import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' hide TextDirection;

import 'auth_gate.dart';
import 'role_select_screen.dart';
import 'login_screen.dart';
import '../l10n/app_strings.dart';
import '../services/settings_service.dart';

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
  final _doctorLicenseCtrl = TextEditingController();
  final _customConditionCtrl = TextEditingController();

  String? _gender;
  DateTime? _birthday;
  final List<String> _conditions = [];

  int _step = 1;
  bool _loading = false;
  String? _error;

  static const _blue = Color(0xFF1E3A8A);

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
    _customConditionCtrl.dispose();
    super.dispose();
  }

  void _addCustomCondition() {
    final val = _customConditionCtrl.text.trim();
    if (val.isEmpty) return;
    if (!_conditions.contains(val)) {
      setState(() => _conditions.add(val));
    }
    _customConditionCtrl.clear();
  }

  String? _validateStep1(S s) {
    if (_usernameCtrl.text.trim().isEmpty ||
        _emailCtrl.text.trim().isEmpty ||
        _passCtrl.text.isEmpty) {
      return s.authEmptyFields;
    }
    if (!RegExp(r'^[\w\-.]+@([\w-]+\.)+[\w-]{2,4}$')
        .hasMatch(_emailCtrl.text.trim())) {
      return s.authInvalidEmailFormat;
    }
    if (_passCtrl.text.length < 6) {
      return s.authWeakPassword;
    }
    return null;
  }

  String? _validateStep2(S s) {
    if (_gender == null) return s.authSelectGender;
    if (_birthday == null) return s.authSelectBirthday;
    return null;
  }

  void _nextStep() {
    final s = S.of(context);
    final err = _validateStep1(s);
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

  Future<void> _register() async {
    final s = S.of(context);

    if (_isPatient) {
      final err = _validateStep2(s);
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
        SnackBar(content: Text(s.accountCreated)),
      );
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AuthGate()),
        (_) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = _friendlyError(e, s));
    } catch (_) {
      try {
        await cred?.user?.delete();
      } catch (_) {}
      if (!mounted) return;
      setState(() => _error = s.authSomethingWentWrong);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyError(FirebaseAuthException e, S s) {
    switch (e.code) {
      case 'email-already-in-use': return s.authEmailInUse;
      case 'invalid-email': return s.authInvalidEmailFormat;
      case 'weak-password': return s.authWeakPasswordShort;
      default: return e.message ?? s.authRegistrationFailed;
    }
  }

  Future<void> _pickBirthday() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime(1995, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _birthday = picked);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isRtl = SettingsService.instance.isRtl;
    final isStep2 = _isPatient && _step == 2;

    final bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF3F6FB);
    final primaryText = isDark ? Colors.white : const Color(0xFF0F172A);
    final secondaryText = isDark ? Colors.white70 : const Color(0xFF64748B);

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          elevation: 0,
          iconTheme: IconThemeData(color: primaryText),
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
            s.createAccount,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: primaryText,
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
                  if (_isPatient) ...[
                    _StepIndicator(current: _step),
                    const SizedBox(height: 24),
                  ],

                  if (!isStep2)
                    _buildStep1(s, isDark, secondaryText)
                  else
                    _buildStep2(s, isDark, primaryText, secondaryText),

                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!,
                        style:
                            const TextStyle(color: Colors.red, fontSize: 13)),
                  ],

                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
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
                              isStep2 || !_isPatient ? s.register : s.nextBtn,
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
                        Text(
                          '${s.alreadyHaveAccount} ',
                          style: TextStyle(color: secondaryText),
                        ),
                        GestureDetector(
                          onTap: _loading
                              ? null
                              : () => Navigator.pushAndRemoveUntil(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => const LoginScreen()),
                                    (_) => false,
                                  ),
                          child: Text(
                            s.loginTitle,
                            style: const TextStyle(
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
      ),
    );
  }

  Widget _buildStep1(S s, bool isDark, Color secondaryText) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isPatient ? s.createPatientSubtitle : s.createDoctorSubtitle,
          style: TextStyle(
            color: secondaryText,
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 24),
        _NiceField(
          label: s.userName,
          hint: s.enterNameHint,
          controller: _usernameCtrl,
        ),
        const SizedBox(height: 14),
        _NiceField(
          label: s.email,
          hint: s.enterEmailHint,
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 14),
        _NiceField(
          label: s.password,
          hint: s.minPasswordHint,
          controller: _passCtrl,
          obscureText: true,
        ),
        if (!_isPatient) ...[
          const SizedBox(height: 14),
          _NiceField(
            label: s.medicalLicenseOptional,
            hint: s.enterLicenseHint,
            controller: _doctorLicenseCtrl,
          ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildStep2(S s, bool isDark, Color primaryText, Color secondaryText) {
    final borderColor =
        isDark ? const Color(0xFF3A3A5C) : const Color(0xFFE2E8F0);
    final fieldFill = isDark ? const Color(0xFF1E1E2E) : Colors.white;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.healthInfoSubtitle,
          style: TextStyle(
            color: secondaryText,
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 24),

        // Gender
        _FieldLabel(s.gender),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _gender = 'Male'),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: _gender == 'Male' ? _blue : fieldFill,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _gender == 'Male' ? _blue : borderColor,
                    ),
                  ),
                  child: Text(
                    s.male,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _gender == 'Male' ? Colors.white : secondaryText,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _gender = 'Female'),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: _gender == 'Female' ? _blue : fieldFill,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _gender == 'Female' ? _blue : borderColor,
                    ),
                  ),
                  child: Text(
                    s.female,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color:
                          _gender == 'Female' ? Colors.white : secondaryText,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Birthday
        _FieldLabel(s.birthday),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickBirthday,
          child: Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: fieldFill,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today_outlined,
                    color: secondaryText, size: 18),
                const SizedBox(width: 10),
                Text(
                  _birthday == null
                      ? s.selectBirthday
                      : DateFormat('MMMM d, yyyy').format(_birthday!),
                  style: TextStyle(
                    color: _birthday == null
                        ? (isDark
                            ? Colors.white38
                            : const Color(0xFF94A3B8))
                        : primaryText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Medical conditions
        _FieldLabel(s.medicalConditionsOptional),
        const SizedBox(height: 4),
        Text(
          s.selectAllThatApply,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ..._commonConditions.map((c) {
              final selected = _conditions.contains(c);
              return FilterChip(
                label: Text(s.conditionName(c),
                    style: const TextStyle(fontSize: 13)),
                selected: selected,
                onSelected: (val) => setState(() {
                  if (val) {
                    _conditions.add(c);
                  } else {
                    _conditions.remove(c);
                  }
                }),
                backgroundColor:
                    isDark ? const Color(0xFF2A2A4A) : Colors.white,
                selectedColor: isDark
                    ? const Color(0xFF1E3A8A).withValues(alpha: 0.5)
                    : const Color(0xFFDBEAFE),
                checkmarkColor: _blue,
                side: BorderSide(
                  color: selected
                      ? _blue
                      : (isDark
                          ? const Color(0xFF3A3A5C)
                          : const Color(0xFFCBD5E1)),
                ),
                labelStyle: TextStyle(
                  color: selected
                      ? (isDark ? Colors.white : _blue)
                      : (isDark
                          ? Colors.white70
                          : const Color(0xFF475569)),
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w400,
                ),
              );
            }),
            ..._conditions
                .where((c) => !_commonConditions.contains(c))
                .map((c) => Chip(
                      label: Text(c,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700)),
                      onDeleted: () =>
                          setState(() => _conditions.remove(c)),
                      backgroundColor: isDark
                          ? const Color(0xFF1E3A8A).withValues(alpha: 0.5)
                          : const Color(0xFFDBEAFE),
                      deleteIconColor:
                          isDark ? Colors.white70 : _blue,
                      labelStyle: TextStyle(
                          color: isDark ? Colors.white : _blue),
                      side: BorderSide(color: _blue),
                    )),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _customConditionCtrl,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _addCustomCondition(),
                style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontSize: 14),
                decoration: InputDecoration(
                  hintText: s.customConditionHint,
                  hintStyle: TextStyle(
                      color: isDark
                          ? Colors.white38
                          : const Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: fieldFill,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color(0xFF3B82F6)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 46,
              height: 46,
              child: ElevatedButton(
                onPressed: _addCustomCondition,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _blue,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 22),
              ),
            ),
          ],
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
    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        _StepDot(number: 1, active: current >= 1, label: s.stepBasicInfo),
        Expanded(
          child: Container(
            height: 2,
            color: current >= 2
                ? const Color(0xFF1E3A8A)
                : (isDark
                    ? const Color(0xFF3A3A5C)
                    : const Color(0xFFE2E8F0)),
          ),
        ),
        _StepDot(number: 2, active: current >= 2, label: s.stepHealthInfo),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inactiveCircle =
        isDark ? const Color(0xFF2A2A4A) : const Color(0xFFE2E8F0);
    final inactiveText =
        isDark ? Colors.white38 : const Color(0xFF94A3B8);

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? const Color(0xFF1E3A8A) : inactiveCircle,
          ),
          child: Center(
            child: Text(
              '$number',
              style: TextStyle(
                color: active ? Colors.white : inactiveText,
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
            color: active ? const Color(0xFF1E3A8A) : inactiveText,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      text,
      style: TextStyle(
        fontWeight: FontWeight.w700,
        color: isDark ? Colors.white : const Color(0xFF0F172A),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fillColor = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final hintColor = isDark ? Colors.white38 : const Color(0xFF94A3B8);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: hintColor),
            filled: true,
            fillColor: fillColor,
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