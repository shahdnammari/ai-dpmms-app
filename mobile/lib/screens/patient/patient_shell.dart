import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../role_select_screen.dart';
import 'patient_home_tab.dart';
import 'medications_list_screen.dart';
import 'medication_form_screen.dart';
import '/widgets/app_motion.dart';

  
class PatientShell extends StatefulWidget {
  const PatientShell({super.key});

  @override
  State<PatientShell> createState() => _PatientShellState();
}

class _PatientShellState extends State<PatientShell> {
  int _index = 0;

  // === Brand Colors (Tech + Professional) ===
  static const Color kPrimary = Color(0xFF4F5DFF); // indigo blue
  static const Color kAccent = Color(0xFF8B5CF6); // purple
  static const Color kBgTop = Color(0xFFF4F5FF); // subtle lavender
  static const Color kBgBottom = Color(0xFFF6F7FB);

  String _sectionTitle(int index) {
    switch (index) {
      case 0:
        return 'Home';
      case 1:
        return 'Medications';
      case 2:
        return 'Notifications';
      case 3:
        return 'Reports / History';
      case 4:
        return 'AI';
      default:
        return '';
    }
  }

  bool get _showFab => _index == 1;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const RoleSelectScreen();

    final pages = <Widget>[
      const PatientHomeTab(),
      const MedicationsListScreen(),
      const _PlaceholderPage(title: 'Notifications (soon)'),
      const _PlaceholderPage(title: 'Reports / History (soon)'),
      const _PlaceholderPage(title: 'AI (soon)'),
    ];

    return Container(
      // ✅ Unified background for ALL tabs
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [kBgTop, kBgBottom],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent, // show the gradient

        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(72),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [kPrimary, kAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(26),
              ),
              boxShadow: [
                BoxShadow(
                  blurRadius: 16,
                  offset: Offset(0, 6),
                  color: Color(0x22000000),
                ),
              ],
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .doc(user.uid)
                            .snapshots(),
                        builder: (context, snap) {
                          final data = snap.data?.data();
                          final username =
                              (data?['username'] as String?) ??
                              (data?['displayName'] as String?) ??
                              (user.email?.split('@').first ?? 'Patient');

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Welcome $username',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),

                              // ✅ Section title animation (Fade)
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                transitionBuilder: (child, anim) =>
                                    FadeTransition(opacity: anim, child: child),
                                child: Text(
                                  _sectionTitle(_index),
                                  key: ValueKey(_index),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xCCFFFFFF),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),

                    // logout (no navigator here, AuthGate will route)
                    IconButton(
                      icon: const Icon(Icons.logout, color: Colors.white),
                      onPressed: () async {
                        await FirebaseAuth.instance.signOut();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // ✅ Animated tab transitions
        body: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              final slide = Tween<Offset>(
                begin: const Offset(0.03, 0),
                end: Offset.zero,
              ).animate(animation);

              return FadeTransition(
                opacity: animation,
                child: SlideTransition(position: slide, child: child),
              );
            },
            child: PageMotion(
              key: ValueKey(_index),
              child: pages[_index],
            ),
          ),
        ),

        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

        // ✅ FAB animation + hide on other tabs
        floatingActionButton: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: _showFab ? 1 : 0,
          child: AnimatedScale(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            scale: _showFab ? 1 : 0.85,
            child: IgnorePointer(
              ignoring: !_showFab,
              child: SizedBox(
                height: 64,
                width: 64,
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [kPrimary, kAccent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 14,
                        offset: Offset(0, 8),
                        color: Color(0x33000000),
                      ),
                    ],
                  ),
                  child: FloatingActionButton(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MedicationFormScreen(
                            uid: user.uid,
                            effectiveDate: DateTime.now(),
                          ),
                        ),
                      );
                    },
                    child: const Icon(Icons.add, size: 30, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ),

        bottomNavigationBar: NavigationBarTheme(
          data: NavigationBarThemeData(
            height: 68,
            backgroundColor: Colors.white,
            elevation: 3,
            indicatorColor: const Color(0x224F5DFF),
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              final selected = states.contains(WidgetState.selected);
              return TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? kPrimary : Colors.grey.shade600,
              );
            }),
            iconTheme: WidgetStateProperty.resolveWith((states) {
              final selected = states.contains(WidgetState.selected);
              return IconThemeData(
                size: 24,
                color: selected ? kPrimary : Colors.grey.shade600,
              );
            }),
          ),
          child: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
              NavigationDestination(icon: Icon(Icons.medication), label: 'Medication'),
              NavigationDestination(icon: Icon(Icons.notifications), label: 'Notifications'),
              NavigationDestination(icon: Icon(Icons.insert_chart), label: 'Reports'),
              NavigationDestination(icon: Icon(Icons.smart_toy), label: 'AI'),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceholderPage extends StatelessWidget {
  final String title;
  const _PlaceholderPage({required this.title});

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(title));
  }
}