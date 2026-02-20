// medications_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/medication.dart';
import 'notification_service.dart';

class MedicationsService {
  final FirebaseFirestore _db;

  MedicationsService({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String uid) {
    return _db.collection('users').doc(uid).collection('medications');
  }

  Stream<List<Medication>> watchMedications(String uid) {
    return _col(uid)
        .orderBy('startDate', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Medication.fromDoc).toList());
  }

  /// Create first version of a medication series.
  /// groupId = doc.id
  Future<void> addMedication({
    required String uid,
    required String name,
    required String dosage,
    required int frequencyPerDay,
    String? notes,
    required List<String> times,
    required DateTime startDate,
    DateTime? endDate,
    required bool isActive,
  }) async {
    final doc = _col(uid).doc();

    await doc.set({
      'groupId': doc.id,
      'name': name.trim(),
      'dosage': dosage.trim(),
      'frequencyPerDay': frequencyPerDay,
      'notes': notes?.trim(),
      'isActive': isActive,
      'startDate': Timestamp.fromDate(_dateOnly(startDate)),
      'endDate': endDate != null ? Timestamp.fromDate(_dateOnly(endDate)) : null,
      'times': times,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await NotificationService.instance.scheduleMedicationRange(
      medDocId: doc.id,
      medName: name.trim(),
      startDate: startDate,
      endDate: endDate,
      times: times,
    );
  }

  /// Versioning / Effective Dating:
  /// - Past edits: forbidden
  /// - Today/Future:
  ///   - If effectiveDate == old.startDate AND old.startDate >= today => update same doc (future version not started)
  ///   - Else => close old at (effectiveDate-1) and create new version starting at effectiveDate
  ///       new.endDate = old.endDate (as it was)
  ///       new.groupId = old.groupId
  Future<void> updateMedicationVersioned({
    required String uid,
    required Medication oldMed,
    required DateTime effectiveDate,
    required String name,
    required String dosage,
    required int frequencyPerDay,
    String? notes,
    required List<String> times,
    required bool isActive,
    required DateTime? newEndDate,
  }) async {
    final eff = _dateOnly(effectiveDate);
    final today = _dateOnly(DateTime.now());
    final oldStart = _dateOnly(oldMed.startDate);
    final oldEnd = oldMed.endDate == null ? null : _dateOnly(oldMed.endDate!);

    // 1) No past edits
    if (eff.isBefore(today)) {
      throw Exception('Cannot edit past days');
    }

    // 2) Validate new end date
    final targetEnd = newEndDate == null ? oldEnd : _dateOnly(newEndDate);
    if (targetEnd != null) {
      // end must not be before start of THIS version
      if (targetEnd.isBefore(oldStart)) {
        throw Exception('End date cannot be before start date');
      }
      // and must not be before effective date (otherwise the new version would be empty)
      if (targetEnd.isBefore(eff)) {
        throw Exception('End date cannot be before the selected effective date');
      }
    }

    // 3) Prevent overlap with next version in same group (PRO)
    final next = await _getNextVersion(uid: uid, groupId: oldMed.groupId, afterStartDate: oldStart);
    if (next != null && targetEnd != null) {
      final nextStart = _dateOnly(next.startDate);
      if (!targetEnd.isBefore(nextStart)) {
        throw Exception('End date overlaps with a later version starting at ${nextStart.toString().substring(0,10)}');
      }
    }

    // 4) If old version has an endDate, effectiveDate must be within its current range
    if (oldEnd != null && eff.isAfter(oldEnd)) {
      throw Exception('Selected date is after this medication end date');
    }

    // Special case: editing a FUTURE version on its first effective day
    final isSameAsOldStart = _isSameDay(oldStart, eff);
    final oldStartIsFutureOrToday = !oldStart.isBefore(today);

    if (isSameAsOldStart && oldStartIsFutureOrToday) {
      // update same doc
      await _col(uid).doc(oldMed.id).update({
        'groupId': oldMed.groupId,
        'name': name.trim(),
        'dosage': dosage.trim(),
        'frequencyPerDay': frequencyPerDay,
        'notes': notes?.trim(),
        'times': times,
        'isActive': isActive,
        'endDate': targetEnd == null ? null : Timestamp.fromDate(_dateOnly(targetEnd)),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Cancel+Reschedule (after update)
      await NotificationService.instance.cancelMedicationRange(
        medDocId: oldMed.id,
        startDate: oldStart,
        endDate: oldEnd,
        timesCount: oldMed.times.length,
      );

      await NotificationService.instance.scheduleMedicationRange(
        medDocId: oldMed.id,
        medName: name.trim(),
        startDate: oldStart,
        endDate: targetEnd,
        times: times,
      );

      return;
    }

    // 5) Versioning
    final prevEnd = eff.subtract(const Duration(days: 1));
    if (prevEnd.isBefore(oldStart)) {
      throw Exception('Invalid versioning range (prevEnd before oldStart)');
    }

    final batch = _db.batch();

    // Close old version at prevEnd
    batch.update(_col(uid).doc(oldMed.id), {
      'endDate': Timestamp.fromDate(_dateOnly(prevEnd)),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Create new version starting at eff, ending at targetEnd (or keep oldEnd if targetEnd null)
    final newDoc = _col(uid).doc();
    batch.set(newDoc, {
      'groupId': oldMed.groupId,
      'name': name.trim(),
      'dosage': dosage.trim(),
      'frequencyPerDay': frequencyPerDay,
      'notes': notes?.trim(),
      'times': times,
      'isActive': isActive,
      'startDate': Timestamp.fromDate(eff),
      'endDate': (targetEnd == null)
          ? (oldEnd == null ? null : Timestamp.fromDate(oldEnd))
          : Timestamp.fromDate(_dateOnly(targetEnd)),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    // Then notifications:
    // 1) cancel old range
    await NotificationService.instance.cancelMedicationRange(
      medDocId: oldMed.id,
      startDate: oldStart,
      endDate: oldEnd,
      timesCount: oldMed.times.length,
    );

    // 2) reschedule old shortened
    await NotificationService.instance.scheduleMedicationRange(
      medDocId: oldMed.id,
      medName: oldMed.name,
      startDate: oldStart,
      endDate: prevEnd,
      times: oldMed.times,
    );

    // 3) schedule new version
    final newEnd = (targetEnd ?? oldEnd);
    await NotificationService.instance.scheduleMedicationRange(
      medDocId: newDoc.id,
      medName: name.trim(),
      startDate: eff,
      endDate: newEnd,
      times: times,
    );
  }


  Future<Medication?> _getNextVersion({
    required String uid,
    required String groupId,
    required DateTime afterStartDate,
  }) async {
    final snap = await _col(uid)
        .where('groupId', isEqualTo: groupId)
        .where('startDate', isGreaterThan: Timestamp.fromDate(_dateOnly(afterStartDate)))
        .orderBy('startDate')
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    return Medication.fromDoc(snap.docs.first);
  }

  /// Delete for today/future:
  /// - If effectiveDate == med.startDate => delete this version doc
  /// - Else => close at (effectiveDate-1)
  Future<void> deleteMedicationForFuture({
    required String uid,
    required Medication med,
    required DateTime effectiveDate,
  }) async {
    final eff = _dateOnly(effectiveDate);
    final today = _dateOnly(DateTime.now());

    if (eff.isBefore(today)) {
      throw Exception('Cannot delete past days');
    }

    final start = _dateOnly(med.startDate);
    final end = med.endDate == null ? null : _dateOnly(med.endDate!);

    if (end != null && eff.isAfter(end)) {
      throw Exception('Selected date is after this medication end date');
    }

    if (_isSameDay(start, eff)) {
      await NotificationService.instance.cancelMedicationRange(
      medDocId: med.id,
      startDate: med.startDate,
      endDate: med.endDate,
      timesCount: med.times.length,
      );
      
      await _col(uid).doc(med.id).delete();
      return;
    }

    final prevEnd = eff.subtract(const Duration(days: 1));
    if (prevEnd.isBefore(start)) {
      throw Exception('Invalid delete range');
    }

      // cancel old notifications (full old range)
      await NotificationService.instance.cancelMedicationRange(
        medDocId: med.id,
        startDate: start,
        endDate: end,
        timesCount: med.times.length,
      );

      // update endDate
      await _col(uid).doc(med.id).update({
        'endDate': Timestamp.fromDate(_dateOnly(prevEnd)),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // reschedule for shortened range
      await NotificationService.instance.scheduleMedicationRange(
        medDocId: med.id,
        medName: med.name,
        startDate: start,
        endDate: prevEnd,
        times: med.times,
      );

      return;

  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}