import 'package:cloud_firestore/cloud_firestore.dart';

class Medication {
  final String id;
  final String groupId;
  final String name;
  final String dosage;
  final int frequencyPerDay;
  final String? notes;
  final bool isActive;
  final DateTime startDate;
  final DateTime? endDate;
  final List<String> times;

  const Medication({
    required this.id,
    required this.groupId,
    required this.name,
    required this.dosage,
    required this.frequencyPerDay,
    this.notes,
    required this.isActive,
    required this.startDate,
    this.endDate,
    this.times = const [],
  });

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  Map<String, dynamic> toMap() {
    return {
      'name': name.trim(),
      'dosage': dosage.trim(),
      'frequencyPerDay': frequencyPerDay,
      'notes': notes?.trim(),
      'isActive': isActive,
      'startDate': Timestamp.fromDate(_dateOnly(startDate)),
      'endDate': endDate == null ? null : Timestamp.fromDate(_dateOnly(endDate!)),
      'times': times,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static Medication fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    final startTs = data['startDate'];
    final endTs = data['endDate'];

    DateTime startDate;
    if (startTs is Timestamp) {
      startDate = startTs.toDate();
    } else {
      startDate = DateTime.now();
    }

    DateTime? endDate;
    if (endTs is Timestamp) {
      endDate = endTs.toDate();
    }

    return Medication(
      id: doc.id,
      groupId: data['groupId'] as String? ?? doc.id,
      name: (data['name'] as String?) ?? '',
      dosage: (data['dosage'] as String?) ?? '',
      frequencyPerDay: (data['frequencyPerDay'] as int?) ?? 1,
      notes: data['notes'] as String?,
      isActive: (data['isActive'] as bool?) ?? true,
      startDate: _dateOnly(startDate),
      endDate: endDate == null ? null : _dateOnly(endDate),
      times: ((data['times'] as List?) ?? []).map((e) => e.toString()).toList(),
    );
  }
}
