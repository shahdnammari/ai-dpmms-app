import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:ai_dpmms_mobile/services/app_refresh.dart';

import '../../l10n/app_strings.dart';
import '../../models/medication.dart';
import '../../services/medications_service.dart';
import 'medication_form_screen.dart';
import 'medication_details_screen.dart';
import 'ai_screen.dart';

class MedicationsListScreen extends StatefulWidget {
  const MedicationsListScreen({super.key});

  @override
  State<MedicationsListScreen> createState() => _MedicationsListScreenState();
}

class _MedicationsListScreenState extends State<MedicationsListScreen> {
  final _service    = MedicationsService();
  final _searchCtrl = TextEditingController();
  VoidCallback? _refreshListener;

  DateTime _focusedDay  = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  String   _query       = '';

  @override
  void initState() {
    super.initState();
    _refreshListener = () {
      if (mounted) setState(() {});
    };
    AppRefresh.notifier.addListener(_refreshListener!);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    if (_refreshListener != null) {
      AppRefresh.notifier.removeListener(_refreshListener!);
    }
    super.dispose();
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  bool _isSameDayOnly(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool get _isSelectedDayPast {
    final today    = _dateOnly(DateTime.now());
    final selected = _dateOnly(_selectedDay);
    return selected.isBefore(today);
  }

  bool _isMedActiveForDate(Medication med, DateTime day) {
    final start  = _dateOnly(med.startDate);
    final target = _dateOnly(day);
    if (target.isBefore(start)) return false;
    if (med.endDate != null && target.isAfter(_dateOnly(med.endDate!))) {
      return false;
    }
    return true;
  }

  List<Medication> _pickActiveVersionsPerGroup(List<Medication> meds, DateTime day) {
    final activeToday = meds.where((m) => _isMedActiveForDate(m, day)).toList();
    final Map<String, Medication> latestByGroup = {};
    for (final med in activeToday) {
      latestByGroup[med.groupId] = med;
    }
    final result = latestByGroup.values.toList();
    result.sort((a, b) {
      final at = a.times.isNotEmpty ? a.times.first : '99:99';
      final bt = b.times.isNotEmpty ? b.times.first : '99:99';
      return at.compareTo(bt);
    });
    return result;
  }

  String _formatSelectedDay(DateTime day) =>
      DateFormat('EEE, d MMM yyyy').format(day);

  Future<void> _onRefresh() async {
    AppRefresh.trigger();
    await Future.delayed(const Duration(milliseconds: 400));
  }

  Future<void> _confirmDelete({required String uid, required Medication med}) async {
    final s  = S.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(s.deleteMedTitle,
            style: const TextStyle(fontWeight: FontWeight.w800)),
        content: Text(s.deleteConfirm(med.name)),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF0B1738)),
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.delete),
          ),
        ],
      ),
    );
    if (ok != true) return;

    await _service.deleteMedicationForFuture(
      uid: uid, med: med, effectiveDate: _selectedDay,
    );
    AppRefresh.trigger();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(S.of(context).medDeleted(med.name))),
    );
  }

  void _goAdd(String uid) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MedicationFormScreen(
          uid: uid,
          effectiveDate: _selectedDay,
          source: MedicationFormSource.medicationsList,
        ),
      ),
    );
    AppRefresh.trigger();
  }

  void _goEdit(String uid, Medication med) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MedicationFormScreen(
          uid: uid,
          existing: med,
          effectiveDate: _selectedDay,
          source: MedicationFormSource.medicationsList,
        ),
      ),
    );
    AppRefresh.trigger();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('No logged in user.'));
    }

    final s        = S.of(context);
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final bg       = Theme.of(context).scaffoldBackgroundColor;
    final surface  = Theme.of(context).colorScheme.surface;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final isReadOnly = _isSelectedDayPast;

    return Scaffold(
      backgroundColor: bg,
      floatingActionButton: FloatingActionButton(
        backgroundColor:
            isReadOnly ? const Color(0xFFB0BEC5) : const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        elevation: 8,
        shape: const CircleBorder(),
        onPressed: isReadOnly ? null : () => _goAdd(user.uid),
        child: const Icon(Icons.add, size: 32),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF3A3A5C)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (v) => setState(() => _query = v),
                        style: TextStyle(color: onSurface),
                        decoration: InputDecoration(
                          hintText: s.searchHint,
                          hintStyle: TextStyle(
                            color: onSurface.withValues(alpha: 0.4),
                          ),
                          prefixIcon: const Icon(Icons.search,
                              color: Color(0xFF1E3A8A)),
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 12),
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
                        MaterialPageRoute(builder: (_) => const AiScreen()),
                      );
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.auto_awesome_outlined,
                          color: Color(0xFF1E3A8A), size: 22),
                    ),
                  ),
                ],
              ),
            ),

            // List
            Expanded(
              child: StreamBuilder<List<Medication>>(
                stream: _service.watchMedications(user.uid),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final allMeds    = snap.data ?? [];
                  final medsForDay = _pickActiveVersionsPerGroup(allMeds, _selectedDay);

                  final filtered = medsForDay.where((m) {
                    final q = _query.trim().toLowerCase();
                    if (q.isEmpty) return true;
                    return m.name.toLowerCase().contains(q) ||
                        m.dosage.toLowerCase().contains(q);
                  }).toList();

                  return RefreshIndicator(
                    onRefresh: _onRefresh,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Week calendar
                          Container(
                            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                            decoration: BoxDecoration(
                              color: surface,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                  color: Colors.black
                                      .withValues(alpha: isDark ? 0.25 : 0.07),
                                ),
                              ],
                            ),
                            child: TableCalendar(
                              firstDay: DateTime.utc(2020, 1, 1),
                              lastDay: DateTime.utc(2035, 12, 31),
                              focusedDay: _focusedDay,
                              selectedDayPredicate: (day) =>
                                  _isSameDayOnly(day, _selectedDay),
                              calendarFormat: CalendarFormat.week,
                              availableCalendarFormats: const {
                                CalendarFormat.week: 'Week',
                              },
                              startingDayOfWeek: StartingDayOfWeek.sunday,
                              headerStyle: HeaderStyle(
                                titleCentered: true,
                                formatButtonVisible: false,
                                leftChevronIcon: Icon(Icons.chevron_left,
                                    color: onSurface),
                                rightChevronIcon: Icon(Icons.chevron_right,
                                    color: onSurface),
                                titleTextStyle: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: onSurface,
                                ),
                              ),
                              daysOfWeekStyle: DaysOfWeekStyle(
                                weekdayStyle: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: onSurface.withValues(alpha: 0.7),
                                ),
                                weekendStyle: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: onSurface.withValues(alpha: 0.7),
                                ),
                              ),
                              calendarStyle: CalendarStyle(
                                outsideDaysVisible: false,
                                defaultTextStyle: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: onSurface,
                                ),
                                weekendTextStyle: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: onSurface,
                                ),
                                todayDecoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF1E3A8A).withValues(alpha: 0.3)
                                      : const Color(0xFFE8EEF9),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: const Color(0xFF1E3A8A)),
                                ),
                                selectedDecoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF1E3A8A)
                                      : const Color(0xFF0F172A),
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
                                  _focusedDay  = focusedDay;
                                });
                              },
                              onPageChanged: (focusedDay) {
                                _focusedDay = focusedDay;
                              },
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Selected day label + View Only badge
                          Row(
                            children: [
                              Text(
                                _formatSelectedDay(_selectedDay),
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: onSurface,
                                ),
                              ),
                              if (isReadOnly) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF3A3A5C)
                                        : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isDark
                                          ? const Color(0xFF4A4A6C)
                                          : const Color(0xFFCBD5E1),
                                    ),
                                  ),
                                  child: Text(
                                    s.viewOnly,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),

                          const SizedBox(height: 14),

                          // Empty state
                          if (filtered.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: surface,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Text(
                                s.noMedsDay,
                                style: TextStyle(
                                  color: onSurface.withValues(alpha: 0.5),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),

                          // Medication cards
                          ...filtered.map((med) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: isReadOnly
                                  ? InkWell(
                                      borderRadius: BorderRadius.circular(18),
                                      onTap: () => Navigator.of(context).push(
                                        PageRouteBuilder(
                                          opaque: false,
                                          pageBuilder: (_, _, _) =>
                                              MedicationDetailsScreen(
                                            medication: med,
                                            uid: user.uid,
                                            effectiveDate: _selectedDay,
                                          ),
                                        ),
                                      ),
                                      child: _MedicationCard(
                                        med: med,
                                        isReadOnly: true,
                                        s: s,
                                        onEdit: () {},
                                        onDelete: () {},
                                        onDetails: () =>
                                            Navigator.of(context).push(
                                          PageRouteBuilder(
                                            opaque: false,
                                            pageBuilder: (_, _, _) =>
                                                MedicationDetailsScreen(
                                              medication: med,
                                              uid: user.uid,
                                              effectiveDate: _selectedDay,
                                            ),
                                          ),
                                        ),
                                      ),
                                    )
                                  : Slidable(
                                      key: ValueKey(
                                          '${med.id}_${_selectedDay.toIso8601String()}'),
                                      endActionPane: ActionPane(
                                        motion: const ScrollMotion(),
                                        children: [
                                          SlidableAction(
                                            onPressed: (_) => _confirmDelete(
                                                uid: user.uid, med: med),
                                            backgroundColor:
                                                const Color(0xFFDC2626),
                                            foregroundColor: Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            icon: Icons.delete_outline,
                                            label: s.delete,
                                          ),
                                        ],
                                      ),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(18),
                                        onTap: () =>
                                            Navigator.of(context).push(
                                          PageRouteBuilder(
                                            opaque: false,
                                            pageBuilder: (_, _, _) =>
                                                MedicationDetailsScreen(
                                              medication: med,
                                              uid: user.uid,
                                              effectiveDate: _selectedDay,
                                            ),
                                          ),
                                        ),
                                        child: _MedicationCard(
                                          med: med,
                                          isReadOnly: false,
                                          s: s,
                                          onEdit: () => _goEdit(user.uid, med),
                                          onDelete: () => _confirmDelete(
                                              uid: user.uid, med: med),
                                          onDetails: () =>
                                              Navigator.of(context).push(
                                            PageRouteBuilder(
                                              opaque: false,
                                              pageBuilder: (_, _, _) =>
                                                  MedicationDetailsScreen(
                                                medication: med,
                                                uid: user.uid,
                                                effectiveDate: _selectedDay,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                            );
                          }),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Medication Card

class _MedicationCard extends StatelessWidget {
  final Medication med;
  final bool isReadOnly;
  final S s;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onDetails;

  const _MedicationCard({
    required this.med,
    required this.isReadOnly,
    required this.s,
    required this.onEdit,
    required this.onDelete,
    required this.onDetails,
  });

  @override
  Widget build(BuildContext context) {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final surface  = Theme.of(context).colorScheme.surface;
    final timesText = med.times.isNotEmpty ? med.times.join(' · ') : '--:--';

    final cardColor = isReadOnly
        ? (isDark ? surface.withValues(alpha: 0.6) : const Color(0xFFF8FAFC))
        : surface;

    final nameColor = isReadOnly
        ? const Color(0xFF94A3B8)
        : const Color(0xFF1E3A8A);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? const Color(0xFF3A3A5C)
              : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 10,
            offset: const Offset(0, 4),
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.medication_outlined,
            color: nameColor,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  med.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: nameColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  timesText,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            offset: const Offset(-10, 40),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            icon: const Icon(Icons.more_vert,
                color: Color(0xFF64748B), size: 20),
            onSelected: (selected) {
              if (selected == 'edit') {
                onEdit();
              } else if (selected == 'delete') {
                onDelete();
              } else if (selected == 'details') {
                onDetails();
              }
            },
            itemBuilder: (context) => [
              if (!isReadOnly)
                PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    dense: true,
                    leading: const Icon(Icons.edit_outlined,
                        color: Color(0xFF1E3A8A)),
                    title: Text(s.edit,
                        style: const TextStyle(color: Color(0xFF1E3A8A))),
                  ),
                ),
              if (!isReadOnly)
                PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    dense: true,
                    leading: const Icon(Icons.delete_outline,
                        color: Color(0xFFDC2626)),
                    title: Text(s.delete,
                        style: const TextStyle(color: Color(0xFFDC2626))),
                  ),
                ),
              PopupMenuItem(
                value: 'details',
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.info_outline,
                      color: Color(0xFF334155)),
                  title: Text(s.details,
                      style: const TextStyle(color: Color(0xFF334155))),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
