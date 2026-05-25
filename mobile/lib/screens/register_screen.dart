import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'auth_gate.dart';
import 'role_select_screen.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  final UserRole role;
  const RegisterScreen({super.key, required this.role});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Step 1
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _doctorLicenseCtrl = TextEditingController();

  // Step 2 (patients only)
  String? _gender;
  DateTime? _birthday;
  final List<String> _conditions = [];

  int _step = 1;
  bool _loading = false;
  String? _error;

  static const _blue = Color(0xFF1E3A8A);
  static const _dark = Color(0xFF0F172A);
  static const _bg = Color(0xFFF3F6FB);

  static const _commonConditions = [
    'Diabetes',
    'Hypertension',
    'Heart Disease',
    'Asthma',
    'Kidney Disease',
    'Arthritis',
    'Thyroid Disorder',
    'High Cholesterol',
  ];

  bool get _isPatient => widget.role == UserRole.patient;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _doctorLicenseCtrl.dispose();
    super.dispose();
  }

  // ── Validation ─────────────────────────────────────────────────────────────

  String? _validateStep1() {
    if (_usernameCtrl.text.trim().isEmpty ||
        _emailCtrl.text.trim().isEmpty ||
        _passCtrl.text.isEmpty) {
      return "Please fill all fields.";
    }
    if (!RegExp(r'^[\w\-.]+@([\w-]+\.)+[\w-]{2,4}$')
        .hasMatch(_emailCtrl.text.trim())) {
      return "Enter a valid email address.";
    }
    if (_passCtrl.text.length < 6) {
      return "Password must be at least 6 characters.";
    }
    return null;
  }

  String? _validateStep2() {
    if (_gender == null) return "Please select your gender.";
    if (_birthday == null) return "Please select your birthday.";
    return null;
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  void _nextStep() {
    final err = _validateStep1();
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _error = null;
      _step = 2;
    });
  }

  void _prevStep() => setState(() {
        _step = 1;
        _error = null;
      });

  // ── Registration ────────────────────────────────────────────────────────────

  Future<void> _register() async {
    if (_isPatient) {
      final err = _validateStep2();
      if (err != null) {
        setState(() => _error = err);
        return;
      }
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    UserCredential? cred;
    try {
      cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );

      final uid = cred.user!.uid;

      final data = <String, dynamic>{
        'email': _emailCtrl.text.trim(),
        'username': _usernameCtrl.text.trim(),
        'role': widget.role.name,
        'createdAt': FieldValue.serverTimestamp(),
      };

      if (!_isPatient) {
        final license = _doctorLicenseCtrl.text.trim();
        if (license.isNotEmpty) data['medicalLicenseId'] = license;
      } else {
        data['gender'] = _gender;
        data['birthday'] = Timestamp.fromDate(_birthday!);
        data['conditions'] = _conditions;
      }

      await FirebaseFirestore.instance.collection('users').doc(uid).set(data);
      await cred.user!.updateDisplayName(_usernameCtrl.text.trim());

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Account created successfully")),
      );
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AuthGate()),
        (_) => false,
      );
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _friendlyError(e));
    } catch (e) {
      try {
        await cred?.user?.delete();
      } catch (_) {}
      setState(() => _error = "Something went wrong. Please try again.");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return "This email is already registered.";
      case 'invalid-email':
        return "Invalid email format.";
      case 'weak-password':
        return "Password is too weak (min 6 chars).";
      default:
        return e.message ?? "Registration failed.";
    }
  }

  // ── Birthday picker ─────────────────────────────────────────────────────────

  Future<void> _pickBirthday() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime(1995, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _birthday = picked);
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isStep2 = _isPatient && _step == 2;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (isStep2) {
              _prevStep();
            } else {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const RoleSelectScreen()),
                (_) => false,
              );
            }
          },
        ),
        title: Text(
          "Create Account",
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: _dark,
          ),
        ),
        centerTitle: false,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Step indicator (patients only)
                if (_isPatient) ...[
                  _StepIndicator(current: _step),
                  const SizedBox(height: 24),
                ],

                if (!isStep2) _buildStep1() else _buildStep2(),

                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!,
                      style: const TextStyle(color: Colors.red, fontSize: 13)),
                ],

                const SizedBox(height: 20),

                // Action button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _dark,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                    ),
                    onPressed: _loading
                        ? null
                        : (isStep2 || !_isPatient) ? _register : _nextStep,
                    child: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            isStep2 || !_isPatient ? "Register" : "Next",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ),

                if (!isStep2) ...[
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Already have an account? "),
                      GestureDetector(
                        onTap: _loading
                            ? null
                            : () => Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const LoginScreen()),
                                  (_) => false,
                                ),
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Step 1 UI ───────────────────────────────────────────────────────────────

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isPatient
              ? "Let's start with your basic info"
              : "Create your doctor account",
          style: const TextStyle(
            color: Color(0xFF475569),
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 24),
        _NiceField(
          label: "User Name",
          hint: "Enter your name",
          controller: _usernameCtrl,
        ),
        const SizedBox(height: 14),
        _NiceField(
          label: "Email",
          hint: "Enter your email",
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 14),
        _NiceField(
          label: "Password",
          hint: "Min 6 characters",
          controller: _passCtrl,
          obscureText: true,
        ),
        if (!_isPatient) ...[
          const SizedBox(height: 14),
          _NiceField(
            label: "Medical License ID (optional)",
            hint: "Enter license number",
            controller: _doctorLicenseCtrl,
          ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }

  // ── Step 2 UI ───────────────────────────────────────────────────────────────

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Tell us about your health",
          style: TextStyle(
            color: Color(0xFF475569),
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 24),

        // Gender
        const _FieldLabel("Gender"),
        const SizedBox(height: 8),
        Row(
          children: ['Male', 'Female'].map((g) {
            final selected = _gender == g;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _gender = g),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: EdgeInsets.only(right: g == 'Male' ? 8 : 0),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: selected ? _blue : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected ? _blue : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Text(
                    g,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),

        // Birthday
        const _FieldLabel("Date of Birth"),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickBirthday,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_outlined,
                    color: Color(0xFF64748B), size: 18),
                const SizedBox(width: 10),
                Text(
                  _birthday == null
                      ? "Select date of birth"
                      : DateFormat('MMMM d, yyyy').format(_birthday!),
                  style: TextStyle(
                    color: _birthday == null
                        ? const Color(0xFF94A3B8)
                        : _dark,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Conditions
        const _FieldLabel("Medical Conditions (optional)"),
        const SizedBox(height: 4),
        const Text(
          "Select all that apply",
          style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _commonConditions.map((c) {
            final selected = _conditions.contains(c);
            return FilterChip(
              label: Text(c, style: const TextStyle(fontSize: 13)),
              selected: selected,
              onSelected: (val) => setState(() {
                if (val) {
                  _conditions.add(c);
                } else {
                  _conditions.remove(c);
                }
              }),
              selectedColor: const Color(0xFFDBEAFE),
              checkmarkColor: _blue,
              side: BorderSide(
                color: selected ? _blue : const Color(0xFFCBD5E1),
              ),
              labelStyle: TextStyle(
                color: selected ? _blue : const Color(0xFF475569),
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ── Step indicator ────────────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  final int current;
  const _StepIndicator({required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StepDot(number: 1, active: current >= 1, label: "Basic Info"),
        Expanded(
          child: Container(
            height: 2,
            color: current >= 2
                ? const Color(0xFF1E3A8A)
                : const Color(0xFFE2E8F0),
          ),
        ),
        _StepDot(number: 2, active: current >= 2, label: "Health Info"),
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  final int number;
  final bool active;
  final String label;
  const _StepDot(
      {required this.number, required this.active, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? const Color(0xFF1E3A8A) : const Color(0xFFE2E8F0),
          ),
          child: Center(
            child: Text(
              '$number',
              style: TextStyle(
                color: active ? Colors.white : const Color(0xFF94A3B8),
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: active
                ? const Color(0xFF1E3A8A)
                : const Color(0xFF94A3B8),
            fontWeight: active ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        color: Color(0xFF0F172A),
        fontSize: 14,
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
        _FieldLabel(label),
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
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}
