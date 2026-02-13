import 'package:cloud_firestore/cloud_firestore.dart';

class Medication {
  final String id;
  final String name;
  final String dosage;
  final int frequencyPerDay;
  final String? notes;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Medication({
    required this.id,
    required this.name,
    required this.dosage,
    required this.frequencyPerDay,
    this.notes,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name.trim(),
      'dosage': dosage.trim(),
      'frequencyPerDay': frequencyPerDay,
      'notes': notes?.trim(),
      'isActive': isActive,
      'createdAt': createdAt == null ? FieldValue.serverTimestamp() : Timestamp.fromDate(createdAt!),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static Medication fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Medication(
      id: doc.id,
      name: (data['name'] as String? ?? ''),
      dosage: (data['dosage'] as String? ?? ''),
      frequencyPerDay: (data['frequencyPerDay'] as int? ?? 1),
      notes: data['notes'] as String?,
      isActive: (data['isActive'] as bool? ?? true),
      createdAt: (data['createdAt'] is Timestamp) ? (data['createdAt'] as Timestamp).toDate() : null,
      updatedAt: (data['updatedAt'] is Timestamp) ? (data['updatedAt'] as Timestamp).toDate() : null,
    );
  }
}
