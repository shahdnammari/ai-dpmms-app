import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'role_select_screen.dart';

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

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isEditMode = false;

  String _originalName = '';
  String _originalEmail = '';
  String _originalGender = '';
  DateTime? _originalBirthday;

  static const Color _primary = Color(0xFF0D1B4C);
  static const Color _accent = Color(0xFF1E3A8A);
  static const Color _red = Color(0xFFDC2626);
  static const Color _bg = Color(0xFFF4F5FB);
  static const Color _cardBg = Color(0xFFF7F7FA);

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

      final name = (data['name'] ?? data['username'] ?? '').toString();
      final email = (data['email'] ?? user.email ?? '').toString();
      final gender = (data['gender'] ?? '').toString();
      final role = (data['role'] ?? 'patient').toString();

      DateTime? birthday;
      final birthdayValue = data['birthday'];
      if (birthdayValue is Timestamp) {
        birthday = birthdayValue.toDate();
      } else if (birthdayValue is String && birthdayValue.isNotEmpty) {
        try {
          birthday = DateTime.parse(birthdayValue);
        } catch (_) {}
      }

      _nameController.text = name;
      _emailController.text = email;
      _selectedGender = gender.isEmpty ? null : _normalizeGenderForUi(gender);
      _selectedBirthday = birthday;
      _role = role;

      _originalName = name;
      _originalEmail = email;
      _originalGender = _selectedGender ?? '';
      _originalBirthday = birthday;
    } catch (e) {
      _showSnackBar('Failed to load profile: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _normalizeGenderForUi(String value) {
    final v = value.trim().toLowerCase();
    if (v == 'female') return 'Female';
    if (v == 'male') return 'Male';
    return value;
  }

  String _displayRole(String role) {
    final r = role.trim().toLowerCase();
    if (r == 'patient') return 'Patient';
    if (r == 'doctor') return 'Doctor';
    return role;
  }

  bool get _hasChanges {
    final birthdayChanged =
        (_originalBirthday?.year != _selectedBirthday?.year) ||
            (_originalBirthday?.month != _selectedBirthday?.month) ||
            (_originalBirthday?.day != _selectedBirthday?.day);

    return _nameController.text.trim() != _originalName.trim() ||
        _emailController.text.trim() != _originalEmail.trim() ||
        (_selectedGender ?? '') != _originalGender ||
        birthdayChanged;
  }

  void _enterEditMode() {
    if (_isEditMode) return;
    setState(() => _isEditMode = true);
  }

  void _restoreOriginalValues() {
    _nameController.text = _originalName;
    _emailController.text = _originalEmail;
    _selectedGender = _originalGender.isEmpty ? null : _originalGender;
    _selectedBirthday = _originalBirthday;
  }

  Future<String?> _showUnsavedDialog() {
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Discard changes?',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'Any changes you made will not be saved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: const Text(
              'Keep editing',
              style: TextStyle(color: _accent),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(context, 'discard'),
            child: const Text('Discard'),
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
    final now = DateTime.now();
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
    if (!_formKey.currentState!.validate()) return;

    if (_selectedGender == null || _selectedGender!.isEmpty) {
      _showSnackBar('Please select gender', isError: true);
      return;
    }

    if (_selectedBirthday == null) {
      _showSnackBar('Please select birthday', isError: true);
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
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'gender': _selectedGender,
        'birthday': Timestamp.fromDate(_selectedBirthday!),
        'role': _role,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _originalName = _nameController.text.trim();
      _originalEmail = _emailController.text.trim();
      _originalGender = _selectedGender ?? '';
      _originalBirthday = _selectedBirthday;

      setState(() {
        _isEditMode = false;
        
      });

      _showSnackBar('Profile updated successfully');
    } catch (e) {
      _showSnackBar('Failed to save profile: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Logout?',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'Are you sure you want to logout?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: _accent),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
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

  String _formattedBirthday() {
    if (_selectedBirthday == null) return 'Select birthday';
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

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: BorderSide(color: Colors.grey.shade300),
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
            decoration: _inputDecoration(label),
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF1E2A4A),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildViewMode() {
    return Column(
      children: [
        _buildTapToEditField(
          label: 'User Name',
          value: _nameController.text,
        ),
        _buildTapToEditField(
          label: 'Email',
          value: _emailController.text,
        ),
        _buildTapToEditField(
          label: 'Gender',
          value: _selectedGender ?? '-',
        ),
        _buildTapToEditField(
          label: 'Birthday',
          value: _formattedBirthday(),
          onTap: _pickBirthday,
        ),
        _buildTapToEditField(
          label: 'Role',
          value: _displayRole(_role),
        ),
      ],
    );
  }

  Widget _buildEditMode() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _nameController,
            decoration: _inputDecoration('User Name'),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your name';
              }
              if (value.trim().length < 2) {
                return 'Name is too short';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: _inputDecoration('Email'),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your email';
              }
              final emailRegex = RegExp(
                r'^[\w\-.]+@([\w-]+\.)+[\w-]{2,4}$',
              );
              if (!emailRegex.hasMatch(value.trim())) {
                return 'Enter a valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: (_selectedGender == 'Female' || _selectedGender == 'Male')
                ? _selectedGender
                : null,
            decoration: _inputDecoration('Gender'),
            items: const [
              DropdownMenuItem(
                value: 'Female',
                child: Text('Female'),
              ),
              DropdownMenuItem(
                value: 'Male',
                child: Text('Male'),
              ),
            ],
            onChanged: (value) {
              setState(() {
                _selectedGender = value;
              });
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please select gender';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _pickBirthday,
            child: AbsorbPointer(
              child: TextFormField(
                controller: TextEditingController(text: _formattedBirthday()),
                decoration: _inputDecoration('Birthday'),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            initialValue: _displayRole(_role),
            enabled: false,
            decoration: _inputDecoration('Role'),
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
                      borderRadius: BorderRadius.circular(20),
                    ),
                    side: const BorderSide(color: _primary),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
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
                      borderRadius: BorderRadius.circular(20),
                    ),
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
                      : const Text(
                          'Save',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final canPop = await _handleBack();
        if (canPop && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _bg,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
            onPressed: () async {
              final canPop = await _handleBack();
              if (canPop && context.mounted) Navigator.pop(context);
            },
          ),
          title: const Text(
            'Profile',
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w700,
            ),
          ),
          actions: [
            if (!_isLoading && !_isEditMode)
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: _primary),
                onPressed: _enterEditMode,
              ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _currentUser == null
                ? const Center(child: Text('No user is logged in'))
                : SafeArea(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 10,
                      ),
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
                            child: const Icon(
                              Icons.person,
                              size: 58,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Container(
                            width: double.infinity,
                            constraints: const BoxConstraints(
                              minHeight: 400,
                            ),
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: _cardBg,
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
                                _isEditMode ? _buildEditMode() : _buildViewMode(),
                              ],
                            ),
                          ),
                          const SizedBox(height: 26),
                          TextButton.icon(
                            onPressed: _logout,
                            icon: const Icon(
                              Icons.logout,
                              color: Colors.red,
                              size: 20,
                            ),
                            label: const Text(
                              'Logout',
                              style: TextStyle(
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