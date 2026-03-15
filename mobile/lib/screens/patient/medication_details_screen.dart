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

class _MedicationDetailsScreenState extends State<MedicationDetailsScreen> {
  final _intakeService = IntakeService();

  Future<void> _confirmDelete() async {
    final service = MedicationsService();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Delete medication?'),
          content: Text(
            'Are you sure you want to delete "${widget.medication.name}"?',
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
        ),
      ),
    );
  }

  String get _timeText {
    if (widget.medication.times.isEmpty) return '--:--';
    return widget.medication.times.join(' • ');
  }

  String get _scheduleText {
    if (widget.medication.frequencyPerDay <= 1) {
      return '1 time per day';
    }
    return '${widget.medication.frequencyPerDay} times per day';
  }

  Future<List<_ActivityItem>> _loadRecentActivity() async {
    final List<_ActivityItem> items = [];
    final time = widget.medication.times.isNotEmpty
        ? widget.medication.times.first
        : '08:00';
    final doseKey = '${widget.medication.id}_$time';

    for (int i = 1; i <= 4; i++) {
      final day = DateTime.now().subtract(Duration(days: i));

      final status = await _intakeService.getDoseStatus(
        uid: widget.uid,
        date: day,
        doseKey: doseKey,
      );

      if (status == 'taken') {
        items.add(
          _ActivityItem(
            date: day,
            label: 'Taken',
            color: const Color(0xFF16A34A),
          ),
        );
      } else if (status == 'skipped') {
        items.add(
          _ActivityItem(
            date: day,
            label: 'Skipped',
            color: const Color(0xFFDC2626),
          ),
        );
      }
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final med = widget.medication;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          /// tap outside = close
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                color: Colors.black.withValues(alpha: 0.25),
              ),
            ),
          ),

          Positioned(
            top: 80,
            left: 20,
            child: IconButton(
              icon: const Icon(
                Icons.close,
                color: Color(0xFF0B1738),
                size: 26,
              ),
              onPressed: () => 
                Navigator.pop(context),
              
            ),
          ),

          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
                child: GestureDetector(
                  onTap: () {},
                  child: Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 420),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B1738),
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

                          /// Header
                          Row(
                            children: [
                              const Icon(
                                Icons.info_outline,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Details',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                onPressed: _confirmDelete,
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Color(0xFFDC2626),
                                ),
                              ),
                              IconButton(
                                onPressed: _goEdit,
                                icon: const Icon(
                                  Icons.edit_outlined,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 14),

                          /// Main details card
                          _card(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _row(Icons.medication_outlined, med.name),
                                const SizedBox(height: 10),
                                _row(Icons.science_outlined, med.dosage),
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: med.isActive
                                        ? const Color(0xFFDCFCE7)
                                        : const Color(0xFFF3F4F6),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    med.isActive ? 'Active' : 'Inactive',
                                    style: TextStyle(
                                      color: med.isActive
                                          ? const Color(0xFF16A34A)
                                          : const Color(0xFF9AA0AA),
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 18),

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

                          _card(
                            child: Row(
                              children: [
                                Icon(Icons.notifications_outlined),
                                SizedBox(width: 10),
                                Text(
                                  'Reminder',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Spacer(),
                                Switch(
                                  value: true,
                                  onChanged: null,
                                  thumbColor: WidgetStateProperty.resolveWith((states) {
                                    return Colors.white;
                                  }),
                                  trackColor: WidgetStateProperty.resolveWith((states){
                                    if (states.contains(WidgetState.selected)){
                                      return const Color(0XFF16A34A);
                                    }
                                    return Colors.grey;
                                  }),
                                )

                              ],
                            ),
                          ),

                          const SizedBox(height: 18),

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

                          const _SectionTitle('Recently Activity'),
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
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: items
                                      .map(
                                        (e) => Padding(
                                          padding: const EdgeInsets.only(bottom: 4),
                                          child: Text(
                                            '${_formatShortDate(e.date)} - ${e.label}',
                                            style: TextStyle(
                                              color: e.color,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      )
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
        Icon(
          icon,
          size: 20,
          color: const Color(0xFF0F172A),
        ),
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

class _ActivityItem {
  final DateTime date;
  final String label;
  final Color color;

  _ActivityItem({
    required this.date,
    required this.label,
    required this.color,
  });
}