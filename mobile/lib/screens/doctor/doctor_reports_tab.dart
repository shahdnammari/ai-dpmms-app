import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../models/report_models.dart';
import '../../services/report_service.dart';
import '../../services/report_export_service.dart';
import 'patient_details_screen.dart';
import 'send_message_screen.dart';

class DoctorReportsTab extends StatefulWidget {
  const DoctorReportsTab({super.key});

  @override
  State<DoctorReportsTab> createState() => _DoctorReportsTabState();
}

class _DoctorReportsTabState extends State<DoctorReportsTab> {
  final ReportService _reportService = ReportService();
  final ReportExportService _exportService = ReportExportService();

  bool _fetchingPatients = true;
  List<Map<String, String>> _patients = [];
  String? _selectedPatientId;
  String? _selectedPatientName;

  ReportPeriodType _selectedType = ReportPeriodType.week;
  DateTime _selectedDate = DateTime.now();
  Future<ReportResult>? _reportFuture;
  ReportResult? _lastReportData;

  @override
  void initState() {
    super.initState();
    _fetchPatients();
  }

  Future<void> _fetchPatients() async {
    final results = await Future.wait([
      FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'patient')
          .get(),
      FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'Patient')
          .get(),
    ]);

    final seen = <String>{};
    final patients = <Map<String, String>>[];
    for (final snap in results) {
      for (final doc in snap.docs) {
        if (!seen.add(doc.id)) continue;
        final d = doc.data();
        final name = (d['name'] as String?)?.trim().isNotEmpty == true
            ? d['name'] as String
            : (d['username'] as String?) ?? 'Unknown';
        patients.add({'id': doc.id, 'name': name});
      }
    }
    patients.sort((a, b) => a['name']!.compareTo(b['name']!));

    if (!mounted) return;
    setState(() {
      _patients = patients;
      _fetchingPatients = false;
      if (patients.isNotEmpty) {
        _selectedPatientId = patients[0]['id'];
        _selectedPatientName = patients[0]['name'];
      }
    });
    if (patients.isNotEmpty) _loadReport();
  }

  void _loadReport() {
    if (_selectedPatientId == null) return;
    final future = _reportService.getReport(
      uid: _selectedPatientId!,
      periodType: _selectedType,
      selectedDate: _selectedDate,
    );
    future.then((data) {
      if (mounted) setState(() => _lastReportData = data);
    }).catchError((_) {});
    setState(() {
      _reportFuture = future;
      _lastReportData = null;
    });
  }

  Future<void> _onRefresh() async {
    _loadReport();
    await Future.delayed(const Duration(milliseconds: 400));
  }

  void _changeType(ReportPeriodType type) {
    if (_selectedType == type) return;
    setState(() {
      _selectedType = type;
      _selectedDate = DateTime.now();
    });
    _loadReport();
  }

  void _goPrevious() {
    setState(() {
      if (_selectedType == ReportPeriodType.week) {
        _selectedDate = _selectedDate.subtract(const Duration(days: 7));
      } else {
        _selectedDate =
            DateTime(_selectedDate.year, _selectedDate.month - 1, 1);
      }
    });
    _loadReport();
  }

  void _goNext() {
    setState(() {
      if (_selectedType == ReportPeriodType.week) {
        _selectedDate = _selectedDate.add(const Duration(days: 7));
      } else {
        _selectedDate =
            DateTime(_selectedDate.year, _selectedDate.month + 1, 1);
      }
    });
    _loadReport();
  }

  String _periodLabel() {
    if (_selectedType == ReportPeriodType.week) {
      final start = _weekStartSunday(_selectedDate);
      final end = start.add(const Duration(days: 6));
      return '${DateFormat('d MMM').format(start)} - ${DateFormat('d MMM yyyy').format(end)}';
    }
    return DateFormat('MMMM yyyy').format(_selectedDate);
  }

  DateTime _weekStartSunday(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    return day.subtract(Duration(days: day.weekday % 7));
  }

  String _exportFileName() {
    if (_selectedType == ReportPeriodType.week) {
      return 'report_week_${DateFormat('yyyy_MM_dd').format(_selectedDate)}.pdf';
    }
    return 'report_month_${DateFormat('yyyy_MM').format(_selectedDate)}.pdf';
  }

  void _showExportSheet(ReportResult data) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Export Report',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 18),
                _exportTile(
                  icon: Icons.picture_as_pdf_outlined,
                  title: 'Export as PDF',
                  onTap: () async {
                    Navigator.pop(context);
                    await _exportService.sharePdf(
                      report: data,
                      periodLabel: _periodLabel(),
                      fileName: _exportFileName(),
                    );
                  },
                ),
                _exportTile(
                  icon: Icons.share_outlined,
                  title: 'Share',
                  onTap: () async {
                    Navigator.pop(context);
                    await _exportService.sharePdf(
                      report: data,
                      periodLabel: _periodLabel(),
                      fileName: _exportFileName(),
                    );
                  },
                ),
                _exportTile(
                  icon: Icons.print_outlined,
                  title: 'Print',
                  onTap: () async {
                    Navigator.pop(context);
                    await _exportService.printPdf(
                      report: data,
                      periodLabel: _periodLabel(),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _exportTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: const Color(0xFF1E3A8A)),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: Color(0xFF0F172A),
        ),
      ),
      onTap: onTap,
    );
  }

  void _showPatientPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _PatientPickerSheet(
        patients: _patients,
        selectedId: _selectedPatientId,
        onSelect: (id, name) {
          Navigator.pop(context);
          setState(() {
            _selectedPatientId = id;
            _selectedPatientName = name;
            _selectedDate = DateTime.now();
            _lastReportData = null;
          });
          _loadReport();
        },
      ),
    );
  }

  void _onSendMessage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SendMessageScreen(
          prefilledPatientId: _selectedPatientId,
          prefilledPatientName: _selectedPatientName,
        ),
      ),
    );
  }

  void _onEditMedication() {
    if (_selectedPatientId == null || _selectedPatientName == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PatientDetailsScreen(
          patientUid: _selectedPatientId!,
          patientName: _selectedPatientName!,
        ),
      ),
    );
  }

  void _onExport() {
    if (_lastReportData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report is still loading.')),
      );
      return;
    }
    _showExportSheet(_lastReportData!);
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFF3F6FB);

    if (_fetchingPatients) {
      return Scaffold(
        backgroundColor: bg,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            child: const _SkeletonReportContent(showSelectorRow: true),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            //Patient selector + three-dot menu
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _patients.isEmpty ? null : _showPatientPicker,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          border:
                              Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: const [
                            BoxShadow(
                              blurRadius: 6,
                              offset: Offset(0, 2),
                              color: Color(0x08000000),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E3A8A)
                                    .withValues(alpha: 0.10),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.person_outline,
                                  color: Color(0xFF1E3A8A), size: 15),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _selectedPatientName ?? 'No patients found',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: _selectedPatientName != null
                                      ? const Color(0xFF1F2937)
                                      : const Color(0xFF94A3B8),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(Icons.keyboard_arrow_down_rounded,
                                color: Color(0xFF94A3B8), size: 18),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Three-dot menu
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'message') _onSendMessage();
                      if (v == 'edit') _onEditMedication();
                      if (v == 'export') _onExport();
                    },
                    enabled: _selectedPatientId != null,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                    icon: const Icon(Icons.more_vert,
                        color: Color(0xFF64748B), size: 22),
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'message',
                        height: 46,
                        child: Row(
                          children: [
                            Icon(Icons.near_me_outlined,
                                color: Color(0xFF1E3A8A), size: 18),
                            SizedBox(width: 10),
                            Text(
                              'Send Message',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'edit',
                        height: 46,
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined,
                                color: Color(0xFF1E3A8A), size: 18),
                            SizedBox(width: 10),
                            Text(
                              'Edit Medication',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'export',
                        height: 46,
                        child: Row(
                          children: [
                            Icon(Icons.ios_share_outlined,
                                color: Color(0xFF1E3A8A), size: 18),
                            SizedBox(width: 10),
                            Text(
                              'Export',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Report content
            Expanded(
              child: _selectedPatientId == null
                  ? const Center(
                      child: Text(
                        'No patients available.',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    )
                  : FutureBuilder<ReportResult>(
                      future: _reportFuture,
                      builder: (context, snap) {
                        if (snap.connectionState ==
                                ConnectionState.waiting &&
                            !snap.hasData) {
                          return SingleChildScrollView(
                            padding:
                                const EdgeInsets.fromLTRB(16, 14, 16, 24),
                            child:
                                const _SkeletonReportContent(),
                          );
                        }

                        if (snap.hasError) {
                          return RefreshIndicator(
                            onRefresh: _onRefresh,
                            child: ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                const SizedBox(height: 180),
                                Center(
                                  child: Text(
                                    'Failed: ${snap.error}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.red,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        final data = snap.data;
                        if (data == null) {
                          return RefreshIndicator(
                            onRefresh: _onRefresh,
                            child: ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: const [
                                SizedBox(height: 180),
                                Center(
                                  child: Text(
                                    'No report data yet.',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return RefreshIndicator(
                          onRefresh: _onRefresh,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding:
                                const EdgeInsets.fromLTRB(16, 14, 16, 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _PeriodSelector(
                                  selectedType: _selectedType,
                                  onChanged: _changeType,
                                ),
                                const SizedBox(height: 16),
                                _DateNavigator(
                                  label: _periodLabel(),
                                  onPrevious: _goPrevious,
                                  onNext: _goNext,
                                ),
                                const SizedBox(height: 18),
                                _SummaryCards(data: data),
                                const SizedBox(height: 18),
                                _ChartSection(
                                  type: _selectedType,
                                  bars: data.bars,
                                ),
                                const SizedBox(height: 18),
                                _InsightCard(
                                  icon: Icons.workspace_premium_outlined,
                                  title: _selectedType ==
                                          ReportPeriodType.week
                                      ? 'Best Day'
                                      : 'Best Week',
                                  value: data.insights.bestLabel,
                                ),
                                const SizedBox(height: 10),
                                _InsightCard(
                                  icon: Icons.warning_amber_rounded,
                                  title: 'Most Missed',
                                  value:
                                      data.insights.mostMissedMedication,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// Patient picker bottom sheet

class _PatientPickerSheet extends StatelessWidget {
  final List<Map<String, String>> patients;
  final String? selectedId;
  final void Function(String id, String name) onSelect;

  const _PatientPickerSheet({
    required this.patients,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Select Patient',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: patients.length,
            itemBuilder: (_, i) {
              final p = patients[i];
              final selected = p['id'] == selectedId;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      const Color(0xFF1E3A8A).withValues(alpha: 0.10),
                  child: Text(
                    p['name']!.isNotEmpty
                        ? p['name']![0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: Color(0xFF1E3A8A),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                title: Text(
                  p['name']!,
                  style: TextStyle(
                    fontWeight:
                        selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
                trailing: selected
                    ? const Icon(Icons.check, color: Color(0xFF1E3A8A))
                    : null,
                onTap: () => onSelect(p['id']!, p['name']!),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

// Period selector

class _PeriodSelector extends StatelessWidget {
  final ReportPeriodType selectedType;
  final ValueChanged<ReportPeriodType> onChanged;

  const _PeriodSelector({
    required this.selectedType,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Wrap(
        spacing: 10,
        children: [
          _PeriodChip(
            text: 'Week',
            selected: selectedType == ReportPeriodType.week,
            onTap: () => onChanged(ReportPeriodType.week),
          ),
          _PeriodChip(
            text: 'Month',
            selected: selectedType == ReportPeriodType.month,
            onTap: () => onChanged(ReportPeriodType.month),
          ),
        ],
      ),
    );
  }
}

class _PeriodChip extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback onTap;

  const _PeriodChip({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFF2563EB) : Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? const Color(0xFF2563EB)
                  : const Color(0xFFD1D5DB),
            ),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFF334155),
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

// Date navigator

class _DateNavigator extends StatelessWidget {
  final String label;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _DateNavigator({
    required this.label,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            blurRadius: 10,
            offset: Offset(0, 4),
            color: Color(0x11000000),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
              onPressed: onPrevious,
              icon: const Icon(Icons.chevron_left)),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          IconButton(
              onPressed: onNext,
              icon: const Icon(Icons.chevron_right)),
        ],
      ),
    );
  }
}

// Summary cards

class _SummaryCards extends StatelessWidget {
  final ReportResult data;

  const _SummaryCards({required this.data});

  Color _adherenceColor(int percent) {
    if (percent >= 80) return const Color(0xFF2563EB);
    if (percent >= 50) return const Color(0xFF1E3A8A);
    return const Color(0xFFDC2626);
  }

  @override
  Widget build(BuildContext context) {
    final adherenceColor =
        _adherenceColor(data.summary.adherencePercent);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            blurRadius: 12,
            offset: Offset(0, 4),
            color: Color(0x12000000),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _MetricTile(
                topWidget: Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: adherenceColor, width: 1.5),
                    color: adherenceColor.withValues(alpha: 0.08),
                  ),
                  child: Center(
                    child: Text(
                      '${data.summary.adherencePercent}%',
                      style: TextStyle(
                        color: adherenceColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                label: 'Adherence',
                labelColor: adherenceColor,
              ),
            ),
            const _VerticalDivider(),
            Expanded(
              child: _MetricTile(
                topWidget: Text(
                  '${data.summary.taken}',
                  style: const TextStyle(
                    color: Color(0xFF16A34A),
                    fontWeight: FontWeight.w900,
                    fontSize: 30,
                  ),
                ),
                label: 'Taken',
                labelColor: const Color(0xFF16A34A),
              ),
            ),
            const _VerticalDivider(),
            Expanded(
              child: _MetricTile(
                topWidget: Text(
                  '${data.summary.missed}',
                  style: const TextStyle(
                    color: Color(0xFFEF4444),
                    fontWeight: FontWeight.w900,
                    fontSize: 30,
                  ),
                ),
                label: 'Missed',
                labelColor: const Color(0xFFEF4444),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final Widget topWidget;
  final String label;
  final Color labelColor;

  const _MetricTile({
    required this.topWidget,
    required this.label,
    required this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          topWidget,
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: labelColor,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  const _VerticalDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      margin: const EdgeInsets.symmetric(vertical: 14),
      color: const Color(0xFFE2E8F0),
    );
  }
}

// Chart section

class _ChartSection extends StatelessWidget {
  final ReportPeriodType type;
  final List<ReportBarPoint> bars;

  const _ChartSection({required this.type, required this.bars});

  String get _title {
    switch (type) {
      case ReportPeriodType.week:
        return 'Weekly Overview';
      case ReportPeriodType.month:
        return 'Monthly Overview';
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasData = bars.any((e) => e.totalDue > 0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            blurRadius: 12,
            offset: Offset(0, 4),
            color: Color(0x12000000),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _title,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 18),
          if (!hasData)
            Container(
              height: 180,
              alignment: Alignment.center,
              child: const Text(
                'No chart data yet.',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            SizedBox(
              height: 210,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const _ChartYAxis(),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: List.generate(bars.length, (i) {
                        final p = bars[i];
                        return _ChartBar(
                          label: p.label,
                          value: p.adherence,
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ChartYAxis extends StatelessWidget {
  const _ChartYAxis();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 26,
      height: 180,
      child: Stack(
        children: [
          Positioned(
            left: 18,
            top: 0,
            bottom: 0,
            child:
                Container(width: 1.2, color: const Color(0xFF64748B)),
          ),
          const Positioned(
            left: 0,
            top: 0,
            child: Text(
              '100',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFF334155),
              ),
            ),
          ),
          Positioned(
            left: 10,
            top: 14,
            child: Container(
                width: 14,
                height: 1,
                color: const Color(0xFF64748B)),
          ),
          Positioned(
            left: 10,
            bottom: 0,
            child: Container(
                width: 14,
                height: 1,
                color: const Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}

class _ChartBar extends StatelessWidget {
  final String label;
  final double value;

  const _ChartBar({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0.0, 1.0);
    final rawHeight = 140.0 * clamped;
    final double height =
        value > 0 ? (rawHeight < 10.0 ? 10.0 : rawHeight) : 6.0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 20,
          height: 140,
          alignment: Alignment.bottomCenter,
          child: Container(
            width: 20,
            height: height,
            decoration: BoxDecoration(
              color: const Color(0xFFDADDE5),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 30,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF334155),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// Insight card

class _InsightCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InsightCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(
            blurRadius: 10,
            offset: Offset(0, 4),
            color: Color(0x12000000),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF334155)),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
                children: [
                  TextSpan(text: '$title: '),
                  TextSpan(
                    text: value,
                    style:
                        const TextStyle(color: Color(0xFF334155)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Skeleton loading

class _SkeletonReportContent extends StatefulWidget {
  final bool showSelectorRow;

  const _SkeletonReportContent({this.showSelectorRow = false});

  @override
  State<_SkeletonReportContent> createState() =>
      _SkeletonReportContentState();
}

class _SkeletonReportContentState extends State<_SkeletonReportContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _opacity = Tween(begin: 0.35, end: 0.75).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _box({
    double? width,
    required double height,
    double radius = 10,
  }) =>
      Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(radius),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacity,
      builder: (_, _) => Opacity(
        opacity: _opacity.value,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Patient selector row skeleton
            if (widget.showSelectorRow) ...[
              Row(
                children: [
                  Expanded(child: _box(height: 46, radius: 30)),
                  const SizedBox(width: 8),
                  _box(width: 38, height: 38, radius: 19),
                ],
              ),
              const SizedBox(height: 14),
            ],

            // Period chips
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _box(width: 72, height: 34, radius: 999),
                  const SizedBox(width: 10),
                  _box(width: 72, height: 34, radius: 999),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Date navigator
            Container(
              height: 54,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 10,
                    offset: Offset(0, 4),
                    color: Color(0x11000000),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _box(width: 22, height: 22, radius: 4),
                  const Spacer(),
                  _box(width: 130, height: 13, radius: 6),
                  const Spacer(),
                  _box(width: 22, height: 22, radius: 4),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Summary cards
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 12,
                    offset: Offset(0, 4),
                    color: Color(0x12000000),
                  ),
                ],
              ),
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    // Adherence tile
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 18, horizontal: 8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _box(width: 54, height: 54, radius: 27),
                            const SizedBox(height: 8),
                            _box(width: 68, height: 13, radius: 6),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      width: 1,
                      margin:
                          const EdgeInsets.symmetric(vertical: 14),
                      color: const Color(0xFFE2E8F0),
                    ),
                    // Taken tile
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 18, horizontal: 8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _box(width: 38, height: 38, radius: 6),
                            const SizedBox(height: 8),
                            _box(width: 50, height: 13, radius: 6),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      width: 1,
                      margin:
                          const EdgeInsets.symmetric(vertical: 14),
                      color: const Color(0xFFE2E8F0),
                    ),
                    // Missed tile
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 18, horizontal: 8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _box(width: 38, height: 38, radius: 6),
                            const SizedBox(height: 8),
                            _box(width: 50, height: 13, radius: 6),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Chart section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 12,
                    offset: Offset(0, 4),
                    color: Color(0x12000000),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _box(width: 116, height: 13, radius: 6),
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [80.0, 120.0, 40.0, 100.0, 60.0, 110.0, 70.0]
                        .map((h) => Column(
                              mainAxisAlignment:
                                  MainAxisAlignment.end,
                              children: [
                                Container(
                                  width: 20,
                                  height: h,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE2E8F0),
                                    borderRadius:
                                        BorderRadius.circular(4),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _box(
                                    width: 26,
                                    height: 10,
                                    radius: 4),
                              ],
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Insight cards
            _box(height: 46, radius: 999),
            const SizedBox(height: 10),
            _box(height: 46, radius: 999),
          ],
        ),
      ),
    );
  }
}
