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
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Medication.fromDoc).toList());
  }

  Future<void> addMedication({
    required String uid,
    required String name,
    required String dosage,
    required int frequencyPerDay,
    String? notes,
  }) async {
    final med = Medication(
      id: '',
      name: name,
      dosage: dosage,
      frequencyPerDay: frequencyPerDay,
      notes: notes,
      isActive: true,
      createdAt: null,
      updatedAt: null,
    );

    await _col(uid).add(med.toMap());
  }

  Future<void> updateMedication({
    required String uid,
    required String medId,
    required String name,
    required String dosage,
    required int frequencyPerDay,
    String? notes,
    required bool isActive,
  }) async {
    await _col(uid).doc(medId).update({
      'name': name.trim(),
      'dosage': dosage.trim(),
      'frequencyPerDay': frequencyPerDay,
      'notes': notes?.trim(),
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteMedication({
    required String uid,
    required String medId,
  }) async {
    await _col(uid).doc(medId).delete();
  }
}
