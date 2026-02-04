import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'role_select_screen.dart';

class RegisterScreen extends StatefulWidget {
  final UserRole role;
  const RegisterScreen({super.key, required this.role});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text;
    final confirm = _confirmCtrl.text;

    // Basic validation
    if (email.isEmpty || password.isEmpty || confirm.isEmpty) {
      setState(() {
        _loading = false;
        _error = "Please fill all fields.";
      });
      return;
    }

    if (password != confirm) {
      setState(() {
        _loading = false;
        _error = "Passwords do not match.";
      });
      return;
    }

    UserCredential? cred;

    try {
      cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = cred.user!.uid;

      // Create user profile in Firestore (role is stored here)
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'email': email,
        'role': widget.role.name, // 'patient' or 'doctor'
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Account created ✅ Please login")),
      );

      // After register, go back to Login screen
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _friendlyAuthError(e));
    } catch (e) {
      // If Firestore write failed AFTER user was created, rollback (delete auth user)
      try {
        await cred?.user?.delete();
      } catch (_) {}

      setState(() => _error = "Something went wrong: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return "This email is already registered.";
      case 'invalid-email':
        return "Invalid email format.";
      case 'weak-password':
        return "Password is too weak (min 6 chars).";
      case 'operation-not-allowed':
        return "Email/Password is not enabled in Firebase Auth.";
      default:
        return e.message ?? "Register failed.";
    }
  }

  @override
  Widget build(BuildContext context) {
    final title =
        widget.role == UserRole.patient ? "Patient Register" : "Doctor Register";

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
                TextField(
                  controller: _confirmCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: "Confirm Password",
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
                    onPressed: _loading ? null : _register,
                    child: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text("Create account"),
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
