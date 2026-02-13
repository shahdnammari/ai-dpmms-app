import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../role_select_screen.dart';
import 'patient_home_tab.dart';
import 'medications_list_screen.dart';

import '../../screens/patient/medication_form_screen.dart';

class PatientShell extends StatefulWidget {
  const PatientShell({super.key});

  @override
  State<PatientShell> createState() => _PatientShellState();
}

class _PatientShellState extends State<PatientShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const RoleSelectScreen();

    final pages = <Widget>[
      const PatientHomeTab(),
      MedicationsListScreen(),
      const _PlaceholderPage(title: 'Notifications (soon)'),
      const _PlaceholderPage(title: 'Reports / History (soon)'),
      const _PlaceholderPage(title: 'AI (soon)'),
    ];

    return Scaffold(
      body: pages[_index],

      // ✅ زر + كبير ثابت بكل الصفحات
      
      floatingActionButton: SizedBox(
        height: 64,
        width: 64,
        child: FloatingActionButton(
            onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => MedicationFormScreen(uid: user.uid)),
            );
          },
          child: const Icon(Icons.add),
        ),
      ),

      // ✅ Bottom Navigation ثابت بكل الصفحات
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
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text(title)),
    );
  }
}
