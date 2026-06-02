import 'package:ai_dpmms_mobile/services/app_refresh.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_strings.dart';
import '../../models/report_models.dart';
import '../../services/report_service.dart';
import '../../services/report_export_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final ReportService _reportService = ReportService();
  final ReportExportService _exportService = ReportExportService();

  ReportPeriodType _selectedType = ReportPeriodType.week;
  DateTime _selectedDate = DateTime.now();
  Future<ReportResult>? _reportFuture;
  VoidCallback? _refreshListener;

  @override
  void initState() {
    super.initState();
    _loadReport();
    _refreshListener = () {
      if (mounted) _loadReport();
    };
    AppRefresh.notifier.addListener(_refreshListener!);
  }

  @override
  void dispose() {
    if (_refreshListener != null) {
      AppRefresh.notifier.removeListener(_refreshListener!);
    }
    super.dispose();
  }

  void _loadReport() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() {
      _reportFuture = _reportService.getReport(
        uid: uid,
        periodType: _selectedType,
        selectedDate: _selectedDate,
      );
    });
  }

  Future<void> _onRefresh() async {
    AppRefresh.trigger();
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
      final end   = start.add(const Duration(days: 6));
      return '${DateFormat('d MMM').format(start)} - ${DateFormat('d MMM yyyy').format(end)}';
    }
    return DateFormat('MMMM yyyy').format(_selectedDate);
  }

  DateTime _weekStartSunday(DateTime d) {
    final day  = DateTime(d.year, d.month, d.day);
    final diff = day.weekday % 7;
    return day.subtract(Duration(days: diff));
  }

  String _exportFileName() {
    if (_selectedType == ReportPeriodType.week) {
      return 'report_week_${DateFormat('yyyy_MM_dd').format(_selectedDate)}.pdf';
    }
    return 'report_month_${DateFormat('yyyy_MM').format(_selectedDate)}.pdf';
  }

  void _showExportSheet(ReportResult data) {
    final s      = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg =
        isDark ? const Color(0xFF1E1E2E) : Colors.white;

    showModalBottomSheet(
      context: context,
      backgroundColor: sheetBg,
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
                    color: Colors.grey.shade400,
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
                _ExportTile(
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
                _ExportTile(
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
                _ExportTile(
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

  @override
  Widget build(BuildContext context) {
    final s   = S.of(context);
    final bg  = Theme.of(context).scaffoldBackgroundColor;
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return Scaffold(body: Center(child: Text(s.notSignedIn)));
    }

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: FutureBuilder<ReportResult>(
          future: _reportFuture,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting &&
                !snap.hasData) {
              return const Center(child: CircularProgressIndicator());
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
                  children: [
                    const SizedBox(height: 180),
                    Center(
                      child: Text(
                        s.noReportData,
                        style: const TextStyle(
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
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(
                          child: _PeriodSelector(
                            selectedType: _selectedType,
                            onChanged: _changeType,
                            s: s,
                          ),
                        ),
                        const SizedBox(height: 40, width: 10),
                        OutlinedButton.icon(
                          onPressed: () => _showExportSheet(data),
                          icon: const Icon(Icons.ios_share_outlined, size: 18),
                          label: Text(s.exportButton),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF1E3A8A),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _DateNavigator(
                      label: _periodLabel(),
                      onPrevious: _goPrevious,
                      onNext: _goNext,
                    ),
                    const SizedBox(height: 18),
                    _SummaryCards(data: data, s: s),
                    const SizedBox(height: 18),
                    _ChartSection(type: _selectedType, bars: data.bars, s: s),
                    const SizedBox(height: 18),
                    _InsightCard(
                      icon: Icons.workspace_premium_outlined,
                      title: _selectedType == ReportPeriodType.week
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
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── Export tile ────────────────────────────────────────────────────────────

class _ExportTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isDark;
  final VoidCallback onTap;

  const _ExportTile({
    required this.icon,
    required this.title,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDark ? Colors.white : const Color(0xFF0F172A);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: const Color(0xFF1E3A8A)),
      title: Text(title,
          style: TextStyle(fontWeight: FontWeight.w700, color: color)),
      onTap: onTap,
    );
  }
}

// ── Period selector ────────────────────────────────────────────────────────

class _PeriodSelector extends StatelessWidget {
  final ReportPeriodType selectedType;
  final ValueChanged<ReportPeriodType> onChanged;
  final S s;

  const _PeriodSelector({
    required this.selectedType,
    required this.onChanged,
    required this.s,
  });

  @override
  Widget build(BuildContext context) {
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
    final surface = Theme.of(context).colorScheme.surface;
    final isDark  = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: selected ? const Color(0xFF2563EB) : surface,
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
                  : Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Date navigator ─────────────────────────────────────────────────────────

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
    final surface   = Theme.of(context).colorScheme.surface;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final isDark    = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            blurRadius: 10,
            offset: const Offset(0, 4),
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.07),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onPrevious,
            icon: Icon(Icons.chevron_left, color: onSurface),
          ),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: onSurface,
              ),
            ),
          ),
          IconButton(
            onPressed: onNext,
            icon: Icon(Icons.chevron_right, color: onSurface),
          ),
        ],
      ),
    );
  }
}

// ── Summary cards ──────────────────────────────────────────────────────────

class _SummaryCards extends StatelessWidget {
  final ReportResult data;
  final S s;

  const _SummaryCards({required this.data, required this.s});

  Color _adherenceColor(int percent) {
    if (percent >= 80) return const Color(0xFF2563EB);
    if (percent >= 50) return const Color(0xFF1E3A8A);
    return const Color(0xFFDC2626);
  }

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final adherenceColor = _adherenceColor(data.summary.adherencePercent);

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            blurRadius: 12,
            offset: const Offset(0, 4),
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.07),
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
            _VerticalDivider(),
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
            _VerticalDivider(),
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
  const _VerticalDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      margin: const EdgeInsets.symmetric(vertical: 14),
      color: Theme.of(context).colorScheme.outlineVariant,
    );
  }
}

// ── Chart section ──────────────────────────────────────────────────────────

class _ChartSection extends StatelessWidget {
  final ReportPeriodType type;
  final List<ReportBarPoint> bars;
  final S s;

  const _ChartSection({
    required this.type,
    required this.bars,
    required this.s,
  });

  @override
  Widget build(BuildContext context) {
    final surface   = Theme.of(context).colorScheme.surface;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final hasData   = bars.any((e) => e.totalDue > 0);

    final title = type == ReportPeriodType.week
        ? s.weeklyOverview
        : s.monthlyOverview;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            blurRadius: 12,
            offset: const Offset(0, 4),
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.07),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                color: onSurface,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              )),
          const SizedBox(height: 18),
          if (!hasData)
            Container(
              height: 180,
              alignment: Alignment.center,
              child: Text(
                s.noChartData,
                style: const TextStyle(
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
                  _ChartYAxis(onSurface: onSurface),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: bars.map((p) => _ChartBar(
                            label: p.label,
                            value: p.adherence,
                            onSurface: onSurface,
                          )).toList(),
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
  final Color onSurface;
  const _ChartYAxis({required this.onSurface});

  @override
  Widget build(BuildContext context) {
    final axisColor = onSurface.withValues(alpha: 0.4);
    return SizedBox(
      width: 26,
      height: 180,
      child: Stack(
        children: [
          Positioned(
            left: 18,
            top: 0,
            bottom: 0,
            child: Container(width: 1.2, color: axisColor),
          ),
          Positioned(
            left: 0,
            top: 0,
            child: Text(
              '100',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          Positioned(
            left: 10,
            top: 14,
            child: Container(width: 14, height: 1, color: axisColor),
          ),
          Positioned(
            left: 10,
            bottom: 0,
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
  final Color onSurface;

  const _ChartBar({
    required this.label,
    required this.value,
    required this.onSurface,
  });

  @override
  Widget build(BuildContext context) {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final clamped  = value.clamp(0.0, 1.0);
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
              color: isDark
                  ? const Color(0xFF3A4A6B)
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
              color: onSurface.withValues(alpha: 0.6),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ── Insight card ───────────────────────────────────────────────────────────

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
    final surface   = Theme.of(context).colorScheme.surface;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final isDark    = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            blurRadius: 10,
            offset: const Offset(0, 4),
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.07),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: onSurface.withValues(alpha: 0.7)),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  color: onSurface,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
                children: [
                  TextSpan(text: '$title: '),
                  TextSpan(
                    text: value,
                    style: TextStyle(
                        color: onSurface.withValues(alpha: 0.65)),
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
