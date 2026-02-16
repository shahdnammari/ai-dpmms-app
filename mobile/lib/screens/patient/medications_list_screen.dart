// medications_list_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../models/medication.dart';
import '../../services/medications_service.dart';
import 'medication_form_screen.dart';
import '/widgets/app_motion.dart';

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

  Future<bool> _confirmDelete(BuildContext context, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete "$name"?'),
        content: const Text('This will affect the selected day and future days.'),
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
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final d = _dateOnly(date);
    final dayName = days[d.weekday - 1];
    return '$dayName • ${d.day} ${months[d.month - 1]} ${d.year}';
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

  bool _isMedActiveForDate(Medication m, DateTime day) {
    final d = _dateOnly(day);
    final startOk = !_dateOnly(m.startDate).isAfter(d);
    final endOk = m.endDate == null || !_dateOnly(m.endDate!).isBefore(d);
    return m.isActive && startOk && endOk;
  }

  // ✅ pick only ONE active version per groupId for the selected day
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

  void _goEdit(BuildContext context, String uid, Medication m, DateTime effectiveDate) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MedicationFormScreen(
          uid: uid,
          existing: m,
          effectiveDate: effectiveDate,
        ),
      ),
    );
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
      child: StreamBuilder<List<Medication>>(
        stream: _service.watchMedications(user.uid),
        builder: (context, medsSnap) {
          if (medsSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (medsSnap.hasError) {
            return Center(child: Text('Error: ${medsSnap.error}'));
          }

          var meds = medsSnap.data ?? [];
          meds = _pickActiveVersionsPerGroup(meds, _selectedDay);

          if (_query.isNotEmpty) {
            meds = meds.where((m) {
              final name = m.name.toLowerCase();
              final dosage = m.dosage.toLowerCase();
              return name.contains(_query) || dosage.contains(_query);
            }).toList();
          }

          return StreamBuilder<Map<String, dynamic>>(
            stream: _watchCheckedMap(user.uid, _selectedDay),
            builder: (context, checkedSnap) {
              final checkedMap = checkedSnap.data ?? {};
              final doseItems = _buildDoseItems(meds);
              final total = doseItems.length;

              final taken = doseItems.where((item) {
                final medId = item['medId']!;
                final time = item['time']!;
                final key = _doseKey(medId, time);
                return checkedMap[key] != null; // Timestamp exists => taken
              }).length;

              final progress = total == 0 ? 0.0 : (taken / total);

              return Column(
                children: [
                  // 🔎 Search
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

                  // 📅 Calendar (week)
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

                  // Selected day header
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _formatSelectedHeader(_selectedDay),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Scroll content
                  Expanded(
                    child: CustomScrollView(
                      slivers: [
                        // Summary
                        SliverToBoxAdapter(
                          child: Card(
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
                                    child: TweenAnimationBuilder<double>(
                                      tween: Tween(begin: 0, end: progress),
                                      duration: const Duration(milliseconds: 500),
                                      curve: Curves.easeOutCubic,
                                      builder: (_, v, __) => LinearProgressIndicator(value: v, minHeight: 10),
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
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 10)),

                        if (doseItems.isEmpty)
                          const SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(child: Text('No medications found. Use + to add.')),
                          )
                        else
                          SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, i) {
                                final item = doseItems[i];
                                final medId = item['medId']!;
                                final time = item['time']!;
                                final m = _findMedById(meds, medId);

                                final canToggle = selectedToday;      // ✅ checkbox فقط لليوم
                                final canEditDelete = !selectedPast;  // ✅ actions فقط اليوم/المستقبل

                                final doseKey = _doseKey(m.id, time);
                                final checked = checkedMap[doseKey] != null;
                                final showTime = time.trim().isNotEmpty;

                                // -------- Base Tile --------
                                final baseTile = AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.easeOut,
                                  decoration: BoxDecoration(
                                    color: checked ? Colors.green.withValues(alpha: 0.06) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Card(
                                    margin: const EdgeInsets.symmetric(vertical: 8),
                                    elevation: 2,
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                      title: Text(
                                        m.name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          decoration: checked ? TextDecoration.lineThrough : null,
                                          color: checked ? Colors.green : null,
                                        ),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 4),
                                          Text('${m.dosage} • ${m.frequencyPerDay} / day'),
                                          if (showTime)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 6),
                                              child: Text(
                                                'Time: $time',
                                                style: const TextStyle(fontWeight: FontWeight.w600),
                                              ),
                                            ),
                                        ],
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Checkbox(
                                            value: checked,
                                            onChanged: canToggle
                                                ? (v) => _toggleChecked(user.uid, _selectedDay, m.id, time, v ?? false)
                                                : null,
                                          ),
                                          if (canEditDelete)
                                            PopupMenuButton<String>(
                                              icon: const Icon(Icons.more_vert),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                              onSelected: (value) async {
                                                if (value == 'edit') {
                                                  _goEdit(context, user.uid, m, _selectedDay);
                                                } else if (value == 'delete') {
                                                  final ok = await _confirmDelete(context, m.name);
                                                  if (!ok) return;
                                                  await _service.deleteMedicationForFuture(
                                                    uid: user.uid,
                                                    med: m,
                                                    effectiveDate: _selectedDay,
                                                  );
                                                } else if (value == 'add') {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) => MedicationFormScreen(
                                                        uid: user.uid,
                                                        effectiveDate: _selectedDay,
                                                      ),
                                                    ),
                                                  );
                                                }
                                              },
                                              itemBuilder: (context) => const [
                                                PopupMenuItem(
                                                  value: 'edit',
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.edit),
                                                      SizedBox(width: 12),
                                                      Text('Edit'),
                                                    ],
                                                  ),
                                                ),
                                                PopupMenuItem(
                                                  value: 'delete',
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.delete, color: Colors.red),
                                                      SizedBox(width: 12),
                                                      Text('Delete', style: TextStyle(color: Colors.red)),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );

                                // -------- Build final tile (maybe slidable) --------
                                Widget tile = baseTile;

                                // Swipe delete only when allowed (today/future)
                                if (canEditDelete) {
                                  tile = Slidable(
                                    key: ValueKey(doseKey),
                                    endActionPane: ActionPane(
                                      motion: const DrawerMotion(),
                                      extentRatio: 0.25,
                                      children: [
                                        SlidableAction(
                                          onPressed: (_) async {
                                            final ok = await _confirmDelete(context, m.name);
                                            if (!ok) return;

                                            await _service.deleteMedicationForFuture(
                                              uid: user.uid,
                                              med: m,
                                              effectiveDate: _selectedDay,
                                            );
                                          },
                                          backgroundColor: Colors.red,
                                          foregroundColor: Colors.white,
                                          icon: Icons.delete,
                                          label: 'Delete',
                                        ),
                                      ],
                                    ),
                                    child: baseTile,
                                  );
                                }

                                // ✅ Stagger animation wrapper
                                return StaggerItem(index: i, child: tile);

                              },
                              childCount: doseItems.length,
                            ),
                          ),

                        const SliverToBoxAdapter(child: SizedBox(height: 90)),
                      ],
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