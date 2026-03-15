import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

import '../../models/medication.dart';
import '../../services/medications_service.dart';
import 'medication_form_screen.dart';
import 'medication_details_screen.dart';

class MedicationsListScreen extends StatefulWidget {
  const MedicationsListScreen({super.key});

  @override
  State<MedicationsListScreen> createState() => _MedicationsListScreenState();
}

class _MedicationsListScreenState extends State<MedicationsListScreen> {
  final _service = MedicationsService();
  final _searchCtrl = TextEditingController();

  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  String _query = '';

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  bool _isSameDayOnly(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isMedActiveForDate(Medication med, DateTime day) {
    final start = _dateOnly(med.startDate);
    final target = _dateOnly(day);

    if (target.isBefore(start)) return false;

    if (med.endDate != null) {
      final end = _dateOnly(med.endDate!);
      if (target.isAfter(end)) return false;
    }

    return med.isActive;
  }

  List<Medication> _pickActiveVersionsPerGroup(List<Medication> meds, DateTime day) {
    final activeToday = meds.where((m) => _isMedActiveForDate(m, day)).toList();

    final Map<String, Medication> latestByGroup = {};
    for (final med in activeToday) {
      final key = med.groupId;
      latestByGroup[key] = med;
    }

    final result = latestByGroup.values.toList();
    result.sort((a, b) {
      final at = a.times.isNotEmpty ? a.times.first : '99:99';
      final bt = b.times.isNotEmpty ? b.times.first : '99:99';
      return at.compareTo(bt);
    });

    return result;
  }

  String _formatSelectedDay(DateTime day) {
    return DateFormat('EEE, d MMM yyyy').format(day);
  }

  Future<void> _confirmDelete({
    required String uid,
    required Medication med,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Delete medication?'),
          content: Text(
            'Are you sure you want to delete "${med.name}"?',
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF0B1738),
              ),
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (ok != true) return;

    await _service.deleteMedicationForFuture(
      uid: uid,
      med: med,
      effectiveDate: _selectedDay,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${med.name} deleted')),
    );
  }

  void _goAdd(String uid) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MedicationFormScreen(
          uid: uid,
          effectiveDate: _selectedDay,
        ),
      ),
    );
  }

  void _goEdit(String uid, Medication med) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MedicationFormScreen(
          uid: uid,
          existing: med,
          effectiveDate: _selectedDay,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('No logged in user.'));
    }

    const bg = Color(0xFFF3F6FB);

    return Scaffold(
      backgroundColor: bg,
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        elevation: 8,
        shape: const CircleBorder(),
        onPressed: () => _goAdd(user.uid),
        child: const Icon(Icons.add, size: 32),
      ),
      body: SafeArea(
        
        child: Column(
          children:[
            /// Search + AI
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: (v) {
                            _query = v;
                            setState(() {});
                          },
                          decoration: const InputDecoration(
                            hintText: 'Search medication...',
                            prefixIcon: Icon(
                              Icons.search,
                              color: Color(0xFF1E3A8A),
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const _AiPlaceholderScreen(),
                          ),
                        );
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(
                          Icons.auto_awesome_outlined,
                          color: Color(0xFF1E3A8A),
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
            ),
          
        
      
        Expanded(
        child: StreamBuilder<List<Medication>>(
          stream: _service.watchMedications(user.uid),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final allMeds = snap.data ?? [];
            final medsForDay = _pickActiveVersionsPerGroup(allMeds, _selectedDay);

            final filtered = medsForDay.where((m) {
              final q = _query.trim().toLowerCase();
              if (q.isEmpty) return true;
              return m.name.toLowerCase().contains(q) ||
                  m.dosage.toLowerCase().contains(q);
            }).toList();

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              

                  const SizedBox(height: 14),

                  /// Week calendar
                  Container(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: const [
                        BoxShadow(
                          blurRadius: 10,
                          offset: Offset(0, 4),
                          color: Color(0x11000000),
                        ),
                      ],
                    ),
                    child: TableCalendar(
                      firstDay: DateTime.utc(2020, 1, 1),
                      lastDay: DateTime.utc(2035, 12, 31),
                      focusedDay: _focusedDay,
                      selectedDayPredicate: (day) => _isSameDayOnly(day, _selectedDay),
                      calendarFormat: CalendarFormat.week,
                      availableCalendarFormats: const {
                        CalendarFormat.week: 'Week',
                      },
                      startingDayOfWeek: StartingDayOfWeek.sunday,
                      headerStyle: const HeaderStyle(
                        titleCentered: true,
                        formatButtonVisible: false,
                        leftChevronIcon: Icon(Icons.chevron_left),
                        rightChevronIcon: Icon(Icons.chevron_right),
                        titleTextStyle: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      daysOfWeekStyle: const DaysOfWeekStyle(
                        weekdayStyle: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF334155),
                        ),
                        weekendStyle: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF334155),
                        ),
                      ),
                      calendarStyle: CalendarStyle(
                        outsideDaysVisible: false,
                        defaultTextStyle: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                        weekendTextStyle: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                        todayDecoration: BoxDecoration(
                          color: const Color(0xFFE8EEF9),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF1E3A8A)),
                        ),
                        selectedDecoration: const BoxDecoration(
                          color: Color(0xFF0F172A),
                          shape: BoxShape.circle,
                        ),
                        selectedTextStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      onDaySelected: (selectedDay, focusedDay) {
                        setState(() {
                          _selectedDay = selectedDay;
                          _focusedDay = focusedDay;
                        });
                      },
                      onPageChanged: (focusedDay) {
                        _focusedDay = focusedDay;
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  /// Selected day
                  Text(
                    _formatSelectedDay(_selectedDay),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF334155),
                    ),
                  ),

                  const SizedBox(height: 14),

                  if (filtered.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Text(
                        'No medications for this day.',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                  ...filtered.map((med) {
                    final time = med.times.isNotEmpty ? med.times.first : '--:--';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Slidable(
                        key: ValueKey('${med.id}_${_selectedDay.toIso8601String()}'),
                        endActionPane: ActionPane(
                          motion: const ScrollMotion(),
                          children: [
                            SlidableAction(
                              onPressed: (_) => _confirmDelete(uid: user.uid, med: med),
                              backgroundColor: const Color(0xFFDC2626),
                              foregroundColor: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              icon: Icons.delete_outline,
                              label: 'Delete',
                            ),
                          ],
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () {
                            Navigator.of(context).push(
                              PageRouteBuilder(
                                opaque: false,
                                pageBuilder: (_, _, _) => MedicationDetailsScreen(
                                  medication: med,
                                  uid: user.uid,
                                  effectiveDate: _selectedDay,
                                )
                              ),
                            );
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: const [
                                BoxShadow(
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                  color: Color(0x0E000000),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.medication_outlined,
                                  color: Color(0xFF1E3A8A),
                                  size: 22,
                                ),
                                const SizedBox(width: 12),

                                Expanded(
                                  child: Text(
                                    med.name,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF1E3A8A),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),

                                const SizedBox(width: 12),

                                Text(
                                  time,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1E3A8A),
                                  ),
                                ),

                                const SizedBox(width: 10),

                                PopupMenuButton<String>(
                                  offset: const Offset(-10, 40),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  icon: const Icon(
                                    Icons.more_vert,
                                    color: Color(0xFF64748B),
                                    size: 20,
                                  ),
                                  onSelected: (selected) {
                                    if (selected == 'edit') {
                                      _goEdit(user.uid, med);
                                    } else if (selected == 'delete') {
                                      _confirmDelete(uid: user.uid, med: med);
                                    } else if (selected == 'details') {
                                      Navigator.of(context).push(
                                        PageRouteBuilder(
                                          opaque: false,
                                          pageBuilder: (_, _, _) => MedicationDetailsScreen(
                                            medication: med,
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
                                      child: ListTile(
                                        dense: true,
                                        leading: Icon(Icons.edit_outlined, color: Color(0xFF1E3A8A)),
                                        title: Text(
                                          'Edit',
                                          style: TextStyle(color: Color(0xFF1E3A8A)),
                                        ),
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: ListTile(
                                        dense: true,
                                        leading: Icon(Icons.delete_outline, color: Color(0xFFDC2626)),
                                        title: Text(
                                          'Delete',
                                          style: TextStyle(color: Color(0xFFDC2626)),
                                        ),
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'details',
                                      child: ListTile(
                                        dense: true,
                                        leading: Icon(Icons.info_outline, color: Color(0xFF334155)),
                                        title: Text(
                                          'Details',
                                          style: TextStyle(color: Color(0xFF334155)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            );
          },
        ),
      ),
      ],
    )
    ),
    );
  }
}

class _AiPlaceholderScreen extends StatelessWidget {
  const _AiPlaceholderScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI')),
      body: const Center(
        child: Text(
          'AI Screen Skeleton',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
