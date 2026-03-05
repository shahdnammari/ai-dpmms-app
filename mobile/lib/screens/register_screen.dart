import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

import 'auth_gate.dart';
import 'role_select_screen.dart';
import 'login_screen.dart';
import 'reset_password_screen.dart';

class RegisterScreen extends StatefulWidget {
  final UserRole role;
  const RegisterScreen({super.key, required this.role});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  // Optional field to distinguish doctor/patient (doctor only)
  final _doctorLicenseCtrl = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _doctorLicenseCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final username = _usernameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text;

    if (username.isEmpty || email.isEmpty || password.isEmpty) {
      setState(() {
        _loading = false;
        _error = "Please fill all fields.";
      });
      return;
    }

    // If doctor, you may require license
    final license = _doctorLicenseCtrl.text.trim();

    UserCredential? cred;

    try {
      cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = cred.user!.uid;

      final data = <String, dynamic>{
        'email': email,
        'username': username,
        'role': widget.role.name, // 'patient' or 'doctor'
        'createdAt': FieldValue.serverTimestamp(),
      };

      if (widget.role == UserRole.doctor && license.isNotEmpty) {
        data['medicalLicenseId'] = license;
      }

      await FirebaseFirestore.instance.collection('users').doc(uid).set(data);

      await cred.user!.updateDisplayName(username);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Account created ✅")),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AuthGate()),
        (_) => false,
      );
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _friendlyAuthError(e));
    } catch (e) {
      // rollback if Firestore failed after auth creation
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
    const bg = Color(0xFFF3F6FB);

    final subtitle = (widget.role == UserRole.doctor)
        ? "Create your doctor account to manage patients and follow-ups."
        : "Create your account to track medications and stay on schedule.";

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const RoleSelectScreen()),
              (_) => false,
            );
          },
        ),
        title: Text(
          "Create Account",
          style: GoogleFonts.inter(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
            ),
        ),
        centerTitle: false,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Column(
              
              children: [
                const SizedBox(height: 20),                
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF475569),
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 150),

                _NiceField(
                  label: "User Name",
                  hint: "Enter User Name",
                  controller: _usernameCtrl,
                ),
                const SizedBox(height: 14),

                _NiceField(
                  label: "Email",
                  hint: "Enter your Email",
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 14),

                _NiceField(
                  label: "Password",
                  hint: "Enter your password",
                  controller: _passCtrl,
                  obscureText: true,
                ),

                if (widget.role == UserRole.doctor) ...[
                  const SizedBox(height: 14),
                  _NiceField(
                    label: "Medical License ID (optional)",
                    hint: "Enter license number",
                    controller: _doctorLicenseCtrl,
                  ),
                ],

                const SizedBox(height: 10),

                Align(
                  alignment: Alignment.center,
                  child: TextButton(
                    onPressed: _loading
                        ? null
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ResetPasswordScreen(),
                              ),
                            );
                          },
                      child: const Text(
                        "Forgot password?",
                        style: TextStyle(
                          color: Color(0xFF3B82F6),
                          fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),

                if (_error != null) ...[
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 10),
                ],

                const SizedBox(height: 10),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 6,
                    ),
                    onPressed: _loading ? null : _register,
                    child: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            "Register",
                            style: TextStyle(
                            color: Color(0xFFFFFFFF), 
                            fontWeight: FontWeight.w800
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 14),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Already have an account? "),
                    InkWell(
                      onTap: _loading
                          ? null
                          : () {
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const LoginScreen(),
                                ),
                                (_) => false,
                              );
                            },
                      child: const Text(
                        "Login",
                        style: TextStyle(
                          color: Color(0xFF3B82F6),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NiceField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final bool obscureText;
  final TextInputType? keyboardType;

  const _NiceField({
    required this.label,
    required this.hint,
    required this.controller,
    this.obscureText = false,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}