import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../models/medication.dart';
import '../models/report_models.dart';

class ReportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  String _docIdForDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  ({int h, int m}) _parseHHmm(String s) {
    final parts = s.split(':');
    final h = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
    final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return (h: h, m: m);
  }

  DateTime _weekStartSunday(DateTime d) {
    final day = _dateOnly(d);
    final diff = day.weekday % 7; // Sunday => 0
    return day.subtract(Duration(days: diff));
  }

  DateTime _weekEndSaturday(DateTime d) {
    return _weekStartSunday(d).add(const Duration(days: 6));
  }

  DateTime _monthStart(DateTime d) => DateTime(d.year, d.month, 1);

  DateTime _monthEnd(DateTime d) => DateTime(d.year, d.month + 1, 0);


  Iterable<DateTime> _daysInRange(DateTime start, DateTime end) sync* {
    for (DateTime d = _dateOnly(start);
        !d.isAfter(_dateOnly(end));
        d = d.add(const Duration(days: 1))) {
      yield d;
    }
  }

  bool _isMedActiveForDate(Medication med, DateTime day) {
    final start = _dateOnly(med.startDate);
    final target = _dateOnly(day);

    if (target.isBefore(start)) return false;

    if (med.endDate != null) {
      final end = _dateOnly(med.endDate!);
      if (target.isAfter(end)) return false;
    }

    // Check if this day of week is in the medication's repeat schedule.
    // weekday: 1=Monday … 7=Sunday, matching allDays order.
    if (med.repeatDays.isNotEmpty) {
      const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final dayName = weekdays[day.weekday - 1];
      if (!med.repeatDays.contains(dayName)) return false;
    }

    return true;
  }

  List<Medication> _pickActiveVersionsPerGroup(
    List<Medication> meds,
    DateTime day,
  ) {
    final activeToday = meds.where((m) => _isMedActiveForDate(m, day)).toList();

    final Map<String, Medication> latestByGroup = {};
    for (final med in activeToday) {
      latestByGroup[med.groupId] = med;
    }

    final result = latestByGroup.values.toList();
    result.sort((a, b) {
      final at = a.times.isNotEmpty ? a.times.first : '99:99';
      final bt = b.times.isNotEmpty ? b.times.first : '99:99';
      return at.compareTo(bt);
    });

    return result;
  }

  // A dose is "due" if it's today or any past day — future days are excluded.
  // Today's doses all count regardless of what time they're scheduled at,
  // so the report shows the complete picture (all 5 meds, not just the 2
  // whose times have already passed).
  bool _isDoseDue({
    required DateTime day,
    required String time,
    required DateTime now,
  }) {
    final doseDay = _dateOnly(day);
    final today = _dateOnly(now);
    return !doseDay.isAfter(today);
  }

  // Whether a specific dose's scheduled time has actually passed.
  // Used only for "most missed medication" insights — we don't want to flag
  // a dose as "truly missed" just because it's on today's schedule but hours away.
  bool _isDoseTimeReached({
    required DateTime day,
    required String time,
    required DateTime now,
  }) {
    final doseDay = _dateOnly(day);
    final today = _dateOnly(now);
    if (doseDay.isBefore(today)) return true;
    if (doseDay.isAfter(today)) return false;
    final parsed = _parseHHmm(time);
    final scheduled = DateTime(day.year, day.month, day.day, parsed.h, parsed.m);
    return !scheduled.isAfter(now);
  }

  Future<List<Medication>> _fetchAllMedications(String uid) async {
    final snap = await _firestore
        .collection('users')
        .doc(uid)
        .collection('medications')
        .get();

    return snap.docs.map((doc) {
      final data = doc.data();

      return Medication(
        id: data['id'] ?? doc.id,
        groupId: data['groupId'] ?? doc.id,
        name: (data['name'] ?? '') as String,
        dosage: (data['dosage'] ?? '') as String,
        frequencyPerDay: (data['frequencyPerDay'] ?? 1) as int,
        notes: data['notes'] as String?,
        startDate:
            (data['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
        endDate: (data['endDate'] as Timestamp?)?.toDate(),
        times: ((data['times'] as List?)?.cast<String>() ?? const []),
        repeatDays: ((data['repeatDays'] as List?)?.cast<String>() ??
            Medication.allDays),
        reminderEnabled: (data['reminderEnabled'] ?? true) as bool,
      );
    }).toList();
  }

  Future<Map<String, dynamic>> _fetchDailyIntake(String uid, DateTime day) async {
    final snap = await _firestore
        .collection('users')
        .doc(uid)
        .collection('daily_intake')
        .doc(_docIdForDate(day))
        .get();

    final data = snap.data();
    if (data == null) return {};

    // Doses are stored at the top level as Maps: { '{medId}_{time}': { status, updatedAt } }
    return Map<String, dynamic>.fromEntries(
      data.entries.where((e) => e.value is Map),
    );
  }

  Future<_BucketResult> _buildBucketForRange({
    required String uid,
    required DateTime start,
    required DateTime end,
    required DateTime now,
    required List<Medication> meds,
  }) async {
    int totalDue = 0;
    int taken = 0;
    int missed = 0;
    int skipped = 0;

    final Map<String, int> missedByMedicationGroup = {};
    final Map<String, String> medicationsNameByGroup = {};

    for (final day in _daysInRange(start, end)) {
      final intakeMap = await _fetchDailyIntake(uid, day);
      final medsForDay = _pickActiveVersionsPerGroup(meds, day);

      for (final med in medsForDay) {
        final times = med.times.isNotEmpty ? med.times : const ['08:00'];

        medicationsNameByGroup[med.groupId] = med.name;

        for (final time in times) {
          final due = _isDoseDue(day: day, time: time, now: now);
          if (!due) continue;

          totalDue++;

          final doseKey = '${med.id}_$time';

          final rawValue = intakeMap[doseKey];
          final statusMap =
              rawValue is Map<String, dynamic> ? rawValue : null;
          final status = (statusMap?['status'] as String?) ?? 'pending';

          if (status == 'taken') {
            taken++;
          } else if (status == 'skipped') {
            skipped++;
          } else {
            missed++;
            // Only count toward "most missed" insight if the time actually passed —
            // today's future-scheduled doses shouldn't skew the insight.
            if (_isDoseTimeReached(day: day, time: time, now: now)) {
              missedByMedicationGroup[med.groupId] =
                  (missedByMedicationGroup[med.groupId] ?? 0) + 1;
            }
          }
        }
      }
    }

    final denominator = taken + missed;
    final adherence = denominator == 0 ? 0.0 : taken / denominator;

    return _BucketResult(
      totalDue: totalDue,
      taken: taken,
      missed: missed,
      skipped: skipped,
      adherence: adherence,
      missedByMedicationGroup: missedByMedicationGroup,
      medicationsNameByGroup: medicationsNameByGroup,
    );
  }

  Future<ReportResult> getReport({
    required String uid,
    required ReportPeriodType periodType,
    required DateTime selectedDate,
  }) async {
    final now = DateTime.now();
    final meds = await _fetchAllMedications(uid);

    switch (periodType) {
      case ReportPeriodType.week:
        return _getWeekReport(
          uid: uid,
          selectedDate: selectedDate,
          now: now,
          meds: meds,
        );
      case ReportPeriodType.month:
        return _getMonthReport(
          uid: uid,
          selectedDate: selectedDate,
          now: now,
          meds: meds,
        );
    }
  }

  Future<ReportResult> _getWeekReport({
    required String uid,
    required DateTime selectedDate,
    required DateTime now,
    required List<Medication> meds,
  }) async {
    final start = _weekStartSunday(selectedDate);
    final end = _weekEndSaturday(selectedDate);

    final bucket = await _buildBucketForRange(
      uid: uid,
      start: start,
      end: end,
      now: now,
      meds: meds,
    );

    final bars = <ReportBarPoint>[];
    ReportBarPoint? bestBar;

    for (final day in _daysInRange(start, end)) {
      final dayBucket = await _buildBucketForRange(
        uid: uid,
        start: day,
        end: day,
        now: now,
        meds: meds,
      );

      final point = ReportBarPoint(
        label: DateFormat('EEE').format(day),
        totalDue: dayBucket.totalDue,
        taken: dayBucket.taken,
        missed: dayBucket.missed,
        skipped: dayBucket.skipped,
        adherence: dayBucket.adherence,
      );

      bars.add(point);

      if (bestBar == null || point.adherence > bestBar.adherence) {
        bestBar = point;
      }
    }

    final mostMissedMedication = _pickMostMissed(
      missedByMedicationGroup: bucket.missedByMedicationGroup,
      medicationNameByGroup: bucket.medicationsNameByGroup,
    );

    final bestLabel = bestBar == null || bestBar.totalDue == 0
        ? 'No data yet'
        : '${bestBar.label} (${bestBar.adherencePercent}%)';

    return ReportResult(
      periodType: ReportPeriodType.week,
      selectedDate: selectedDate,
      summary: ReportSummary(
        totalDue: bucket.totalDue,
        taken: bucket.taken,
        missed: bucket.missed,
        skipped: bucket.skipped,
        adherence: bucket.adherence,
      ),
      bars: bars,
      insights: ReportInsights(
        bestLabel: bestLabel,
        mostMissedMedication: mostMissedMedication,
      ),
    );
  }

  Future<ReportResult> _getMonthReport({
    required String uid,
    required DateTime selectedDate,
    required DateTime now,
    required List<Medication> meds,
  }) async {
    final start = _monthStart(selectedDate);
    final end = _monthEnd(selectedDate);

    final bucket = await _buildBucketForRange(
      uid: uid,
      start: start,
      end: end,
      now: now,
      meds: meds,
    );

    final bars = <ReportBarPoint>[];
    ReportBarPoint? bestBar;

    final List<({DateTime start, DateTime end, String label})> weeks = [];
    DateTime cursor = start;
    int weekNumber = 1;

    while (!cursor.isAfter(end)) {
      final weekStart = cursor;
      final weekEnd = cursor.add(const Duration(days: 6)).isAfter(end)
          ? end
          : cursor.add(const Duration(days: 6));

      weeks.add((
        start: weekStart,
        end: weekEnd,
        label: 'W$weekNumber',
      ));

      cursor = weekEnd.add(const Duration(days: 1));
      weekNumber++;
    }

    for (final week in weeks) {
      final weekBucket = await _buildBucketForRange(
        uid: uid,
        start: week.start,
        end: week.end,
        now: now,
        meds: meds,
      );

      final point = ReportBarPoint(
        label: week.label,
        totalDue: weekBucket.totalDue,
        taken: weekBucket.taken,
        missed: weekBucket.missed,
        skipped: weekBucket.skipped,
        adherence: weekBucket.adherence,
      );

      bars.add(point);

      if (bestBar == null || point.adherence > bestBar.adherence) {
        bestBar = point;
      }
    }

    final mostMissedMedication = _pickMostMissed(
      missedByMedicationGroup: bucket.missedByMedicationGroup,
      medicationNameByGroup: bucket.medicationsNameByGroup,
    );

    final bestLabel = bestBar == null || bestBar.totalDue == 0
        ? 'No data yet'
        : '${bestBar.label} (${bestBar.adherencePercent}%)';

    return ReportResult(
      periodType: ReportPeriodType.month,
      selectedDate: selectedDate,
      summary: ReportSummary(
        totalDue: bucket.totalDue,
        taken: bucket.taken,
        missed: bucket.missed,
        skipped: bucket.skipped,
        adherence: bucket.adherence,
      ),
      bars: bars,
      insights: ReportInsights(
        bestLabel: bestLabel,
        mostMissedMedication: mostMissedMedication,
      ),
    );
  }


  String _pickMostMissed({
    required Map<String, int> missedByMedicationGroup,
    required Map<String, String> medicationNameByGroup,
  }) {
    if (missedByMedicationGroup.isEmpty) return 'No data yet';

    final maxMissed = missedByMedicationGroup.values.reduce(
      (a, b) => a > b ? a : b,
    );

    if (maxMissed <= 0) return 'No data yet';

    final winners = missedByMedicationGroup.entries
        .where((e) => e.value == maxMissed)
        .map((e) => medicationNameByGroup[e.key] ?? 'Unknown')
        .toSet()
        .toList()
      ..sort();

    if (winners.isEmpty) return 'No data yet';

    return winners.join(', ');
  }
}

class _BucketResult {
  final int totalDue;
  final int taken;
  final int missed;
  final int skipped;
  final double adherence;
  
  // groupId -> missed count
  final Map<String, int> missedByMedicationGroup;

  // groupId -> mediation name
  final Map<String, String> medicationsNameByGroup;

  const _BucketResult({
    required this.totalDue,
    required this.taken,
    required this.missed,
    required this.skipped,
    required this.adherence,
    required this.medicationsNameByGroup,
    required this.missedByMedicationGroup,
  });
}