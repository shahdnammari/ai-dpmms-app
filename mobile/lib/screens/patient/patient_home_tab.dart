import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:ai_dpmms_mobile/services/app_refresh.dart';

import '../../l10n/app_strings.dart';
import '../../services/settings_service.dart';
import '../../models/medication.dart';
import '../../services/intake_service.dart';
import '../../services/medications_service.dart';
import '../role_select_screen.dart';
import 'medication_details_screen.dart';
import 'medication_form_screen.dart';
import 'ai_screen.dart';
import 'settings_screen.dart';
import '../../services/alert_service.dart';

class PatientHomeTab extends StatefulWidget {
  const PatientHomeTab({super.key});

  @override
  State<PatientHomeTab> createState() => _PatientHomeTabState();
}

class _PatientHomeTabState extends State<PatientHomeTab> {
  final _medicationsService = MedicationsService();
  final _intakeService = IntakeService();
  VoidCallback? _refreshListener;

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
    if (_refreshListener != null) {
      AppRefresh.notifier.removeListener(_refreshListener!);
    }
    super.dispose();
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  String _formatToday() => DateFormat('d MMMM, EEEE').format(DateTime.now());

  bool _isMedActiveForDate(Medication med, DateTime day) {
    final start = _dateOnly(med.startDate);
    final target = _dateOnly(day);
    if (target.isBefore(start)) return false;
    if (med.endDate != null && target.isAfter(_dateOnly(med.endDate!))) {
      return false;
    }
    return true;
  }

  List<Medication> _pickActiveVersionsPerGroup(
      List<Medication> meds, DateTime day) {
    final activeToday =
        meds.where((m) => _isMedActiveForDate(m, day)).toList();
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

  List<({Medication med, String time, String doseKey})> _expandDoses(
      List<Medication> meds) {
    final result = <({Medication med, String time, String doseKey})>[];
    for (final med in meds) {
      final times = med.times.isNotEmpty ? med.times : ['08:00'];
      for (final t in times) {
        result.add((med: med, time: t, doseKey: '${med.id}_$t'));
      }
    }
    result.sort((a, b) => a.time.compareTo(b.time));
    return result;
  }

  Future<void> _onRefresh() async {
    AppRefresh.trigger();
    await Future.delayed(const Duration(milliseconds: 400));
  }

  Future<void> _showMoreMenu(S s) async {
    final isRtl = SettingsService.instance.isRtl;
    final selected = await showMenu<String>(
      context: context,
      position: isRtl
          ? const RelativeRect.fromLTRB(16, 145, 1000, 0)
          : const RelativeRect.fromLTRB(1000, 145, 16, 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      items: [
        PopupMenuItem(
          value: 'settings',
          child: ListTile(
            dense: true,
            leading: Icon(Icons.settings_outlined,
                color: Theme.of(context).colorScheme.onSurface),
            title: Text(s.menuSetting,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
          ),
        ),
        PopupMenuItem(
          value: 'help',
          child: ListTile(
            dense: true,
            leading: Icon(Icons.help_outline, 
            color: Theme.of(context).colorScheme.onSurface),
            title: Text(s.menuHelp,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'logout',
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.logout, color: Color(0xFFDC2626)),
            title: Text(s.menuLogout,
                style: const TextStyle(color: Color(0xFFDC2626))),
          ),
        ),
      ],
    );

    if (!mounted || selected == null) return;

    if (selected == 'settings') {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const SettingsScreen()));
    } else if (selected == 'help') {
      _showHelpSupportSheet(s);
    } else if (selected == 'logout') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(s.logoutConfirmTitle,
              style: const TextStyle(fontWeight: FontWeight.w800)),
          content: Text(s.logoutConfirmMsg),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(s.cancel,
                  style: const TextStyle(color: Color(0xFF3B82F6))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: Text(s.logoutButton),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const RoleSelectScreen()),
        (_) => false,
      );
    }
  }

  void _showHelpSupportSheet(S s) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor:
          isDark ? const Color(0xFF1E1E2E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 42, child: Divider(thickness: 4)),
              const SizedBox(height: 14),
              Text(s.helpTitle,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isDark
                          ? Colors.white
                          : const Color(0xFF0F172A))),
              const SizedBox(height: 8),
              Text(
                s.helpBody,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Color(0xFF64748B), height: 1.4),
              ),
              const SizedBox(height: 18),
              const ListTile(
                  leading: Icon(Icons.email_outlined),
                  title: Text('support@ai-dpmms.com')),
              const ListTile(
                  leading: Icon(Icons.phone_outlined),
                  title: Text('+970 000 000 000')),
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

    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final cardBg = Theme.of(context).colorScheme.surface;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final today = DateTime.now();

    return Container(
      color: bg,
      child: StreamBuilder<List<Medication>>(
        stream: _medicationsService.watchMedications(user.uid),
        builder: (context, medsSnap) {
          if (medsSnap.connectionState == ConnectionState.waiting) {
            return const _SkeletonHomeContent();
          }

          final meds = medsSnap.data ?? [];
          final todayMeds = _pickActiveVersionsPerGroup(meds, today);
          final doses = _expandDoses(todayMeds);

          return StreamBuilder<Map<String, dynamic>>(
            stream: _intakeService.watchDailyIntake(
                uid: user.uid, date: today),
            builder: (context, intakeSnap) {
              final intakeMap = intakeSnap.data ?? {};

              int takenCount = 0;
              for (final dose in doses) {
                final d =
                    intakeMap[dose.doseKey] as Map<String, dynamic>?;
                if ((d?['status'] as String?) == 'taken') takenCount++;
              }

              final totalCount = doses.length;
              final progress =
                  totalCount == 0 ? 0.0 : takenCount / totalCount;

              return RefreshIndicator(
                onRefresh: _onRefresh,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header row
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _formatToday(),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: onSurface,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => MedicationFormScreen(
                                    uid: user.uid,
                                    effectiveDate: _dateOnly(today),
                                    source: MedicationFormSource.home,
                                  ),
                                ),
                              );
                            },
                            icon: Icon(Icons.add_circle_outline,
                                color: Theme.of(context).colorScheme.onSurface, size: 26),
                            tooltip: s.addMedication,
                          ),
                          InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const AiScreen()),
                              );
                            },
                            child: Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(Icons.auto_awesome_outlined,
                                  color: Theme.of(context).colorScheme.onSurface, size: 22),
                            ),
                          ),
                          const SizedBox(width: 4),
                          InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _showMoreMenu(s),
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Icon(Icons.more_vert,
                                  color: Theme.of(context).colorScheme.onSurface, size: 22),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // Daily progress
                      Text(s.dailyProgress,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? Colors.white70
                                  : const Color(0xFF334155))),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding:
                            const EdgeInsets.fromLTRB(12, 12, 12, 10),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                              color: Colors.black
                                  .withValues(alpha: isDark ? 0.25 : 0.07),
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
                                backgroundColor: isDark
                                    ? const Color(0xFF3A3A5C)
                                    : const Color(0xFF94A3B8),
                                valueColor:
                                    const AlwaysStoppedAnimation(
                                        Color(0xFF0F2A64)),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              s.takenOf(takenCount, totalCount),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Checklist title
                      Text(s.todayChecklist,
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF334155))),
                      const SizedBox(height: 12),

                      // Empty state
                      if (doses.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Text(
                            s.noMedsToday,
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white60
                                  : const Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),

                      ...doses.map((dose) {
                        final med = dose.med;
                        final time = dose.time;
                        final doseKey = dose.doseKey;

                        final d = intakeMap[doseKey]
                            as Map<String, dynamic>?;
                        final status =
                            (d?['status'] as String?) ?? 'pending';

                        Color mainColor;
                        String label;
                        Color skipBgColor, skipIconColor, skipTextColor;
                        Color takeBgColor, takeIconColor, takeTextColor;

                        if (status == 'taken') {
                          mainColor = const Color(0xFF16A34A);
                          label = s.statusTaken;
                          skipBgColor = isDark
                              ? const Color(0xFF2A2A3C)
                              : const Color(0xFFF3F4F6);
                          skipIconColor = const Color(0xFF9AA0AA);
                          skipTextColor = const Color(0xFF9AA0AA);
                          takeBgColor = isDark
                              ? const Color(0xFF14532D).withValues(alpha: 0.5)
                              : const Color(0xFFDCFCE7);
                          takeIconColor = const Color(0xFF16A34A);
                          takeTextColor = const Color(0xFF16A34A);
                        } else if (status == 'skipped') {
                          mainColor = const Color(0xFFDC2626);
                          label = s.statusSkipped;
                          skipBgColor = isDark
                              ? const Color(0xFF7F1D1D).withValues(alpha: 0.45)
                              : const Color(0xFFFEE2E2);
                          skipIconColor = const Color(0xFFDC2626);
                          skipTextColor = const Color(0xFFDC2626);
                          takeBgColor = isDark
                              ? const Color(0xFF2A2A3C)
                              : const Color(0xFFF3F4F6);
                          takeIconColor = const Color(0xFF9AA0AA);
                          takeTextColor = const Color(0xFF9AA0AA);
                        } else {
                          mainColor = const Color(0xFF1E3A8A);
                          label = s.statusScheduled;
                          skipBgColor = isDark
                              ? const Color(0xFF1E3A8A).withValues(alpha: 0.25)
                              : const Color(0xFFDBEAFE);
                          skipIconColor = const Color(0xFF1E3A8A);
                          skipTextColor = const Color(0xFF1E3A8A);
                          takeBgColor = isDark
                              ? const Color(0xFF1E3A8A).withValues(alpha: 0.25)
                              : const Color(0xFFDBEAFE);
                          takeIconColor = const Color(0xFF1E3A8A);
                          takeTextColor = const Color(0xFF1E3A8A);
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () {
                              Navigator.of(context).push(
                                PageRouteBuilder(
                                  opaque: false,
                                  barrierDismissible: true,
                                  pageBuilder: (_, _, _) =>
                                      MedicationDetailsScreen(
                                    medication: med,
                                    uid: user.uid,
                                    effectiveDate: today,
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.fromLTRB(
                                  14, 12, 14, 10),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                    color: Colors.black.withValues(
                                        alpha: isDark ? 0.25 : 0.07),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(top: 2),
                                        child: Icon(
                                          Icons.medication_outlined,
                                          color: mainColor,
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(width: 15),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              med.name,
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w800,
                                                color: mainColor,
                                              ),
                                            ),
                                            Text(
                                              med.dosage,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: Color(0xFF64748B),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
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
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _ActionCircleButton(
                                          icon: Icons.close,
                                          label: s.skip,
                                          bgColor: skipBgColor,
                                          iconColor: skipIconColor,
                                          textColor: skipTextColor,
                                          onTap: () async {
                                            if (status == 'skipped') {
                                              await _intakeService
                                                  .clearDoseStatus(
                                                uid: user.uid,
                                                date: today,
                                                doseKey: doseKey,
                                              );
                                            } else {
                                              await _intakeService
                                                  .setDoseStatus(
                                                uid: user.uid,
                                                date: today,
                                                doseKey: doseKey,
                                                status: 'skipped',
                                              );
                                              AlertService.analyzeAndAlert();
                                            }
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: _ActionCircleButton(
                                          icon: Icons.check,
                                          label: s.take,
                                          bgColor: takeBgColor,
                                          iconColor: takeIconColor,
                                          textColor: takeTextColor,
                                          onTap: () async {
                                            if (status == 'taken') {
                                              await _intakeService
                                                  .clearDoseStatus(
                                                uid: user.uid,
                                                date: today,
                                                doseKey: doseKey,
                                              );
                                            } else {
                                              await _intakeService
                                                  .setDoseStatus(
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
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ── Action button ──────────────────────────────────────────────────────────

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
            decoration:
                BoxDecoration(color: bgColor, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 24),
          ),
        ),
        const SizedBox(height: 6),
        Text(label,
            style:
                TextStyle(fontWeight: FontWeight.w800, color: textColor)),
      ],
    );
  }
}

// Skeleton loading

class _SkeletonHomeContent extends StatefulWidget {
  const _SkeletonHomeContent();

  @override
  State<_SkeletonHomeContent> createState() => _SkeletonHomeContentState();
}

class _SkeletonHomeContentState extends State<_SkeletonHomeContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _opacity = Tween(begin: 0.35, end: 0.75).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _box({double? width, required double height, double radius = 10}) {
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
    final cardBg = isDark ? const Color(0xFF1E1E2E) : Colors.white;

    return AnimatedBuilder(
      animation: _opacity,
      builder: (_, _) => Opacity(
        opacity: _opacity.value,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Expanded(child: _box(height: 16, width: 160, radius: 8)),
                  const SizedBox(width: 8),
                  _box(width: 28, height: 28, radius: 8),
                  const SizedBox(width: 8),
                  _box(width: 28, height: 28, radius: 8),
                  const SizedBox(width: 8),
                  _box(width: 28, height: 28, radius: 8),
                ],
              ),
              const SizedBox(height: 18),
              // Daily progress label
              _box(width: 110, height: 12, radius: 6),
              const SizedBox(height: 10),
              // Progress card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _box(height: 16, radius: 999),
                    const SizedBox(height: 10),
                    _box(width: 80, height: 11, radius: 6),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              // Checklist title
              _box(width: 140, height: 18, radius: 8),
              const SizedBox(height: 14),
              // Dose cards
              ...List.generate(3, (_) => _SkeletonDoseCard(isDark: isDark)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkeletonDoseCard extends StatelessWidget {
  final bool isDark;
  const _SkeletonDoseCard({required this.isDark});

  Widget _box({double? width, required double height, double radius = 8}) =>
      Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2A4A) : const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(radius),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2A2A4A) : const Color(0xFFE2E8F0),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _box(height: 13, width: 130, radius: 7),
                const SizedBox(height: 7),
                _box(height: 10, width: 80, radius: 6),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _box(height: 32, radius: 10)),
                    const SizedBox(width: 8),
                    Expanded(child: _box(height: 32, radius: 10)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
