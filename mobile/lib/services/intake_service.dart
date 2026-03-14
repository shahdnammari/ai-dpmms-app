import 'package:cloud_firestore/cloud_firestore.dart';

class IntakeService {
  final _db = FirebaseFirestore.instance;

  String _docIdForDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  DocumentReference<Map<String, dynamic>> _docRef({
    required String uid,
    required DateTime date,
  }) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('daily_intake')
        .doc(_docIdForDate(date));
  }

  /// Stream of the entire daily intake document for the given date
  Stream<Map<String, dynamic>> watchDailyIntake({
    required String uid,
    required DateTime date,
  }) {
    return _docRef(uid: uid, date: date).snapshots().map((snap) {
      return snap.data() ?? <String, dynamic>{};
    });
  }

  Future<Map<String, dynamic>> getDailyIntake({
    required String uid,
    required DateTime date,
  }) async {
    final snap = await _docRef(uid: uid, date: date).get();
    return snap.data() ?? <String, dynamic>{};
  }

  /// taken / skipped
  Future<void> setDoseStatus({
    required String uid,
    required DateTime date,
    required String doseKey,
    required String status,
  }) async {
    await _docRef(uid: uid, date: date).set({
      doseKey: {
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      }
    }, SetOptions(merge: true));
  }

  /// Pending
  Future<void> clearDoseStatus({
    required String uid,
    required DateTime date,
    required String doseKey,
  }) async {
    await _docRef(uid: uid, date: date).set({
      doseKey: FieldValue.delete(),
    }, SetOptions(merge: true));
  }

  /// Toggle 
  Future<void> toggleDose({
    required String uid,
    required DateTime date,
    required String doseKey,
    required bool checked,
  }) async {
    if (checked) {
      await setDoseStatus(
        uid: uid,
        date: date,
        doseKey: doseKey,
        status: 'taken',
      );
    } else {
      await clearDoseStatus(
        uid: uid,
        date: date,
        doseKey: doseKey,
      );
    }
  }

  Stream<Map<String, dynamic>> watchCheckedMap(String uid, DateTime date) {
    return watchDailyIntake(uid: uid, date: date).map((data) {
      final result = <String, dynamic>{};
      data.forEach((key, value) {
        if (value is Map && value['status'] == 'taken') {
          result[key] = true;
        }
      });
      return result;
    });
  }

  Future<Map<String, dynamic>> getCheckedMap(String uid, DateTime date) async {
    final data = await getDailyIntake(uid: uid, date: date);
    final result = <String, dynamic>{};
    data.forEach((key, value) {
      if (value is Map && value['status'] == 'taken') {
        result[key] = true;
      }
    });
    return result;
  }
}