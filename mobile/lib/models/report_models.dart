enum ReportPeriodType {
  week,
  month,
}

class ReportSummary {
  final int totalDue;
  final int taken;
  final int missed;
  final int skipped;
  final double adherence; // 0.0 -> 1.0

  const ReportSummary({
    required this.totalDue,
    required this.taken,
    required this.missed,
    required this.skipped,
    required this.adherence,
  });

  int get adherencePercent => (adherence * 100).round();
}

class ReportBarPoint {
  final String label;
  final int totalDue;
  final int taken;
  final int missed;
  final int skipped;
  final double adherence; // 0.0 -> 1.0

  const ReportBarPoint({
    required this.label,
    required this.totalDue,
    required this.taken,
    required this.missed,
    required this.skipped,
    required this.adherence,
  });

  int get adherencePercent => (adherence * 100).round();
}

class ReportInsights {
  final String bestLabel; // Best Week / Best Month
  final String mostMissedMedication;

  const ReportInsights({
    required this.bestLabel,
    required this.mostMissedMedication,
  });
}

class ReportResult {
  final ReportPeriodType periodType;
  final DateTime selectedDate;

  final ReportSummary summary;
  final List<ReportBarPoint> bars;
  final ReportInsights insights;

  const ReportResult({
    required this.periodType,
    required this.selectedDate,
    required this.summary,
    required this.bars,
    required this.insights,
  });
}