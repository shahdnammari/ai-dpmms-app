// medication_details_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../models/medication.dart';
import '../../services/intake_service.dart';
import '../../services/medications_service.dart';
import 'medication_form_screen.dart';

class MedicationDetailsScreen extends StatefulWidget {
  final Medication medication;
  final String uid;
  final DateTime effectiveDate;

  const MedicationDetailsScreen({
    super.key,
    required this.medication,
    required this.uid,
    required this.effectiveDate,
  });

  @override
  State<MedicationDetailsScreen> createState() =>
      _MedicationDetailsScreenState();
}

class _MedicationDetailsScreenState
    extends State<MedicationDetailsScreen> {
  final _intakeService = IntakeService();

  static const Color _dark  = Color(0xFF0B1738);
  static const Color _red   = Color(0xFFDC2626);
  static const Color _green = Color(0xFF16A34A);

  // Delete

  Future<void> _confirmDelete() async {
    final service = MedicationsService();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete medication?',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text(
            'Are you sure you want to delete "${widget.medication.name}"?'),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: _dark),
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    await service.deleteMedicationForFuture(
      uid: widget.uid,
      med: widget.medication,
      effectiveDate: widget.effectiveDate,
    );

    if (!mounted) return;
    Navigator.pop(context);
  }

  // Edit

  void _goEdit() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MedicationFormScreen(
          uid: widget.uid,
          existing: widget.medication,
          effectiveDate: widget.effectiveDate,
          source: MedicationFormSource.medicationsList,
        ),
      ),
    );
  }

  // Texts helpers

  String get _timeText {
    if (widget.medication.times.isEmpty) return '--:--';
    return widget.medication.times.join(' · ');
  }

  String get _scheduleText {
    final n = widget.medication.times.isNotEmpty
        ? widget.medication.times.length
        : widget.medication.frequencyPerDay;
    return n <= 1 ? '1 time per day' : '$n times per day';
  }

  String get _repeatText {
    final days = widget.medication.repeatDays;
    if (days.length == 7) return 'Every day';
    if (days.isEmpty)     return 'No repeat days';


    const order = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final sorted = days
        .where(order.contains)
        .toList()
      ..sort((a, b) => order.indexOf(a).compareTo(order.indexOf(b)));
    return sorted.join(', ');
  }

  // Recent activity

  Future<List<_ActivityItem>> _loadRecentActivity() async {
    final List<_ActivityItem> items = [];

    final times = widget.medication.times.isNotEmpty
        ? widget.medication.times
        : ['08:00'];

    for (int i = 1; i <= 4; i++) {
      final day = DateTime.now().subtract(Duration(days: i));

      for (final time in times) {
        final doseKey = '${widget.medication.id}_$time';
        final status = await _intakeService.getDoseStatus(
          uid: widget.uid,
          date: day,
          doseKey: doseKey,
        );

        if (status == 'taken') {
          items.add(_ActivityItem(
            date: day,
            time: time,
            label: 'Taken',
            color: _green,
          ));
        } else if (status == 'skipped') {
          items.add(_ActivityItem(
            date: day,
            time: time,
            label: 'Skipped',
            color: _red,
          ));
        }
      }
    }

    items.sort((a, b) => b.date.compareTo(a.date));
    return items;
  }

  // build

  @override
  Widget build(BuildContext context) {
    final med = widget.medication;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Blur backdrop
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                color: Colors.black.withValues(alpha: 0.25),
              ),
            ),
          ),

          // X button
          Positioned(
            top: 80,
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: _dark, size: 26),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // Card
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 24),
                child: GestureDetector(
                  onTap: () {},
                  child: Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 420),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: _dark,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: const [
                        BoxShadow(
                          blurRadius: 28,
                          offset: Offset(0, 10),
                          color: Color(0x33000000),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          // Header
                          Row(
                            children: [
                              const Icon(Icons.info_outline,
                                  color: Colors.white),
                              const SizedBox(width: 8),
                              const Text('Details',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18,
                                  )),
                              const Spacer(),
                              IconButton(
                                onPressed: _confirmDelete,
                                icon: const Icon(Icons.delete_outline,
                                    color: _red),
                              ),
                              IconButton(
                                onPressed: _goEdit,
                                icon: const Icon(Icons.edit_outlined,
                                    color: Colors.white),
                              ),
                            ],
                          ),

                          const SizedBox(height: 14),

                          // Main info card
                          _card(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _row(Icons.medication_outlined, med.name),
                                const SizedBox(height: 10),
                                _row(Icons.science_outlined, med.dosage),
                              ],
                            ),
                          ),

                          const SizedBox(height: 18),

                          // Schedule
                          const _SectionTitle('Schedule'),
                          const SizedBox(height: 8),
                          _card(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [

                                Text(
                                  _timeText,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _scheduleText,
                                  style: const TextStyle(
                                    color: Color(0xFF334155),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 18),

                          // Repeat days
                          const _SectionTitle('Repeat'),
                          const SizedBox(height: 8),
                          _card(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _repeatText,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF334155),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                _RepeatDaysRow(
                                    repeatDays: med.repeatDays),
                              ],
                            ),
                          ),

                          const SizedBox(height: 18),

                          // Reminder
                          _card(
                            child: Row(
                              children: [
                                const Icon(
                                    Icons.notifications_outlined),
                                const SizedBox(width: 10),
                                const Text('Reminder',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w700)),
                                const Spacer(),
                                Switch(
                                  value: med.reminderEnabled,
                                  onChanged: null, // read-only
                                  thumbColor: WidgetStateProperty.all(
                                      Colors.white),
                                  trackColor: WidgetStateProperty
                                      .resolveWith((states) {
                                    if (states.contains(
                                        WidgetState.selected)) {
                                      return _green;
                                    }
                                    return Colors.grey;
                                  }),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 18),

                          // Note
                          const _SectionTitle('Note'),
                          const SizedBox(height: 8),
                          _card(
                            child: Text(
                              (med.notes?.trim().isNotEmpty ?? false)
                                  ? med.notes!.trim()
                                  : '-',
                              style: const TextStyle(
                                color: Color(0xFF0F172A),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),

                          const SizedBox(height: 18),

                          // Recent Activity
                          const _SectionTitle('Recent Activity'),
                          const SizedBox(height: 8),
                          _card(
                            child: FutureBuilder<List<_ActivityItem>>(
                              future: _loadRecentActivity(),
                              builder: (context, snap) {
                                if (snap.connectionState ==
                                    ConnectionState.waiting) {
                                  return const SizedBox(
                                    height: 40,
                                    child: Center(
                                        child:
                                            CircularProgressIndicator(
                                                strokeWidth: 2)),
                                  );
                                }

                                final items = snap.data ?? [];

                                if (items.isEmpty) {
                                  return const Text(
                                    'No recent activity.',
                                    style: TextStyle(
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  );
                                }

                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: items
                                      .map((e) => Padding(
                                            padding:
                                                const EdgeInsets.only(
                                                    bottom: 6),
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 8,
                                                  height: 8,
                                                  decoration:
                                                      BoxDecoration(
                                                    color: e.color,
                                                    shape:
                                                        BoxShape.circle,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  '${_formatShortDate(e.date)}  ${e.time}',
                                                  style: const TextStyle(
                                                    color: Color(
                                                        0xFF334155),
                                                    fontSize: 13,
                                                    fontWeight:
                                                        FontWeight.w600,
                                                  ),
                                                ),
                                                const Spacer(),
                                                Text(
                                                  e.label,
                                                  style: TextStyle(
                                                    color: e.color,
                                                    fontWeight:
                                                        FontWeight.w700,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ))
                                      .toList(),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // widget helpers

  static String _formatShortDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${months[d.month - 1]}';
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: child,
    );
  }

  Widget _row(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF0F172A)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }
}

// Repeat Days Row — read-only

class _RepeatDaysRow extends StatelessWidget {
  final List<String> repeatDays;

  static const List<String> _labels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
  static const List<String> _keys = [
    'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'
  ];

  const _RepeatDaysRow({required this.repeatDays});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        final selected = repeatDays.contains(_keys[i]);
        return Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected
                ? const Color(0xFF0B1738)
                : const Color(0xFFF1F5F9),
          ),
          child: Center(
            child: Text(
              _labels[i],
              style: TextStyle(
                color: selected ? Colors.white : const Color(0xFF94A3B8),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        );
      }),
    );
  }
}

// Section title

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white70,
        fontWeight: FontWeight.w800,
        fontSize: 16,
      ),
    );
  }
}

// Activity item model

class _ActivityItem {
  final DateTime date;
  final String time;
  final String label;
  final Color color;

  _ActivityItem({
    required this.date,
    required this.time,
    required this.label,
    required this.color,
  });
}