import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../role_select_screen.dart';
import 'patient_home_tab.dart';
import 'medications_list_screen.dart';
import 'medication_form_screen.dart';

class PatientShell extends StatefulWidget {
  const PatientShell({super.key});

  @override
  State<PatientShell> createState() => _PatientShellState();
}

class _PatientShellState extends State<PatientShell> {
  int _index = 0;

  String _sectionTitle(int index) {
    switch (index) {
      case 0: return 'Home';
      case 1: return 'Medications';
      case 2: return 'Notifications';
      case 3: return 'Reports / History';
      case 4: return 'AI';
      default: return '';
    }
  }

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

    return Scaffold(
      appBar: AppBar(
        title: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
          builder: (context, snap) {
            final data = snap.data?.data();
            final username =
                (data?['username'] as String?) ??
                (data?['displayName'] as String?) ??
                (user.email?.split('@').first ?? 'Patient');

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Welcome $username', style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 2),
                Text(
                  _sectionTitle(_index),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),

      body: pages[_index],

      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: SizedBox(
        height: 64,
        width: 64,
        child: FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => MedicationFormScreen(
                uid: user.uid,
                effectiveDate: DateTime.now(),
                )
              ),
            );
          },
          child: const Icon(Icons.add, size: 30),
        ),
      ),

      bottomNavigationBar: NavigationBar(
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