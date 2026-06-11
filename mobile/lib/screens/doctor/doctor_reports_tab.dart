import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_strings.dart';
import '../../models/report_models.dart';
import '../../services/report_service.dart';
import '../../services/report_export_service.dart';
import 'patient_details_screen.dart';
import 'send_message_screen.dart';

class DoctorReportsTab extends StatefulWidget {
  const DoctorReportsTab({super.key});

  static final patientNotifier =
      ValueNotifier<({String id, String name})?>(null);

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
    DoctorReportsTab.patientNotifier.addListener(_onPatientSignal);
    _fetchPatients();
  }

  @override
  void dispose() {
    DoctorReportsTab.patientNotifier.removeListener(_onPatientSignal);
    super.dispose();
  }

  void _onPatientSignal() {
    final p = DoctorReportsTab.patientNotifier.value;
    if (p == null || !mounted) return;
    DoctorReportsTab.patientNotifier.value = null;
    setState(() {
      _selectedPatientId = p.id;
      _selectedPatientName = p.name;
      _selectedDate = DateTime.now();
      _lastReportData = null;
    });
    _loadReport();
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
    final pending = DoctorReportsTab.patientNotifier.value;
    if (pending != null) DoctorReportsTab.patientNotifier.value = null;
    setState(() {
      _patients = patients;
      _fetchingPatients = false;
      if (pending != null) {
        _selectedPatientId = pending.id;
        _selectedPatientName = pending.name;
      } else if (patients.isNotEmpty) {
        _selectedPatientId = patients[0]['id'];
        _selectedPatientName = patients[0]['name'];
      }
    });
    if (_selectedPatientId != null) _loadReport();
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
    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
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
                  width: 42, height: 4,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white24
                        : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  s.exportReport,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 18),
                _exportTile(
                  icon: Icons.picture_as_pdf_outlined,
                  title: s.exportPdf,
                  isDark: isDark,
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
                  title: s.share,
                  isDark: isDark,
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
                  title: s.print,
                  isDark: isDark,
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
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.circle, color: Color(0xFF1E3A8A), size: 0),
      title: Row(
        children: [
          Icon(icon, color: const Color(0xFF1E3A8A)),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
      onTap: onTap,
    );
  }

  void _showPatientPicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
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
    final s = S.of(context);
    if (_lastReportData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.loadingLabel)),
      );
      return;
    }
    _showExportSheet(_lastReportData!);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = Theme.of(context).scaffoldBackgroundColor;

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
            // Patient selector + three-dot menu
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
                          color: isDark
                              ? const Color(0xFF1E1E2E)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                              color: isDark
                                  ? const Color(0xFF3A3A5C)
                                  : const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                              color: Colors.black
                                  .withValues(alpha: isDark ? 0.2 : 0.03),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 26, height: 26,
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
                                _selectedPatientName ?? s.noPatientsAvailable,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: _selectedPatientName != null
                                      ? (isDark
                                          ? Colors.white
                                          : const Color(0xFF1F2937))
                                      : (isDark
                                          ? Colors.white38
                                          : const Color(0xFF94A3B8)),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Icon(Icons.keyboard_arrow_down_rounded,
                                color: isDark
                                    ? Colors.white38
                                    : const Color(0xFF94A3B8),
                                size: 18),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
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
                    color: isDark ? const Color(0xFF1E1E2E) : null,
                    icon: Icon(Icons.more_vert,
                        color: isDark
                            ? Colors.white54
                            : const Color(0xFF64748B),
                        size: 22),
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'message',
                        height: 46,
                        child: Row(
                          children: [
                            const Icon(Icons.near_me_outlined,
                                color: Color(0xFF1E3A8A), size: 18),
                            const SizedBox(width: 10),
                            Text(
                              s.sendMessageTitle,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1F2937),
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'edit',
                        height: 46,
                        child: Row(
                          children: [
                            const Icon(Icons.edit_outlined,
                                color: Color(0xFF1E3A8A), size: 18),
                            const SizedBox(width: 10),
                            Text(
                              s.editMedication,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1F2937),
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'export',
                        height: 46,
                        child: Row(
                          children: [
                            const Icon(Icons.ios_share_outlined,
                                color: Color(0xFF1E3A8A), size: 18),
                            const SizedBox(width: 10),
                            Text(
                              s.exportButton,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1F2937),
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
                  ? Center(
                      child: Text(
                        s.noPatientsAvailable,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.white38
                              : const Color(0xFF94A3B8),
                        ),
                      ),
                    )
                  : FutureBuilder<ReportResult>(
                      future: _reportFuture,
                      builder: (context, snap) {
                        final isLoading =
                            snap.connectionState == ConnectionState.waiting;
                        final data = snap.data;

                        if (snap.hasError && data == null) {
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
                                if (isLoading)
                                  const _SkeletonReportData()
                                else if (data != null) ...[
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
                                        ? s.bestDay
                                        : s.bestWeek,
                                    value: data.insights.bestLabel,
                                  ),
                                  const SizedBox(height: 10),
                                  _InsightCard(
                                    icon: Icons.warning_amber_rounded,
                                    title: s.mostMissed,
                                    value: data.insights.mostMissedMedication,
                                  ),
                                ] else
                                  Center(
                                    child: Padding(
                                      padding:
                                          const EdgeInsets.only(top: 60),
                                      child: Text(
                                        s.noReportData,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? Colors.white38
                                              : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ),
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
    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        Container(
          width: 40, height: 4,
          decoration: BoxDecoration(
            color: isDark ? Colors.white24 : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          s.selectPatient,
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : null),
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
                    p['name']!.isNotEmpty ? p['name']![0].toUpperCase() : '?',
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
                    color: isDark ? Colors.white : null,
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
    final s = S.of(context);
    return Center(
      child: Wrap(
        spacing: 10,
        children: [
          _PeriodChip(
            text: s.reportWeek,
            selected: selectedType == ReportPeriodType.week,
            onTap: () => onChanged(ReportPeriodType.week),
          ),
          _PeriodChip(
            text: s.reportMonth,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: selected
          ? const Color(0xFF2563EB)
          : (isDark ? const Color(0xFF1E1E2E) : Colors.white),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? const Color(0xFF2563EB)
                  : (isDark
                      ? const Color(0xFF3A3A5C)
                      : const Color(0xFFD1D5DB)),
            ),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: selected
                  ? Colors.white
                  : (isDark ? Colors.white70 : const Color(0xFF334155)),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            blurRadius: 10,
            offset: const Offset(0, 4),
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.07),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
              onPressed: onPrevious,
              icon: Icon(Icons.chevron_left,
                  color: isDark ? Colors.white70 : null)),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ),
          IconButton(
              onPressed: onNext,
              icon: Icon(Icons.chevron_right,
                  color: isDark ? Colors.white70 : null)),
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
    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final adherenceColor = _adherenceColor(data.summary.adherencePercent);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            blurRadius: 12,
            offset: const Offset(0, 4),
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.07),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _MetricTile(
                topWidget: Container(
                  width: 54, height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: adherenceColor, width: 1.5),
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
                label: s.adherence,
                labelColor: adherenceColor,
              ),
            ),
            _VerticalDivider(isDark: isDark),
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
                label: s.statusTaken,
                labelColor: const Color(0xFF16A34A),
              ),
            ),
            _VerticalDivider(isDark: isDark),
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
                label: s.missed,
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
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
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
  final bool isDark;
  const _VerticalDivider({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      margin: const EdgeInsets.symmetric(vertical: 14),
      color: isDark ? const Color(0xFF3A3A5C) : const Color(0xFFE2E8F0),
    );
  }
}

// Chart section

class _ChartSection extends StatelessWidget {
  final ReportPeriodType type;
  final List<ReportBarPoint> bars;

  const _ChartSection({required this.type, required this.bars});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = type == ReportPeriodType.week
        ? s.weeklyOverview
        : s.monthlyOverview;
    final hasData = bars.any((e) => e.totalDue > 0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            blurRadius: 12,
            offset: const Offset(0, 4),
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.07),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 18),
          if (!hasData)
            Container(
              height: 180,
              alignment: Alignment.center,
              child: Text(
                s.noChartData,
                style: TextStyle(
                  color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
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
                  _ChartYAxis(isDark: isDark),
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
                          isDark: isDark,
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
  final bool isDark;
  const _ChartYAxis({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final axisColor =
        isDark ? Colors.white38 : const Color(0xFF64748B);
    return SizedBox(
      width: 26,
      height: 180,
      child: Stack(
        children: [
          Positioned(
            left: 18, top: 0, bottom: 0,
            child: Container(width: 1.2, color: axisColor),
          ),
          Positioned(
            left: 0, top: 0,
            child: Text(
              '100',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white54 : const Color(0xFF334155),
              ),
            ),
          ),
          Positioned(
            left: 10, top: 14,
            child: Container(width: 14, height: 1, color: axisColor),
          ),
          Positioned(
            left: 10, bottom: 0,
            child: Container(width: 14, height: 1, color: axisColor),
          ),
        ],
      ),
    );
  }
}

class _ChartBar extends StatelessWidget {
  final String label;
  final double value;
  final bool isDark;

  const _ChartBar({
    required this.label,
    required this.value,
    required this.isDark,
  });

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
          width: 20, height: 140,
          alignment: Alignment.bottomCenter,
          child: Container(
            width: 20, height: height,
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF4A4A6A)
                  : const Color(0xFFDADDE5),
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
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white54 : const Color(0xFF334155),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            blurRadius: 10,
            offset: const Offset(0, 4),
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.07),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon,
              size: 18,
              color: isDark ? Colors.white54 : const Color(0xFF334155)),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
                children: [
                  TextSpan(text: '$title: '),
                  TextSpan(
                    text: value,
                    style: TextStyle(
                        color: isDark
                            ? Colors.white54
                            : const Color(0xFF334155)),
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

// Skeleton — data sections only (summary cards, chart, insights)

class _SkeletonReportData extends StatefulWidget {
  const _SkeletonReportData();

  @override
  State<_SkeletonReportData> createState() => _SkeletonReportDataState();
}

class _SkeletonReportDataState extends State<_SkeletonReportData>
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

  Widget _box({double? width, required double height, double radius = 10}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A4A) : const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E2E) : Colors.white;

    return AnimatedBuilder(
      animation: _opacity,
      builder: (_, _) => Opacity(
        opacity: _opacity.value,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary cards — mirrors _SummaryCards
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(22),
              ),
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 18, horizontal: 8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF2A2A4A)
                                    : const Color(0xFFE2E8F0),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _box(width: 70, height: 14, radius: 6),
                          ],
                        ),
                      ),
                    ),
                    _VerticalDivider(isDark: isDark),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 18, horizontal: 8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _box(width: 40, height: 36, radius: 8),
                            const SizedBox(height: 8),
                            _box(width: 56, height: 14, radius: 6),
                          ],
                        ),
                      ),
                    ),
                    _VerticalDivider(isDark: isDark),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 18, horizontal: 8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _box(width: 40, height: 36, radius: 8),
                            const SizedBox(height: 8),
                            _box(width: 56, height: 14, radius: 6),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            // Chart section — mirrors _ChartSection
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _box(width: 120, height: 14, radius: 7),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 210,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        SizedBox(
                          width: 26,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _box(width: 20, height: 10, radius: 4),
                              _box(width: 20, height: 10, radius: 4),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: List.generate(7, (i) {
                              const heights = [
                                90.0, 130.0, 70.0, 160.0, 110.0, 80.0, 140.0
                              ];
                              return Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  _box(width: 22, height: heights[i], radius: 6),
                                  const SizedBox(height: 4),
                                  _box(width: 18, height: 10, radius: 4),
                                ],
                              );
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            // Best day insight — mirrors _InsightCard pill shape
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                children: [
                  _box(width: 18, height: 18, radius: 4),
                  const SizedBox(width: 8),
                  _box(width: 160, height: 12, radius: 6),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // Most missed insight
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                children: [
                  _box(width: 18, height: 18, radius: 4),
                  const SizedBox(width: 8),
                  _box(width: 140, height: 12, radius: 6),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Skeleton loading — full page (used while patient list is fetching)

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

  Widget _box({double? width, required double height, double radius = 10}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A4A) : const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final divBg =
        isDark ? const Color(0xFF3A3A5C) : const Color(0xFFE2E8F0);

    return AnimatedBuilder(
      animation: _opacity,
      builder: (_, _) => Opacity(
        opacity: _opacity.value,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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

            Container(
              height: 54,
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
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

            Container(
              decoration: BoxDecoration(
                color: cardBg, borderRadius: BorderRadius.circular(22)),
              child: IntrinsicHeight(
                child: Row(
                  children: [
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
                    Container(width: 1, margin: const EdgeInsets.symmetric(vertical: 14), color: divBg),
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
                    Container(width: 1, margin: const EdgeInsets.symmetric(vertical: 14), color: divBg),
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

            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
              decoration: BoxDecoration(
                  color: cardBg, borderRadius: BorderRadius.circular(22)),
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
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Container(
                                  width: 20, height: h,
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF2A2A4A)
                                        : const Color(0xFFE2E8F0),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _box(width: 26, height: 10, radius: 4),
                              ],
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            _box(height: 46, radius: 999),
            const SizedBox(height: 10),
            _box(height: 46, radius: 999),
          ],
        ),
      ),
    );
  }
}
