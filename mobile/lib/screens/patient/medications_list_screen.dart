import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../models/medication.dart';
import '../../services/medications_service.dart';
import 'medication_form_screen.dart';

class MedicationsListScreen extends StatefulWidget {
  const MedicationsListScreen({super.key});

  @override
  State<MedicationsListScreen> createState() => _MedicationsListScreenState();
}

class _MedicationsListScreenState extends State<MedicationsListScreen> {
  final _service = MedicationsService();
  final _searchCtrl = TextEditingController();

  String _query = '';

  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  bool _isPast(DateTime day) {
    final today = _dateOnly(DateTime.now());
    final target = _dateOnly(day);
    return target.isBefore(today);
  }

  bool _isToday(DateTime day) {
    final today = _dateOnly(DateTime.now());
    final target = _dateOnly(day);
    return target.isAtSameMomentAs(today);
  }

  String _dayId(DateTime date) {
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    return '${date.year}-$mm-$dd';
  }

  DocumentReference<Map<String, dynamic>> _intakeDoc(String uid, DateTime date) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('daily_intake')
        .doc(_dayId(date));
  }

  Stream<Set<String>> _watchCheckedIds(String uid, DateTime date) {
    return _intakeDoc(uid, date).snapshots().map((doc) {
      final data = doc.data();
      final list = (data?['checkedMedIds'] as List?) ?? [];
      return list.map((e) => e.toString()).toSet();
    });
  }

  Future<void> _toggleChecked(String uid, DateTime date, String medId, bool checked) async {
    final ref = _intakeDoc(uid, date);

    if (checked) {
      await ref.set({
        'checkedMedIds': FieldValue.arrayUnion([medId]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } else {
      await ref.set({
        'checkedMedIds': FieldValue.arrayRemove([medId]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<bool> _confirmDelete(BuildContext context, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete "$name"?'),
        content: Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  String _formatSelectedHeader(DateTime date) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final d = _dateOnly(date);
    final dayName = days[d.weekday - 1];
    return '$dayName • ${d.day} ${months[d.month - 1]} ${d.year}';
  }

  int _countTakenFrom(Set<String> checkedIds, List<Medication> meds) {
    final medIds = meds.map((m) => m.id).toSet();
    return checkedIds.where((id) => medIds.contains(id)).length;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Not logged in'));
    }

    final selectedPast = _isPast(_selectedDay);
    final selectedToday = _isToday(_selectedDay);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Search medication...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _query = '');
                      },
                    ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),

          Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: TableCalendar(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2035, 12, 31),
                focusedDay: _focusedDay,
                calendarFormat: CalendarFormat.week,
                availableCalendarFormats: const {CalendarFormat.week: 'Week'},
                headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },
              ),
            ),
          ),

          const SizedBox(height: 12),

          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _formatSelectedHeader(_selectedDay),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 10),

          Expanded(
            child: StreamBuilder<List<Medication>>(
              stream: _service.watchMedications(user.uid),
              builder: (context, medsSnap) {
                if (medsSnap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (medsSnap.hasError) return Center(child: Text('Error: ${medsSnap.error}'));

                var meds = (medsSnap.data ?? []).where((m) => m.isActive).toList();

                if (_query.isNotEmpty) {
                  meds = meds.where((m) {
                    final name = m.name.toLowerCase();
                    final dosage = m.dosage.toLowerCase();
                    return name.contains(_query) || dosage.contains(_query);
                  }).toList();
                }

                return StreamBuilder<Set<String>>(
                  stream: _watchCheckedIds(user.uid, _selectedDay),
                  builder: (context, checkedSnap) {
                    final checkedIds = checkedSnap.data ?? <String>{};

                    final total = meds.length;
                    final taken = _countTakenFrom(checkedIds, meds);
                    final progress = total == 0 ? 0.0 : (taken / total);

                    return Column(
                      children: [
                        Card(
                          elevation: 1,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Taken $taken / $total',
                                      style: const TextStyle(fontWeight: FontWeight.w700),
                                    ),
                                    Text(
                                      '${(progress * 100).round()}%',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    minHeight: 10,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  selectedPast
                                      ? 'Past day: history view'
                                      : (selectedToday ? 'Today: you can mark taken' : 'Future day: plan view'),
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        if (meds.isEmpty)
                          const Expanded(
                            child: Center(child: Text('No medications found. Use + to add.')),
                          )
                        else
                          Expanded(
                            child: ListView.builder(
                              itemCount: meds.length,
                              itemBuilder: (context, i) {
                                final m = meds[i];
                                final checked = checkedIds.contains(m.id);

                                final canToggle = selectedToday;
                                final canEditDelete = !selectedPast;

                                return Slidable(
                                  key: ValueKey(m.id),
                                  enabled: canEditDelete,
                                  startActionPane: canEditDelete
                                      ? ActionPane(
                                          motion: const StretchMotion(),
                                          children: [
                                            SlidableAction(
                                              onPressed: (_) {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) => MedicationFormScreen(
                                                      uid: user.uid,
                                                      existing: m,
                                                    ),
                                                  ),
                                                );
                                              },
                                              icon: Icons.edit,
                                              label: 'Edit',
                                            ),
                                          ],
                                        )
                                      : null,
                                  endActionPane: canEditDelete
                                      ? ActionPane(
                                          motion: const DrawerMotion(),
                                          children: [
                                            SlidableAction(
                                              onPressed: (_) async {
                                                final ok = await _confirmDelete(context, m.name);
                                                if (!ok) return;
                                                await _service.deleteMedication(
                                                  uid: user.uid,
                                                  medId: m.id,
                                                );
                                              },
                                              backgroundColor: Colors.red,
                                              foregroundColor: Colors.white,
                                              icon: Icons.delete,
                                              label: 'Delete',
                                            )
                                          ],
                                        )
                                      : null,
                                  child: Card(
                                    margin: const EdgeInsets.symmetric(vertical: 8),
                                    elevation: 2,
                                    child: ListTile(
                                      leading: Icon(
                                        checked ? Icons.check_circle : Icons.medication_outlined,
                                        color: checked ? Colors.green : Colors.grey,
                                      ),
                                      title: Text(
                                        m.name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          decoration: checked ? TextDecoration.lineThrough : null,
                                          color: checked ? Colors.green : null,
                                        ),
                                      ),
                                      subtitle: Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text('${m.dosage} • ${m.frequencyPerDay} / day'),
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Checkbox(
                                            value: checked,
                                            onChanged: canToggle
                                                ? (v) => _toggleChecked(user.uid, _selectedDay, m.id, v ?? false)
                                                : null,
                                          ),
                                          if (canEditDelete)
                                            PopupMenuButton<String>(
                                              onSelected: (value) async {
                                                if (value == 'edit') {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) => MedicationFormScreen(
                                                        uid: user.uid,
                                                        existing: m,
                                                      ),
                                                    ),
                                                  );
                                                } else if (value == 'delete') {
                                                  final ok = await _confirmDelete(context, m.name);
                                                  if (!ok) return;
                                                  await _service.deleteMedication(
                                                    uid: user.uid,
                                                    medId: m.id,
                                                  );
                                                }
                                              },
                                              itemBuilder: (_) => const [
                                                PopupMenuItem(value: 'edit', child: Text('Edit')),
                                                PopupMenuItem(value: 'delete', child: Text('Delete')),
                                              ],
                                            ),
                                        ],
                                      ),
                                    ),
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
          ),
        ],
      ),
    );
  }
}