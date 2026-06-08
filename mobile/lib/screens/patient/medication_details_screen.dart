import 'dart:ui';
import 'package:flutter/material.dart';
import '../../l10n/app_strings.dart';
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

class _MedicationDetailsScreenState extends State<MedicationDetailsScreen> {
  final _intakeService = IntakeService();

  static const Color _dark  = Color(0xFF0B1738);
  static const Color _red   = Color(0xFFDC2626);
  static const Color _green = Color(0xFF16A34A);

  Future<void> _confirmDelete() async {
    final s       = S.of(context);
    final service = MedicationsService();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(s.deleteMedTitle,
            style: const TextStyle(fontWeight: FontWeight.w800)),
        content: Text(s.deleteConfirm(widget.medication.name)),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: _dark),
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.delete),
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

  String get _timeText {
    if (widget.medication.times.isEmpty) return '--:--';
    return widget.medication.times.join(' · ');
  }

  String _scheduleText(S s) {
    final n = widget.medication.times.isNotEmpty
        ? widget.medication.times.length
        : widget.medication.frequencyPerDay;
    return n <= 1 ? s.timesPerDay1 : s.timesPerDayN(n);
  }

  String _repeatText(S s) {
    final days = widget.medication.repeatDays;
    if (days.length == 7) return s.everyDay;
    if (days.isEmpty)     return s.noRepeatDays;

    const order  = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final sorted = days.where(order.contains).toList()
      ..sort((a, b) => order.indexOf(a).compareTo(order.indexOf(b)));
    return sorted.join(', ');
  }

  Future<List<_ActivityItem>> _loadRecentActivity() async {
    final List<_ActivityItem> items = [];
    final s = S.of(context);

    final times = widget.medication.times.isNotEmpty
        ? widget.medication.times
        : ['08:00'];

    for (int i = 1; i <= 4; i++) {
      final day = DateTime.now().subtract(Duration(days: i));
      for (final time in times) {
        final doseKey = '${widget.medication.id}_$time';
        final status  = await _intakeService.getDoseStatus(
          uid: widget.uid,
          date: day,
          doseKey: doseKey,
        );

        if (status == 'taken') {
          items.add(_ActivityItem(
              date: day, time: time, label: s.statusTaken, color: _green));
        } else if (status == 'skipped') {
          items.add(_ActivityItem(
              date: day, time: time, label: s.statusSkipped, color: _red));
        }
      }
    }

    items.sort((a, b) => b.date.compareTo(a.date));
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final s   = S.of(context);
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
                  color: Colors.black.withValues(alpha: 0.25)),
            ),
          ),

          // Card
          SafeArea(
            child: Center(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
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
                              IconButton(
                                icon: const Icon(Icons.close,
                                    color: Colors.white, size: 20),
                                onPressed: () => Navigator.pop(context),
                              ),
                              const Icon(Icons.info_outline,
                                  color: Colors.white),
                              const SizedBox(width: 8),
                              Text(s.details,
                                  style: const TextStyle(
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

                          // Main info
                          _card(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _row(Icons.medication_outlined, med.name),
                              const SizedBox(height: 10),
                              _row(Icons.science_outlined, med.dosage),
                            ],
                          )),

                          const SizedBox(height: 18),

                          _SectionTitle(s.scheduleLabel),
                          const SizedBox(height: 8),
                          _card(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_timeText,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  )),
                              const SizedBox(height: 6),
                              Text(_scheduleText(s),
                                  style: const TextStyle(
                                    color: Color(0xFF334155),
                                    fontWeight: FontWeight.w600,
                                  )),
                            ],
                          )),

                          const SizedBox(height: 18),

                          _SectionTitle(s.repeatLabel),
                          const SizedBox(height: 8),
                          _card(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_repeatText(s),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF334155),
                                  )),
                              const SizedBox(height: 10),
                              _RepeatDaysRow(repeatDays: med.repeatDays),
                            ],
                          )),

                          const SizedBox(height: 18),

                          _card(child: Row(
                            children: [
                              const Icon(Icons.notifications_outlined),
                              const SizedBox(width: 10),
                              Text(s.reminderLabel,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                              const Spacer(),
                              Switch(
                                value: med.reminderEnabled,
                                onChanged: null,
                                thumbColor:
                                    WidgetStateProperty.all(Colors.white),
                                trackColor:
                                    WidgetStateProperty.resolveWith((states) {
                                  if (states.contains(WidgetState.selected)) {
                                    return _green;
                                  }
                                  return Colors.grey;
                                }),
                              ),
                            ],
                          )),

                          const SizedBox(height: 18),

                          _SectionTitle(s.noteLabel),
                          const SizedBox(height: 8),
                          _card(child: Text(
                            (med.notes?.trim().isNotEmpty ?? false)
                                ? med.notes!.trim()
                                : '-',
                            style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontWeight: FontWeight.w600,
                            ),
                          )),

                          const SizedBox(height: 18),

                          _SectionTitle(s.recentActivity),
                          const SizedBox(height: 8),
                          _card(
                            child: FutureBuilder<List<_ActivityItem>>(
                              future: _loadRecentActivity(),
                              builder: (context, snap) {
                                if (snap.connectionState ==
                                    ConnectionState.waiting) {
                                  return const _SkeletonActivityRows();
                                }

                                final items = snap.data ?? [];

                                if (items.isEmpty) {
                                  return Text(
                                    s.noRecentActivity,
                                    style: const TextStyle(
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  );
                                }

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: items
                                      .map((e) => Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 6),
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 8,
                                                  height: 8,
                                                  decoration: BoxDecoration(
                                                    color: e.color,
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  '${_formatShortDate(e.date)}  ${e.time}',
                                                  style: const TextStyle(
                                                    color: Color(0xFF334155),
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                const Spacer(),
                                                Text(
                                                  e.label,
                                                  style: TextStyle(
                                                    color: e.color,
                                                    fontWeight: FontWeight.w700,
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
          child: Text(text,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
        ),
      ],
    );
  }
}

// Repeat days row

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

// Skeleton loading

class _SkeletonActivityRows extends StatefulWidget {
  const _SkeletonActivityRows();

  @override
  State<_SkeletonActivityRows> createState() => _SkeletonActivityRowsState();
}

class _SkeletonActivityRowsState extends State<_SkeletonActivityRows>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _opacity = Tween(begin: 0.4, end: 0.85).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _box({double? width, required double height, double radius = 7}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A4A) : const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _opacity,
      builder: (_, _) => Opacity(
        opacity: _opacity.value,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(
            3,
            (_) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF2A2A4A)
                          : const Color(0xFFE2E8F0),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _box(height: 11, width: 120, radius: 6),
                        const SizedBox(height: 5),
                        _box(height: 9, width: 80, radius: 5),
                      ],
                    ),
                  ),
                  _box(width: 36, height: 9, radius: 5),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
