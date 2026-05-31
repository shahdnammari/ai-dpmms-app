import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_strings.dart';
import 'role_select_screen.dart';
import 'patient/settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  DateTime? _selectedBirthday;
  String? _selectedGender;
  String _role = 'patient';
  List<String> _selectedConditions = [];

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isEditMode = false;

  String _originalName = '';
  String _originalEmail = '';
  String _originalGender = '';
  DateTime? _originalBirthday;
  List<String> _originalConditions = [];

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

  static const Color _primary = Color(0xFF0D1B4C);
  static const Color _accent  = Color(0xFF1E3A8A);
  static const Color _red     = Color(0xFFDC2626);

  User? get _currentUser => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final user = _currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = doc.data() ?? {};

      final name   = (data['name'] ?? data['username'] ?? '').toString();
      final email  = (data['email'] ?? user.email ?? '').toString();
      final gender = (data['gender'] ?? '').toString();
      final role   = (data['role'] ?? 'patient').toString();

      DateTime? birthday;
      final birthdayValue = data['birthday'];
      if (birthdayValue is Timestamp) {
        birthday = birthdayValue.toDate();
      } else if (birthdayValue is String && birthdayValue.isNotEmpty) {
        try {
          birthday = DateTime.parse(birthdayValue);
        } catch (_) {}
      }

      final conditions = List<String>.from((data['conditions'] as List?) ?? []);

      _nameController.text  = name;
      _emailController.text = email;
      _selectedGender       = gender.isEmpty ? null : _normalizeGenderForUi(gender);
      _selectedBirthday     = birthday;
      _role                 = role;
      _selectedConditions   = conditions;

      _originalName       = name;
      _originalEmail      = email;
      _originalGender     = _selectedGender ?? '';
      _originalBirthday   = birthday;
      _originalConditions = List<String>.from(conditions);
    } catch (e) {
      _showSnackBar('Failed to load profile: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _normalizeGenderForUi(String value) {
    final v = value.trim().toLowerCase();
    if (v == 'female') return 'Female';
    if (v == 'male')   return 'Male';
    return value;
  }

  String _displayRole(String role, S s) {
    final r = role.trim().toLowerCase();
    if (r == 'patient') return s.rolePatient;
    if (r == 'doctor')  return s.roleDoctor;
    return role;
  }

  String _displayGender(String? gender, S s) {
    if (gender == null || gender.isEmpty) return '-';
    if (gender == 'Female') return s.female;
    if (gender == 'Male')   return s.male;
    return gender;
  }

  bool get _hasChanges {
    final birthdayChanged =
        (_originalBirthday?.year  != _selectedBirthday?.year)  ||
        (_originalBirthday?.month != _selectedBirthday?.month) ||
        (_originalBirthday?.day   != _selectedBirthday?.day);

    final conditionsChanged =
        _selectedConditions.length != _originalConditions.length ||
        !_selectedConditions.every(_originalConditions.contains);

    return _nameController.text.trim() != _originalName.trim()   ||
        _emailController.text.trim() != _originalEmail.trim()    ||
        (_selectedGender ?? '') != _originalGender               ||
        birthdayChanged                                          ||
        conditionsChanged;
  }

  void _enterEditMode() {
    if (_isEditMode) return;
    setState(() => _isEditMode = true);
  }

  void _restoreOriginalValues() {
    _nameController.text  = _originalName;
    _emailController.text = _originalEmail;
    _selectedGender       = _originalGender.isEmpty ? null : _originalGender;
    _selectedBirthday     = _originalBirthday;
    _selectedConditions   = List<String>.from(_originalConditions);
  }

  Future<String?> _showUnsavedDialog() {
    final s = S.of(context);
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(s.discardChanges,
            style: const TextStyle(fontWeight: FontWeight.w800)),
        content: Text(s.discardMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: Text(s.keepEditing,
                style: const TextStyle(color: _accent)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, 'discard'),
            child: Text(s.discard),
          ),
        ],
      ),
    );
  }

  Future<bool> _handleBack() async {
    if (!_isEditMode) return true;

    if (!_hasChanges) {
      setState(() => _isEditMode = false);
      return true;
    }

    final result = await _showUnsavedDialog();

    if (result == 'discard') {
      _restoreOriginalValues();
      setState(() => _isEditMode = false);
      return false;
    }

    return false;
  }

  Future<void> _cancelEdit() async {
    if (!_hasChanges) {
      setState(() => _isEditMode = false);
      return;
    }

    final result = await _showUnsavedDialog();

    if (result == 'discard') {
      _restoreOriginalValues();
      setState(() => _isEditMode = false);
    }
  }

  Future<void> _pickBirthday() async {
    final now         = DateTime.now();
    final initialDate = _selectedBirthday ?? DateTime(2002, 9, 22);

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year, now.month, now.day),
    );

    if (picked != null) {
      setState(() {
        _selectedBirthday = picked;
        _isEditMode = true;
      });
    }
  }

  Future<void> _saveProfile() async {
    final s = S.of(context);
    if (!_formKey.currentState!.validate()) return;

    if (_selectedGender == null || _selectedGender!.isEmpty) {
      _showSnackBar(s.profileSelectGender, isError: true);
      return;
    }

    if (_selectedBirthday == null) {
      _showSnackBar(s.profileSelectBirthday, isError: true);
      return;
    }

    final user = _currentUser;
    if (user == null) {
      _showSnackBar('No logged in user found', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'name':       _nameController.text.trim(),
        'email':      _emailController.text.trim(),
        'gender':     _selectedGender,
        'birthday':   Timestamp.fromDate(_selectedBirthday!),
        'conditions': _selectedConditions,
        'role':       _role,
        'updatedAt':  FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _originalName       = _nameController.text.trim();
      _originalEmail      = _emailController.text.trim();
      _originalGender     = _selectedGender ?? '';
      _originalBirthday   = _selectedBirthday;
      _originalConditions = List<String>.from(_selectedConditions);

      setState(() => _isEditMode = false);
      _showSnackBar(s.profileUpdated);
    } catch (e) {
      _showSnackBar('Failed to save profile: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _logout() async {
    final s = S.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(s.logoutConfirmTitle,
            style: const TextStyle(fontWeight: FontWeight.w800)),
        content: Text(s.logoutConfirmMsg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.cancel, style: const TextStyle(color: _accent)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.logoutButton),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const RoleSelectScreen()),
        (route) => false,
      );
    } catch (e) {
      _showSnackBar('Logout failed: $e', isError: true);
    }
  }

  String _formattedBirthday(S s) {
    if (_selectedBirthday == null) return s.selectBirthday;
    return DateFormat('MMMM d, yyyy').format(_selectedBirthday!);
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  InputDecoration _inputDecoration(String label, BuildContext ctx) {
    final surface     = Theme.of(ctx).colorScheme.surface;
    final isDark      = Theme.of(ctx).brightness == Brightness.dark;
    final borderColor = isDark ? Colors.grey.shade700 : Colors.grey.shade300;

    return InputDecoration(
      labelText: label,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      filled: true,
      fillColor: surface,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: BorderSide(color: borderColor),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(color: _primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
    );
  }

  Widget _buildTapToEditField({
    required BuildContext ctx,
    required String label,
    required String value,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: () {
          _enterEditMode();
          onTap?.call();
        },
        child: AbsorbPointer(
          child: TextFormField(
            initialValue: value,
            enabled: false,
            decoration: _inputDecoration(label, ctx),
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(ctx).colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildViewMode(BuildContext ctx) {
    final s      = S.of(ctx);
    final isDark = Theme.of(ctx).brightness == Brightness.dark;

    final chipBg     = isDark
        ? const Color(0xFF1E3A8A).withValues(alpha: 0.22)
        : const Color(0xFFEFF6FF);
    final chipBorder = isDark
        ? const Color(0xFF1E3A8A).withValues(alpha: 0.5)
        : const Color(0xFFBFDBFE);
    final chipText   = isDark
        ? const Color(0xFF93C5FD)
        : const Color(0xFF1E3A8A);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTapToEditField(
            ctx: ctx, label: s.userName, value: _nameController.text),
        _buildTapToEditField(
            ctx: ctx, label: s.email, value: _emailController.text),
        _buildTapToEditField(
            ctx: ctx, label: s.gender, value: _displayGender(_selectedGender, s)),
        _buildTapToEditField(
          ctx: ctx,
          label: s.birthday,
          value: _formattedBirthday(s),
          onTap: _pickBirthday,
        ),
        _buildTapToEditField(
            ctx: ctx, label: s.role, value: _displayRole(_role, s)),
        const SizedBox(height: 4),
        Text(
          s.medicalConditions,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.55),
          ),
        ),
        const SizedBox(height: 8),
        _selectedConditions.isEmpty
            ? GestureDetector(
                onTap: _enterEditMode,
                child: Text(
                  s.tapToAddConditions,
                  style: TextStyle(
                    color: Theme.of(ctx)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.35),
                    fontSize: 14,
                  ),
                ),
              )
            : Wrap(
                spacing: 8,
                runSpacing: 6,
                children: _selectedConditions
                    .map((c) => Chip(
                          label: Text(c,
                              style: const TextStyle(fontSize: 13)),
                          backgroundColor: chipBg,
                          side: BorderSide(color: chipBorder),
                          labelStyle: TextStyle(color: chipText),
                        ))
                    .toList(),
              ),
      ],
    );
  }

  Widget _buildEditMode(BuildContext ctx) {
    final s      = S.of(ctx);
    final isDark = Theme.of(ctx).brightness == Brightness.dark;

    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _nameController,
            decoration: _inputDecoration(s.userName, ctx),
            style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return s.enterName;
              if (value.trim().length < 2) return s.nameTooShort;
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: _inputDecoration(s.email, ctx),
            style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return s.enterEmail;
              final emailRegex = RegExp(r'^[\w\-.]+@([\w-]+\.)+[\w-]{2,4}$');
              if (!emailRegex.hasMatch(value.trim())) return s.invalidEmail;
              return null;
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: (_selectedGender == 'Female' || _selectedGender == 'Male')
                ? _selectedGender
                : null,
            decoration: _inputDecoration(s.gender, ctx),
            dropdownColor: Theme.of(ctx).colorScheme.surface,
            style: TextStyle(
              color: Theme.of(ctx).colorScheme.onSurface,
              fontSize: 14,
            ),
            items: [
              DropdownMenuItem(value: 'Female', child: Text(s.female)),
              DropdownMenuItem(value: 'Male',   child: Text(s.male)),
            ],
            onChanged: (value) => setState(() => _selectedGender = value),
            validator: (value) {
              if (value == null || value.isEmpty) return s.profileSelectGender;
              return null;
            },
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _pickBirthday,
            child: AbsorbPointer(
              child: TextFormField(
                controller: TextEditingController(
                    text: _formattedBirthday(s)),
                decoration: _inputDecoration(s.birthday, ctx),
                style: TextStyle(
                  color: Theme.of(ctx).colorScheme.onSurface,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            initialValue: _displayRole(_role, s),
            enabled: false,
            decoration: _inputDecoration(s.role, ctx),
            style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface),
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              s.medicalConditions,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Theme.of(ctx)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _commonConditions.map((condition) {
              final selected = _selectedConditions.contains(condition);
              return FilterChip(
                label: Text(condition,
                    style: const TextStyle(fontSize: 13)),
                selected: selected,
                onSelected: (val) {
                  setState(() {
                    if (val) {
                      _selectedConditions.add(condition);
                    } else {
                      _selectedConditions.remove(condition);
                    }
                  });
                },
                selectedColor: isDark
                    ? const Color(0xFF1E3A8A).withValues(alpha: 0.3)
                    : const Color(0xFFDBEAFE),
                checkmarkColor: isDark
                    ? const Color(0xFF93C5FD)
                    : const Color(0xFF1E3A8A),
                side: BorderSide(
                  color: selected
                      ? const Color(0xFF1E3A8A)
                      : (isDark
                          ? Colors.grey.shade600
                          : Colors.grey.shade300),
                ),
                labelStyle: TextStyle(
                  color: selected
                      ? (isDark
                          ? const Color(0xFF93C5FD)
                          : const Color(0xFF1E3A8A))
                      : (isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade700),
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w400,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSaving ? null : _cancelEdit,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    side: const BorderSide(color: _primary),
                  ),
                  child: Text(
                    s.cancel,
                    style: const TextStyle(
                      color: _primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : Text(s.save,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final canPop = await _handleBack();
        if (canPop && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios,
                color: Theme.of(context).colorScheme.onSurface),
            onPressed: () async {
              final canPop = await _handleBack();
              if (canPop && context.mounted) Navigator.pop(context);
            },
          ),
          title: Text(
            s.profileTitle,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          actions: [
            if (!_isLoading && !_isEditMode) ...[
              IconButton(
                icon: const Icon(Icons.settings_outlined, color: _primary),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: _primary),
                onPressed: _enterEditMode,
              ),
            ],
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _currentUser == null
                ? Center(child: Text(s.notSignedIn))
                : SafeArea(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 10),
                      child: Column(
                        children: [
                          Container(
                            width: 108,
                            height: 108,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: _primary,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 14,
                                  offset: Offset(0, 6),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.person,
                                size: 58, color: Colors.white),
                          ),
                          const SizedBox(height: 24),
                          Container(
                            width: double.infinity,
                            constraints: const BoxConstraints(minHeight: 400),
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 14,
                                  offset: Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                _isEditMode
                                    ? _buildEditMode(context)
                                    : _buildViewMode(context),
                              ],
                            ),
                          ),
                          const SizedBox(height: 26),
                          TextButton.icon(
                            onPressed: _logout,
                            icon: const Icon(Icons.logout,
                                color: Colors.red, size: 20),
                            label: Text(
                              s.logoutButton,
                              style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.w600,
                              ),
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
