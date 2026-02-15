import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/medication.dart';
import '../../services/medications_service.dart';

class PatientHomeTab extends StatefulWidget {
  const PatientHomeTab({super.key});

  @override
  State<PatientHomeTab> createState() => _PatientHomeTabState();
}

class _PatientHomeTabState extends State<PatientHomeTab> {
  final _service = MedicationsService();

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  String _formatToday() {
    final now = DateTime.now();
    const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${days[now.weekday % 7]}, ${now.day} ${months[now.month - 1]} ${now.year}';
  }

  void _onMenuSelected(String v) {
    if (v == 'settings') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings (soon)')),
      );
    } else if (v == 'emergency') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Emergency (soon)')),
      );
    } else if (v == 'help') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Help / About (soon)')),
      );
    }
  }

  String _dayId(DateTime date) {
    final d = _dateOnly(date);
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  DocumentReference<Map<String, dynamic>> _intakeDoc(String uid, DateTime date) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('daily_intake')
        .doc(_dayId(date));
  }

  Stream<Map<String, dynamic>> _watchCheckedMap(String uid, DateTime date) {
    return _intakeDoc(uid, date).snapshots().map((doc) {
      final data = doc.data();
      return (data?['checked'] as Map<String, dynamic>?) ?? {};
    });
  }

  String _doseKey(String medId, String time) => '${medId}_$time';

  Future<void> _toggleChecked(
    String uid,
    DateTime date,
    String medId,
    String time,
    bool checked,
  ) async {
    final ref = _intakeDoc(uid, date);
    final key = _doseKey(medId, time);

    if (checked) {
      await ref.set({
        'checked': {key: Timestamp.now()}, // takenAt
        'date': Timestamp.fromDate(_dateOnly(date)),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } else {
      await ref.set({
        'checked': {key: FieldValue.delete()},
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  bool _isMedActiveForDate(Medication m, DateTime day) {
    final d = _dateOnly(day);
    final startOk = !_dateOnly(m.startDate).isAfter(d);
    final endOk = m.endDate == null || !_dateOnly(m.endDate!).isBefore(d);
    return m.isActive && startOk && endOk;
  }

  List<Medication> _pickActiveVersionsPerGroup(List<Medication> meds, DateTime day) {
    final map = <String, Medication>{};

    for (final m in meds) {
      if (!_isMedActiveForDate(m, day)) continue;

      final key = m.groupId;
      final existing = map[key];

      if (existing == null || m.startDate.isAfter(existing.startDate)) {
        map[key] = m;
      }
    }

    final res = map.values.toList();
    res.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return res;
  }

  List<Map<String, String>> _buildDoseItems(List<Medication> meds) {
    final items = <Map<String, String>>[];
    for (final m in meds) {
      final times = m.times.isEmpty ? <String>[''] : m.times;
      for (final t in times) {
        items.add({'medId': m.id, 'time': t});
      }
    }
    return items;
  }

  Medication _findMedById(List<Medication> meds, String id) {
    return meds.firstWhere((m) => m.id == id);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    final today = _dateOnly(DateTime.now());

    return Padding(
      padding: const EdgeInsets.all(16),
      child: StreamBuilder<List<Medication>>(
        stream: _service.watchMedications(user.uid),
        builder: (context, medsSnap) {
          if (medsSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (medsSnap.hasError) return Center(child: Text('Error: ${medsSnap.error}'));

          var meds = medsSnap.data ?? [];
          meds = _pickActiveVersionsPerGroup(meds, today);

          return StreamBuilder<Map<String, dynamic>>(
            stream: _watchCheckedMap(user.uid, today),
            builder: (context, checkedSnap) {
              final checkedMap = checkedSnap.data ?? {};
              final doseItems = _buildDoseItems(meds);
              final total = doseItems.length;

              final taken = doseItems.where((item) {
                final medId = item['medId']!;
                final time = item['time']!;
                final key = _doseKey(medId, time);
                return checkedMap[key] != null;
              }).length;

              final progress = total == 0 ? 0.0 : (taken / total);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatToday(),
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      PopupMenuButton<String>(
                        onSelected: _onMenuSelected,
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'settings', child: Text('Settings')),
                          PopupMenuItem(value: 'emergency', child: Text('Emergency')),
                          PopupMenuItem(value: 'help', child: Text('Help / About')),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  const Text(
                    'Checklist for Today',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),

                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Taken $taken / $total', style: const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(value: progress, minHeight: 10),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (doseItems.isEmpty)
                    const Expanded(
                      child: Center(child: Text('No medications for today. Use + to add.')),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        itemCount: doseItems.length,
                        itemBuilder: (context, i) {
                          final item = doseItems[i];
                          final medId = item['medId']!;
                          final time = item['time']!;
                          final m = _findMedById(meds, medId);

                          final key = _doseKey(medId, time);
                          final checked = checkedMap[key] != null;
                          final showTime = time.trim().isNotEmpty;

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            child: CheckboxListTile(
                              value: checked,
                              onChanged: (v) => _toggleChecked(user.uid, today, medId, time, v ?? false),
                              controlAffinity: ListTileControlAffinity.leading,
                              title: Text(
                                m.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  decoration: checked ? TextDecoration.lineThrough : null,
                                  color: checked ? Colors.green : null,
                                ),
                              ),
                              subtitle: Text(
                                showTime
                                    ? '${m.dosage} • $time'
                                    : '${m.dosage} • ${m.frequencyPerDay} / day',
                              ),
                              secondary: checked
                                  ? const Icon(Icons.check_circle, color: Colors.green)
                                  : const Icon(Icons.medication_outlined),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}