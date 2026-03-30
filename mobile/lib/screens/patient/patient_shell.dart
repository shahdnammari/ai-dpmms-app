import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/app_refresh.dart';
import '../patient/patient_home_tab.dart';
import '../patient/medications_list_screen.dart';
import '../patient/notifications_screen.dart';
import '../patient/reports_screen.dart';

class PatientShell extends StatefulWidget {
  const PatientShell({super.key});

  @override
  State<PatientShell> createState() => _PatientShellState();
}

class _PatientShellState extends State<PatientShell> {
  int _index = 0;

  final List<String> _titles = const [
    'Home',
    'Medications',
    'Notifications',
    'Reports',
  ];

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

  Future<Map<String, dynamic>?> _getUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    return doc.data();
  }

  @override
  Widget build(BuildContext context) {
    // Form header
    const headerColor = Color(0xFF1E3A8A);
    const bg = Color(0xFFF3F6FB);

    return Scaffold(
      backgroundColor: bg,

      body: SafeArea(
        child: Column(
          children: [
            // Shell Header
            FutureBuilder<Map<String, dynamic>?>(
              future: _getUserData(),
              builder: (context, snapshot) {
                final data = snapshot.data;
                final username =
                    (data?['username'] as String?)?.trim().isNotEmpty == true
                        ? data!['username'] as String
                        : (FirebaseAuth.instance.currentUser?.displayName
                                    ?.trim()
                                    .isNotEmpty ==
                                true
                            ? FirebaseAuth
                                .instance.currentUser!.displayName!
                            : 'Patient');

                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                  decoration: const BoxDecoration(color: headerColor),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome, $username',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _titles[_index],
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
                              builder: (_) =>
                                  const _ProfilePlaceholderScreen(),
                            ),
                          );
                        },
                        child: Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: .12),
                            border: Border.all(
                                color: Colors.white24, width: 1),
                          ),
                          child: const Icon(Icons.person_outline,
                              color: Colors.white, size: 28),
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

      // Bottom nav
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(
                  blurRadius: 18,
                  offset: Offset(0, 6),
                  color: Color(0x14000000),
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

// Nav item

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
    const activeColor   = Color(0xFF1E3A8A);
    const inactiveColor = Color(0xFF64748B);

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
              ? const Color(0xFFE8EEF9)
              : Colors.transparent,
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

// Placeholders

class _ProfilePlaceholderScreen extends StatelessWidget {
  const _ProfilePlaceholderScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: const Center(
        child: Text('Profile Page Skeleton',
            style:
                TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      ),
    );
  }
}