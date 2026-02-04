import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'register_screen.dart';
import 'role_select_screen.dart';
import 'patient_home_screen.dart';
import 'doctor_home_screen.dart';

class LoginScreen extends StatefulWidget {
  final UserRole role; // UI label + pass to register
  const LoginScreen({super.key, required this.role});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text;

    // Basic validation
    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _loading = false;
        _error = "Please enter email and password.";
      });
      return;
    }

    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = cred.user!.uid;

      // Read profile from Firestore (source of truth)
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (!doc.exists) {
        await FirebaseAuth.instance.signOut();
        throw Exception("Profile not found in Firestore. Please register again.");
      }

      final data = doc.data();
      final roleStr = (data?['role'] as String?)?.toLowerCase();

      if (roleStr == null) {
        await FirebaseAuth.instance.signOut();
        throw Exception("Role missing in Firestore profile. Please register again.");
      }

      if (!mounted) return;

      // Optional: if user selected a different role screen than stored role
      final selectedRole = widget.role.name; // 'patient' or 'doctor'
      if (roleStr != selectedRole) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "You are registered as ${roleStr.toUpperCase()}, redirecting...",
            ),
          ),
        );
      }

      // Navigate by Firestore role
      if (roleStr == 'patient') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const PatientHomeScreen()),
        );
      } else if (roleStr == 'doctor') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DoctorHomeScreen()),
        );
      } else {
        await FirebaseAuth.instance.signOut();
        throw Exception("Unknown role: $roleStr");
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _friendlyAuthError(e));
    } catch (e) {
      setState(() => _error = "Something went wrong: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return "Invalid email format.";
      case 'user-not-found':
        return "No account found for this email.";
      case 'wrong-password':
        return "Wrong password.";
      case 'invalid-credential':
        return "Invalid email or password.";
      case 'user-disabled':
        return "This user has been disabled.";
      case 'too-many-requests':
        return "Too many attempts. Try again later.";
      default:
        return e.message ?? "Login failed.";
    }
  }

  @override
  Widget build(BuildContext context) {
    final title =
        widget.role == UserRole.patient ? "Patient Login" : "Doctor Login";

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: "Email",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: "Password",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                if (_error != null) ...[
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 8),
                ],

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _login,
                    child: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text("Login"),
                  ),
                ),
                const SizedBox(height: 10),

                TextButton(
                  onPressed: _loading
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RegisterScreen(role: widget.role),
                            ),
                          );
                        },
                  child: const Text("Create new account"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
