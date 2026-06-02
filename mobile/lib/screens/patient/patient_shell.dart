import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../l10n/app_strings.dart';
import '../../services/app_refresh.dart';
import '../patient/patient_home_tab.dart';
import '../patient/medications_list_screen.dart';
import '../patient/notifications_screen.dart';
import '../patient/reports_screen.dart';
import '../profile.dart';

class PatientShell extends StatefulWidget {
  const PatientShell({super.key});

  @override
  State<PatientShell> createState() => _PatientShellState();
}

class _PatientShellState extends State<PatientShell> {
  int _index = 0;

  String _greeting(S s) {
    final hour = DateTime.now().hour;
    if (hour < 12) return s.goodMorning;
    if (hour < 18) return s.goodAfternoon;
    return s.goodEvening;
  }

  void _onTap(int i) {
    if (_index == i) {
      AppRefresh.trigger();
      return;
    }
    setState(() => _index = i);
  }

  Widget _buildCurrentPage() {
    switch (_index) {
      case 0:
        return const PatientHomeTab();
      case 1:
        return const MedicationsListScreen();
      case 2:
        return const NotificationsScreen();
      case 3:
        return const ReportsScreen();
      default:
        return const PatientHomeTab();
    }
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> _userStream() {
    final user = FirebaseAuth.instance.currentUser;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final navBg = Theme.of(context).colorScheme.surface;
    final titles = [s.home, s.medications, s.notifications, s.reports];

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // Shell header
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
                            : (FirebaseAuth.instance.currentUser?.displayName
                                            ?.trim()
                                            .isNotEmpty ==
                                        true
                                    ? FirebaseAuth
                                        .instance.currentUser!.displayName!
                                    : 'Patient'));

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
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ProfileScreen(),
                            ),
                          );
                        },
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
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Container(
            decoration: BoxDecoration(
              color: navBg,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.35)
                      : const Color(0x14000000),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
                  icon: Icons.medication_outlined,
                  selectedIcon: Icons.medication,
                  selected: _index == 1,
                  onTap: () => _onTap(1),
                ),
                _NavItem(
                  icon: Icons.notifications_none,
                  selectedIcon: Icons.notifications,
                  selected: _index == 2,
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
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const activeColor = Color(0xFF1E3A8A);
    final inactiveColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.grey.shade400
        : const Color(0xFF64748B);
    final selectedBg = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF1E3A8A).withValues(alpha: 0.28)
        : const Color(0xFFE8EEF9);

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? selectedBg : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Icon(
          selected ? selectedIcon : icon,
          color: selected ? activeColor : inactiveColor,
          size: 26,
        ),
      ),
    );
  }
}
