import 'package:cloud_firestore/cloud_firestore.dart';

class Medication {
  final String id;
  final String groupId;
  final String name;
  final String dosage;
  final int frequencyPerDay;
  final String? notes;
  final DateTime startDate;
  final DateTime? endDate;
  final List<String> times;
  final List<String> repeatDays;    // e.g. ['Mon','Tue','Wed','Thu','Fri','Sat','Sun']
  final bool reminderEnabled;       // true = إشعارات مفعلة

  const Medication({
    required this.id,
    required this.groupId,
    required this.name,
    required this.dosage,
    required this.frequencyPerDay,
    this.notes,
    required this.startDate,
    this.endDate,
    this.times = const [],
    this.repeatDays = const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
    this.reminderEnabled = true,
  });

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// الأيام الكاملة السبعة — الديفولت إذا ما اختار المستخدم
  static const List<String> allDays = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
  ];

  Map<String, dynamic> toMap() {
    return {
      'name': name.trim(),
      'dosage': dosage.trim(),
      'frequencyPerDay': frequencyPerDay,
      'notes': notes?.trim(),
      'startDate': Timestamp.fromDate(_dateOnly(startDate)),
      'endDate': endDate == null ? null : Timestamp.fromDate(_dateOnly(endDate!)),
      'times': times,
      'repeatDays': repeatDays,
      'reminderEnabled': reminderEnabled,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static Medication fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    final startTs = data['startDate'];
    final endTs   = data['endDate'];

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

    // ── repeatDays ──────────────────────────────────────────────
    // الأدوية القديمة بـ Firestore ما عندها repeatDays
    // الديفولت = كل الأيام عشان ما نكسر السلوك القديم
    final rawDays = data['repeatDays'];
    final List<String> repeatDays = (rawDays is List && rawDays.isNotEmpty)
        ? rawDays.map((e) => e.toString()).toList()
        : List<String>.from(allDays);

    // ── reminderEnabled ──────────────────────────────────────────
    // الأدوية القديمة ما عندها reminderEnabled → ديفولت true
    final reminderEnabled = (data['reminderEnabled'] as bool?) ?? true;

    return Medication(
      id: doc.id,
      groupId: data['groupId'] as String? ?? doc.id,
      name: (data['name'] as String?) ?? '',
      dosage: (data['dosage'] as String?) ?? '',
      frequencyPerDay: (data['frequencyPerDay'] as int?) ?? 1,
      notes: data['notes'] as String?,
      startDate: _dateOnly(startDate),
      endDate: endDate == null ? null : _dateOnly(endDate),
      times: ((data['times'] as List?) ?? []).map((e) => e.toString()).toList(),
      repeatDays: repeatDays,
      reminderEnabled: reminderEnabled,
    );
  }
}