import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../../models/medication.dart';
import '../../services/intake_service.dart';
import '../../services/medications_service.dart';
import '../role_select_screen.dart';

class PatientHomeTab extends StatefulWidget {
  const PatientHomeTab({super.key});

  @override
  State<PatientHomeTab> createState() => _PatientHomeTabState();
}

class _PatientHomeTabState extends State<PatientHomeTab> {
  final _medicationsService = MedicationsService();
  final _intakeService = IntakeService();

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  String _formatToday() {
    final now = DateTime.now();
    return DateFormat('d MMMM, EEEE').format(now);
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

  Future<void> _showMoreMenu() async {
    final selected = await showMenu<String>(
      context: context,
      position: const RelativeRect.fromLTRB(1000, 145, 16, 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      items: const [
        PopupMenuItem(
          value: 'settings',
          child: ListTile(
            dense: true,
            leading: Icon(Icons.settings_outlined, color: Color(0XFF1E3A8A)),
            title: Text(
              'Setting',
              style: TextStyle(color: Color(0XFF1E3A8A)),
            ),
          ),
        ),
        PopupMenuItem(
          value: 'help',
          child: ListTile(
            dense: true,
            leading: Icon(Icons.help_outline, color: Color(0XFF0B1B3A)),
            title: Text(
              'Help & Support',
              style: TextStyle(color: Color(0XFF0B1B3A)),
            ),
          ),
        ),
        PopupMenuDivider(),
        PopupMenuItem(
          value: 'logout',
          child: ListTile(
            dense: true,
            leading: Icon(Icons.logout, color: Color(0xFFDC2626)),
            title: Text(
              'Logout',
              style: TextStyle(color: Color(0xFFDC2626)),
            ),
          ),
        ),
      ],
    );

    if (!mounted || selected == null) return;

    if (selected == 'settings') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const _SettingsPlaceholderScreen(),
        ),
      );
    } else if (selected == 'help') {
      _showHelpSupportSheet();
    } else if (selected == 'logout') {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const RoleSelectScreen()),
        (_) => false,
      );
    }
  }

  void _showHelpSupportSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              SizedBox(
                width: 42,
                child: Divider(thickness: 4),
              ),
              SizedBox(height: 14),
              Text(
                'Help & Support',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              SizedBox(height: 8),
              Text(
                'For help with medications, reminders, or account issues,\nplease contact support or talk to your doctor.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF64748B),
                  height: 1.4,
                ),
              ),
              SizedBox(height: 18),
              ListTile(
                leading: Icon(Icons.email_outlined),
                title: Text('support@ai-dpmms.com'),
              ),
              ListTile(
                leading: Icon(Icons.phone_outlined),
                title: Text('+970 000 000 000'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('No logged in user.'));
    }

    final today = DateTime.now();
    const bg = Color(0xFFF3F6FB);

    return Container(
      color: bg,
      child: StreamBuilder<List<Medication>>(
        stream: _medicationsService.watchMedications(user.uid),
        builder: (context, medsSnap) {
          if (medsSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final meds = medsSnap.data ?? [];
          final todayMeds = _pickActiveVersionsPerGroup(meds, today);

          return StreamBuilder<Map<String, dynamic>>(
            stream: _intakeService.watchDailyIntake(
              uid: user.uid,
              date: today,
            ),
            builder: (context, intakeSnap) {
              final intakeMap = intakeSnap.data ?? {};

              int takenCount = 0;
              for (final med in todayMeds) {
                final time = med.times.isNotEmpty ? med.times.first : '08:00';
                final doseKey = '${med.id}_$time';
                final dose = intakeMap[doseKey] as Map<String, dynamic>?;
                final status = dose?['status'] as String?;
                if (status == 'taken') {
                  takenCount++;
                }
              }

              final totalCount = todayMeds.length;
              final progress = totalCount == 0 ? 0.0 : takenCount / totalCount;

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _formatToday(),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                        ),
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
                              color: Color(0xFF334155),
                              size: 22,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: _showMoreMenu,
                          child: const Padding(
                            padding: EdgeInsets.all(6),
                            child: Icon(
                              Icons.more_vert,
                              color: Color(0xFF334155),
                              size: 22,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    const Text(
                      'Daily Progress',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: const [
                          BoxShadow(
                            blurRadius: 12,
                            offset: Offset(0, 4),
                            color: Color(0x11000000),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              minHeight: 16,
                              value: progress,
                              backgroundColor: const Color(0xFF94A3B8),
                              valueColor: const AlwaysStoppedAnimation(
                                Color(0xFF0F2A64),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$takenCount of $totalCount Taken',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    const Text(
                      "Today's Checklist",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (todayMeds.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Text(
                          'No medications scheduled for today.',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                    ...todayMeds.map((med) {
                      final time = med.times.isNotEmpty ? med.times.first : '08:00';
                      final doseKey = '${med.id}_$time';
                      final dose = intakeMap[doseKey] as Map<String, dynamic>?;
                      final status = (dose?['status'] as String?) ?? 'pending';

                      Color mainColor;
                      String label;

                      // Skip button
                      Color skipBgColor;
                      Color skipIconColor;
                      Color skipTextColor;

                      // Take button
                      Color takeBgColor;
                      Color takeIconColor;
                      Color takeTextColor;

                      if (status == 'taken') {
                        // Main selected color
                        mainColor = const Color(0xFF16A34A);
                        label = 'Taken';

                        // Skip becomes faded/off
                        skipBgColor = const Color(0xFFF3F4F6);
                        skipIconColor = const Color(0xFF9AA0AA);
                        skipTextColor = const Color(0xFF9AA0AA);

                        // Take active
                        takeBgColor = const Color(0xFFDCFCE7);
                        takeIconColor = const Color(0xFF16A34A);
                        takeTextColor = const Color(0xFF16A34A);

                      } else if (status == 'skipped') {
                        // Main selected color
                        mainColor = const Color(0xFFDC2626);
                        label = 'Skipped';

                        // Skip active
                        skipBgColor = const Color(0xFFFEE2E2);
                        skipIconColor = const Color(0xFFDC2626);
                        skipTextColor = const Color(0xFFDC2626);

                        // Take becomes faded/off
                        takeBgColor = const Color(0xFFF3F4F6);
                        takeIconColor = const Color(0xFF9AA0AA);
                        takeTextColor = const Color(0xFF9AA0AA);

                      } else {
                        // Default before user chooses anything
                        mainColor = const Color(0xFF1E3A8A);
                        label = 'Scheduled';

                        // Skip default
                        skipBgColor = const Color(0xFFDBEAFE);
                        skipIconColor = const Color(0xFF1E3A8A);
                        skipTextColor = const Color(0xFF1E3A8A);

                        // Take default
                        takeBgColor = const Color(0xFFDBEAFE);
                        takeIconColor = const Color(0xFF1E3A8A);
                        takeTextColor = const Color(0xFF1E3A8A);
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    _MedicationDetailsPlaceholderScreen(medication: med),
                              ),
                            );
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: const [
                                BoxShadow(
                                  blurRadius: 12,
                                  offset: Offset(0, 4),
                                  color: Color(0x11000000),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                     Padding(
                                      padding: EdgeInsets.only(top: 2),
                                      child: Icon(
                                        Icons.medication_outlined,
                                        color: mainColor,
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 15),
                                    Expanded(
                                      child: Text(
                                        med.name,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: mainColor,
                                        ),
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          time,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                            color: mainColor,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          label,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: mainColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height:10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _ActionCircleButton(
                                        icon: Icons.close,
                                        label: 'Skip',
                                        bgColor: skipBgColor,
                                        iconColor: skipIconColor,
                                        textColor: skipTextColor,
                                        onTap: () async {
                                          if (status == 'skipped') {
                                            await _intakeService.clearDoseStatus(
                                              uid: user.uid,
                                              date: today,
                                              doseKey: doseKey,
                                            );
                                          } else {
                                            await _intakeService.setDoseStatus(
                                              uid: user.uid,
                                              date: today,
                                              doseKey: doseKey,
                                              status: 'skipped',
                                            );
                                          }
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _ActionCircleButton(
                                        icon: Icons.check,
                                        label: 'Take',
                                        bgColor: takeBgColor,
                                        iconColor: takeIconColor,
                                        textColor: takeTextColor,

                                        onTap: () async {
                                          if (status == 'taken') {
                                            await _intakeService.clearDoseStatus(
                                              uid: user.uid,
                                              date: today,
                                              doseKey: doseKey,
                                            );
                                          } else {
                                            await _intakeService.setDoseStatus(
                                              uid: user.uid,
                                              date: today,
                                              doseKey: doseKey,
                                              status: 'taken',
                                            );
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ActionCircleButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color bgColor;
  final Color iconColor;
  final Color textColor;
  final VoidCallback onTap;

  const _ActionCircleButton({
    required this.icon,
    required this.label,
    required this.bgColor,
    required this.iconColor,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 24,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: textColor,
          ),
        ),
      ],
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

class _SettingsPlaceholderScreen extends StatelessWidget {
  const _SettingsPlaceholderScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: const Center(
        child: Text(
          'Settings Screen Skeleton',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _MedicationDetailsPlaceholderScreen extends StatelessWidget {
  final Medication medication;
  const _MedicationDetailsPlaceholderScreen({required this.medication});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(medication.name)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Name: ${medication.name}'),
                const SizedBox(height: 8),
                Text('Dosage: ${medication.dosage}'),
                const SizedBox(height: 8),
                Text('Frequency: ${medication.frequencyPerDay}'),
                const SizedBox(height: 8),
                Text('Times: ${medication.times.join(', ')}'),
                const SizedBox(height: 8),
                Text('Notes: ${medication.notes ?? '-'}'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}