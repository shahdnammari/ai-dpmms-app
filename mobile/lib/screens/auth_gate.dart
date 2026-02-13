import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'role_select_screen.dart';
import 'doctor_home_screen.dart';
import 'patient/patient_shell.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Future<Widget> _routeByRole(User user) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!doc.exists) {
      await FirebaseAuth.instance.signOut();
      return const RoleSelectScreen();
    }

    final role = (doc.data()?['role'] as String?)?.toLowerCase();

    if (role == 'patient') return const PatientShell();
    if (role == 'doctor') return const DoctorHomeScreen();

    await FirebaseAuth.instance.signOut();
    return const RoleSelectScreen();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {
        // Firebase still initializing
        if (authSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Not logged in
        final user = authSnap.data;
        if (user == null) {
          return const RoleSelectScreen();
        }

        // Logged in → decide by role
        return FutureBuilder<Widget>(
          future: _routeByRole(user),
          builder: (context, roleSnap) {
            if (roleSnap.connectionState != ConnectionState.done) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            return roleSnap.data ?? const RoleSelectScreen();
          },
        );
      },
    );
  }
}
