import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../l10n/app_strings.dart';
import '../../services/app_refresh.dart';
import '../profile.dart';
import 'doctor_home_tab.dart';
import 'doctor_patients_tab.dart';
import 'doctor_notifications_tab.dart';
import 'doctor_reports_tab.dart';

class DoctorShell extends StatefulWidget {
  const DoctorShell({super.key});

  static final tabNotifier = ValueNotifier<int>(-1);

  @override
  State<DoctorShell> createState() => _DoctorShellState();
}

class _DoctorShellState extends State<DoctorShell> {
  int _index = 0;

  String _greeting(S s) {
    final hour = DateTime.now().hour;
    if (hour < 12) return s.goodMorning;
    if (hour < 18) return s.goodAfternoon;
    return s.goodEvening;
  }

  @override
  void initState() {
    super.initState();
    DoctorShell.tabNotifier.addListener(_onTabSignal);
    _deleteOldAlerts();
  }

  Future<void> _deleteOldAlerts() async {
    try {
      final cutoff = Timestamp.fromDate(
        DateTime.now().subtract(const Duration(hours: 24)),
      );
      final snap = await FirebaseFirestore.instance
          .collection('alerts')
          .where('createdAt', isLessThan: cutoff)
          .get();
      for (final doc in snap.docs) {
        doc.reference.delete();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    DoctorShell.tabNotifier.removeListener(_onTabSignal);
    super.dispose();
  }

  void _onTabSignal() {
    final i = DoctorShell.tabNotifier.value;
    if (i >= 0 && mounted) {
      setState(() => _index = i);
      DoctorShell.tabNotifier.value = -1;
    }
  }

  void _onTap(int i) {
    if (_index == i) {
      AppRefresh.trigger();
      return;
    }
    setState(() => _index = i);
    if (i == 2) _markAlertsAsRead();
  }

  Future<void> _markAlertsAsRead() async {
    final snap = await FirebaseFirestore.instance
        .collection('alerts')
        .where('isRead', isEqualTo: false)
        .get();
    if (snap.docs.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> _userStream() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return FirebaseFirestore.instance.collection('users').doc(uid).snapshots();
  }

  Stream<int> _unreadStream() {
    return FirebaseFirestore.instance
        .collection('alerts')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  Widget _buildCurrentPage() {
    switch (_index) {
      case 0: return const DoctorHomeTab();
      case 1: return const DoctorPatientsTab();
      case 2: return const DoctorNotificationsTab();
      case 3: return const DoctorReportsTab();
      default: return const DoctorHomeTab();
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final isRtl = locale.languageCode == 'ar' || locale.languageCode == 'he';
    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final titles = [s.home, s.patients, s.notifications, s.reports];

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,

        body: SafeArea(
          child: Column(
            children: [
              // Shell Header
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: _userStream(),
                builder: (context, snapshot) {
                  final data = snapshot.data?.data();

                  final username =
                      (data?['name'] as String?)?.trim().isNotEmpty == true
                          ? data!['name'] as String
                          : ((data?['username'] as String?)
                                          ?.trim()
                                          .isNotEmpty ==
                                      true
                                  ? data!['username'] as String
                                  : (FirebaseAuth.instance.currentUser
                                                  ?.displayName
                                                  ?.trim()
                                                  .isNotEmpty ==
                                              true
                                          ? FirebaseAuth
                                              .instance.currentUser!.displayName!
                                          : 'Doctor'));

                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                    decoration: const BoxDecoration(color: Color(0xFF1E3A8A)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_greeting(s)}, $username',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                titles[_index],
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        InkWell(
                          borderRadius: BorderRadius.circular(28),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const ProfileScreen()),
                          ),
                          child: Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: .12),
                              border:
                                  Border.all(color: Colors.white24, width: 1),
                            ),
                            child: const Icon(
                              Icons.person_outline,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              // Page content
              Expanded(child: _buildCurrentPage()),
            ],
          ),
        ),

        // Bottom nav with badge
        bottomNavigationBar: StreamBuilder<int>(
          stream: _unreadStream(),
          builder: (context, badgeSnap) {
            final badge = badgeSnap.data ?? 0;

            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                        color: Colors.black.withValues(
                            alpha: isDark ? 0.35 : 0.08),
                      ),
                    ],
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _NavItem(
                        icon: Icons.home_outlined,
                        selectedIcon: Icons.home,
                        selected: _index == 0,
                        onTap: () => _onTap(0),
                      ),
                      _NavItem(
                        icon: Icons.people_outline,
                        selectedIcon: Icons.people,
                        selected: _index == 1,
                        onTap: () => _onTap(1),
                      ),
                      _NavItem(
                        icon: Icons.notifications_none,
                        selectedIcon: Icons.notifications,
                        selected: _index == 2,
                        badge: badge,
                        onTap: () => _onTap(2),
                      ),
                      _NavItem(
                        icon: Icons.bar_chart_outlined,
                        selectedIcon: Icons.bar_chart,
                        selected: _index == 3,
                        onTap: () => _onTap(3),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// Nav item

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final VoidCallback onTap;
  final int badge;

  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.onTap,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const activeColor = Color(0xFF1E3A8A);
    final inactiveColor =
        isDark ? Colors.white38 : const Color(0xFF64748B);
    final iconColor = selected ? activeColor : inactiveColor;

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? (isDark
                  ? const Color(0xFF2A2A4A)
                  : const Color(0xFFE8EEF9))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              selected ? selectedIcon : icon,
              color: iconColor,
              size: 26,
            ),
            if (badge > 0)
              Positioned(
                top: -5,
                right: -7,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badge > 9 ? '9+' : '$badge',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      height: 1.3,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
