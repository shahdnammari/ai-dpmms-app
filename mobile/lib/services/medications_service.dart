// medications_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/medication.dart';

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
  }) async {
    final eff = _dateOnly(effectiveDate);
    final today = _dateOnly(DateTime.now());
    final oldStart = _dateOnly(oldMed.startDate);
    final oldEnd = oldMed.endDate == null ? null : _dateOnly(oldMed.endDate!);

    // 1) No past edits
    if (eff.isBefore(today)) {
      throw Exception('Cannot edit past days');
    }

    // 2) If medication version has an endDate, effectiveDate must be within its range
    if (oldEnd != null && eff.isAfter(oldEnd)) {
      throw Exception('Selected date is after this medication end date');
    }

    // Special case: editing a FUTURE version on its first effective day
    // (otherwise versioning would create invalid old.endDate < old.startDate)
    final isSameAsOldStart = _isSameDay(oldStart, eff);
    final oldStartIsFutureOrToday = !oldStart.isBefore(today);

    if (isSameAsOldStart && oldStartIsFutureOrToday) {
      await _col(uid).doc(oldMed.id).update({
        'groupId': oldMed.groupId, // ensure exists
        'name': name.trim(),
        'dosage': dosage.trim(),
        'frequencyPerDay': frequencyPerDay,
        'notes': notes?.trim(),
        'times': times,
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return;
    }

    // 3) Versioning
    final prevEnd = eff.subtract(const Duration(days: 1));

    // Safety: make sure we are not making an invalid range
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
      'isActive': isActive,
      'startDate': Timestamp.fromDate(eff),
      // IMPORTANT: keep old endDate as it was
      'endDate': oldEnd == null ? null : Timestamp.fromDate(oldEnd),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
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
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}