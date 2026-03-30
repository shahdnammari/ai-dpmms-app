// medications_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/medication.dart';
import 'notification_service.dart';

class MedicationsService {
  final FirebaseFirestore _db;

  MedicationsService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String uid) {
    return _db.collection('users').doc(uid).collection('medications');
  }

  Stream<List<Medication>> watchMedications(String uid) {
    return _col(uid)
        .orderBy('startDate', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Medication.fromDoc).toList());
  }

  // ADD

  // Create first version of a medication series.
  // groupId = doc.id
  Future<void> addMedication({
    required String uid,
    required String name,
    required String dosage,
    required int frequencyPerDay,
    String? notes,
    required List<String> times,
    required DateTime startDate,
    DateTime? endDate,
    List<String>? repeatDays,
    bool reminderEnabled = true,
  }) async {
    final doc = _col(uid).doc();

    final days = (repeatDays != null && repeatDays.isNotEmpty)
        ? repeatDays
        : List<String>.from(Medication.allDays);

    await doc.set({
      'groupId': doc.id,
      'name': name.trim(),
      'dosage': dosage.trim(),
      'frequencyPerDay': frequencyPerDay,
      'notes': notes?.trim(),
      'startDate': Timestamp.fromDate(_dateOnly(startDate)),
      'endDate': endDate != null ? Timestamp.fromDate(_dateOnly(endDate)) : null,
      'times': times,
      'repeatDays': days,
      'reminderEnabled': reminderEnabled,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // ReminderEnabled
    if (reminderEnabled) {
      await NotificationService.instance.scheduleMedicationRange(
        uid: uid,
        medDocId: doc.id,
        medName: name.trim(),
        startDate: startDate,
        endDate: endDate,
        times: times,
      );
    }
  }

  // UPDATE
  Future<void> updateMedicationVersioned({
    required String uid,
    required Medication oldMed,
    required DateTime effectiveDate,
    required String name,
    required String dosage,
    required int frequencyPerDay,
    String? notes,
    required List<String> times,
    required DateTime? newEndDate,
    List<String>? repeatDays,
    bool? reminderEnabled,
  }) async {
    final eff      = _dateOnly(effectiveDate);
    final today    = _dateOnly(DateTime.now());
    final oldStart = _dateOnly(oldMed.startDate);
    final oldEnd   = oldMed.endDate == null ? null : _dateOnly(oldMed.endDate!);

    final days       = repeatDays ?? oldMed.repeatDays;
    final remEnabled = reminderEnabled ?? oldMed.reminderEnabled;

    // No past edits
    if (eff.isBefore(today)) {
      throw Exception('Cannot edit past days');
    }

    // Validate new end date
    final targetEnd = newEndDate == null ? oldEnd : _dateOnly(newEndDate);
    if (targetEnd != null) {
      if (targetEnd.isBefore(oldStart)) {
        throw Exception('End date cannot be before start date');
      }
      if (targetEnd.isBefore(eff)) {
        throw Exception('End date cannot be before the selected effective date');
      }
    }

    // Prevent overlap with next version
    final next = await _getNextVersion(
        uid: uid, groupId: oldMed.groupId, afterStartDate: oldStart);
    if (next != null && targetEnd != null) {
      final nextStart = _dateOnly(next.startDate);
      if (!targetEnd.isBefore(nextStart)) {
        throw Exception(
            'End date overlaps with a later version starting at '
            '${nextStart.toString().substring(0, 10)}');
      }
    }

    // EffectiveDate must be within old range
    if (oldEnd != null && eff.isAfter(oldEnd)) {
      throw Exception('Selected date is after this medication end date');
    }

    // Special case: same doc update
    final isSameAsOldStart        = _isSameDay(oldStart, eff);
    final oldStartIsFutureOrToday = !oldStart.isBefore(today);

    if (isSameAsOldStart && oldStartIsFutureOrToday) {
      await _col(uid).doc(oldMed.id).update({
        'groupId': oldMed.groupId,
        'name': name.trim(),
        'dosage': dosage.trim(),
        'frequencyPerDay': frequencyPerDay,
        'notes': notes?.trim(),
        'times': times,
        'endDate': targetEnd == null ? null : Timestamp.fromDate(_dateOnly(targetEnd)),
        'repeatDays': days,
        'reminderEnabled': remEnabled,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      

      if (remEnabled) {
        await NotificationService.instance.scheduleMedicationRange(
          uid: uid,
          medDocId: oldMed.id,
          medName: name.trim(),
          startDate: oldStart,
          endDate: targetEnd,
          times: times,
        );
      }

      return;
    }

    // Versioning
    final prevEnd = eff.subtract(const Duration(days: 1));
    if (prevEnd.isBefore(oldStart)) {
      throw Exception('Invalid versioning range (prevEnd before oldStart)');
    }

    final batch = _db.batch();

    // Close old version
    batch.update(_col(uid).doc(oldMed.id), {
      'endDate': Timestamp.fromDate(_dateOnly(prevEnd)),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Create new version
    final newDoc = _col(uid).doc();
    batch.set(newDoc, {
      'groupId': oldMed.groupId,
      'name': name.trim(),
      'dosage': dosage.trim(),
      'frequencyPerDay': frequencyPerDay,
      'notes': notes?.trim(),
      'times': times,
      'startDate': Timestamp.fromDate(eff),
      'endDate': (targetEnd == null)
          ? (oldEnd == null ? null : Timestamp.fromDate(oldEnd))
          : Timestamp.fromDate(_dateOnly(targetEnd)),
      'repeatDays': days,
      'reminderEnabled': remEnabled,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    // Notifications
    
    if (oldMed.reminderEnabled) {
      await NotificationService.instance.scheduleMedicationRange(
        uid: uid,
        medDocId: oldMed.id,
        medName: oldMed.name,
        startDate: oldStart,
        endDate: prevEnd,
        times: oldMed.times,
      );
    }

    if (remEnabled) {
      final newEnd = targetEnd ?? oldEnd;
      await NotificationService.instance.scheduleMedicationRange(
        uid: uid,
        medDocId: newDoc.id,
        medName: name.trim(),
        startDate: eff,
        endDate: newEnd,
        times: times,
      );
    }
  }

  // DELETE
  Future<void> deleteMedicationForFuture({
    required String uid,
    required Medication med,
    required DateTime effectiveDate,
  }) async {
    final eff   = _dateOnly(effectiveDate);
    final today = _dateOnly(DateTime.now());

    if (eff.isBefore(today)) {
      throw Exception('Cannot delete past days');
    }

    final start = _dateOnly(med.startDate);
    final end   = med.endDate == null ? null : _dateOnly(med.endDate!);

    if (end != null && eff.isAfter(end)) {
      throw Exception('Selected date is after this medication end date');
    }

    if (_isSameDay(start, eff)) {
      
      await _col(uid).doc(med.id).delete();
      return;
    }

    final prevEnd = eff.subtract(const Duration(days: 1));
    if (prevEnd.isBefore(start)) {
      throw Exception('Invalid delete range');
    }

    

    await _col(uid).doc(med.id).update({
      'endDate': Timestamp.fromDate(_dateOnly(prevEnd)),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (med.reminderEnabled) {
      await NotificationService.instance.scheduleMedicationRange(
        uid: uid,
        medDocId: med.id,
        medName: med.name,
        startDate: start,
        endDate: prevEnd,
        times: med.times,
      );
    }
  }

  // HELPERS

  Future<Medication?> _getNextVersion({
    required String uid,
    required String groupId,
    required DateTime afterStartDate,
  }) async {
    final snap = await _col(uid)
        .where('groupId', isEqualTo: groupId)
        .where('startDate',
            isGreaterThan: Timestamp.fromDate(_dateOnly(afterStartDate)))
        .orderBy('startDate')
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    return Medication.fromDoc(snap.docs.first);
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}