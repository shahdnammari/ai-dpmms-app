import 'package:flutter/material.dart';
import 'login_screen.dart';

enum UserRole { patient, doctor }

class RoleSelectScreen extends StatelessWidget {
  const RoleSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Choose Role")),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Continue as",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () {// PATIENT
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LoginScreen(role: UserRole.patient),
                        ),
                      );
                    },
                    icon: const Icon(Icons.person),
                    label: const Text("Patient"),
                  ),
                ),
                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () { // DOCTOR
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LoginScreen(role: UserRole.doctor),
                        ),
                      );
                    },
                    icon: const Icon(Icons.medical_services),
                    label: const Text("Doctor"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
