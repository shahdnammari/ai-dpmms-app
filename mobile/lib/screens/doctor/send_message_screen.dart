import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../l10n/app_strings.dart';

class SendMessageScreen extends StatefulWidget {
  final String? prefilledPatientId;
  final String? prefilledPatientName;
  final String? prefilledMessage;
  final bool isReminder;

  const SendMessageScreen({
    super.key,
    this.prefilledPatientId,
    this.prefilledPatientName,
    this.prefilledMessage,
    this.isReminder = false,
  });

  @override
  State<SendMessageScreen> createState() => _SendMessageScreenState();
}

class _SendMessageScreenState extends State<SendMessageScreen> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _messageCtrl;

  String? _selectedPatientId;
  String? _selectedPatientName;
  String? _selectedMedication;

  bool _loading            = false;
  bool _fetchingPatients   = true;
  bool _fetchingMedications = false;

  List<Map<String, String>> _patients    = [];
  List<String>              _medications = [];

  static const _blue = Color(0xFF1E3A8A);

  @override
  void initState() {
    super.initState();
    _titleCtrl   = TextEditingController(
        text: widget.isReminder ? 'Reminder' : '');
    _messageCtrl = TextEditingController(
        text: widget.prefilledMessage ?? '');
    _selectedPatientId   = widget.prefilledPatientId;
    _selectedPatientName = widget.prefilledPatientName;
    _fetchPatients();
    if (_selectedPatientId != null) _fetchMedications(_selectedPatientId!);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  bool get _hasChanges =>
      _titleCtrl.text.isNotEmpty ||
      _messageCtrl.text != (widget.prefilledMessage ?? '') ||
      _selectedPatientId != widget.prefilledPatientId ||
      _selectedMedication != null;

  Future<void> _fetchPatients() async {
    final results = await Future.wait([
      FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'patient')
          .get(),
      FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'Patient')
          .get(),
    ]);

    final seen     = <String>{};
    final patients = <Map<String, String>>[];
    for (final snap in results) {
      for (final doc in snap.docs) {
        if (!seen.add(doc.id)) continue;
        final d    = doc.data();
        final name = (d['name'] as String?)?.trim().isNotEmpty == true
            ? d['name'] as String
            : (d['username'] as String?) ?? 'Unknown';
        patients.add({'id': doc.id, 'name': name});
      }
    }
    patients.sort((a, b) => a['name']!.compareTo(b['name']!));

    if (mounted) {
      setState(() {
        _patients        = patients;
        _fetchingPatients = false;
      });
    }
  }

  Future<void> _fetchMedications(String patientId) async {
    setState(() {
      _fetchingMedications = true;
      _medications         = [];
      _selectedMedication  = null;
    });
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(patientId)
          .collection('medications')
          .get();
      final names = snap.docs
          .map((d) => (d.data()['name'] as String?) ?? '')
          .where((n) => n.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      if (mounted) {
        setState(() {
          _medications         = names;
          _fetchingMedications = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _fetchingMedications = false);
    }
  }

  Future<void> _handleCancel() async {
    if (!_hasChanges) { Navigator.pop(context); return; }
    final s = S.of(context);

    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text(s.discardChanges,
            style: const TextStyle(fontWeight: FontWeight.w800)),
        content: Text(s.discardMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.keepEditing,
                style: const TextStyle(color: _blue)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.discard),
          ),
        ],
      ),
    );

    if (discard == true && mounted) Navigator.pop(context);
  }

  Future<void> _send() async {
    final s = S.of(context);

    if (_selectedPatientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.pleaseSelectPatient)),
      );
      return;
    }

    final msg = _messageCtrl.text.trim();
    if (msg.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.messageCantBeEmpty)),
      );
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _loading = true);

    try {
      final db    = FirebaseFirestore.instance;
      final now   = FieldValue.serverTimestamp();
      final title = _titleCtrl.text.trim().isNotEmpty
          ? _titleCtrl.text.trim()
          : (widget.isReminder
              ? s.reminderFromDoctor
              : s.messageFromDoctor);

      await db.collection('doctor_messages').add({
        'doctorId':    uid,
        'patientId':   _selectedPatientId,
        'patientName': _selectedPatientName,
        'title':       title,
        'message':     msg,
        if (_selectedMedication != null) 'medication': _selectedMedication,
        'createdAt':   now,
        'type':        widget.isReminder ? 'reminder' : 'message',
      });

      await db
          .collection('users')
          .doc(_selectedPatientId)
          .collection('inbox_notifications')
          .add({
        'type':       'doctor',
        'title':      title,
        'body':       msg,
        if (_selectedMedication != null) 'medication': _selectedMedication,
        'event_time': Timestamp.now(),
        'read':       false,
        'createdAt':  now,
      });

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.messageSentTo(_selectedPatientName ?? '')),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(8, 14, 20, 14),
              color: _blue,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 20),
                    onPressed: _handleCancel,
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        widget.isReminder
                            ? s.sendReminderTitle
                            : s.sendMessageTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 46, height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.12),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Icon(Icons.person_outline,
                        color: Colors.white, size: 24),
                  ),
                ],
              ),
            ),

            // Body
            Expanded(
              child: _fetchingPatients
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildPatientChip(s, isDark),
                          const SizedBox(height: 20),

                          _Label(s.titleLabel, isDark: isDark),
                          const SizedBox(height: 8),
                          _FieldBox(
                            isDark: isDark,
                            child: TextField(
                              controller: _titleCtrl,
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                                hintText: 'e.g. Missed Dose',
                                hintStyle: TextStyle(
                                    color: isDark
                                        ? Colors.white38
                                        : const Color(0xFF94A3B8)),
                              ),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1F2937),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          _Label(s.selectMedOptional, isDark: isDark),
                          const SizedBox(height: 8),
                          _buildMedicationDropdown(s, isDark),
                          const SizedBox(height: 20),

                          _Label(s.messageField, isDark: isDark),
                          const SizedBox(height: 8),
                          _FieldBox(
                            isDark: isDark,
                            child: TextField(
                              controller: _messageCtrl,
                              minLines: 5,
                              maxLines: 10,
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.all(16),
                                hintText:
                                    'Please pay attention to Vitamin D dosage...',
                                hintStyle: TextStyle(
                                    color: isDark
                                        ? Colors.white38
                                        : const Color(0xFF94A3B8)),
                              ),
                              style: TextStyle(
                                fontSize: 15,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1F2937),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),

                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _loading ? null : _handleCancel,
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                        color: isDark
                                            ? Colors.white24
                                            : const Color(0xFFCBD5E1)),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 15),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(14)),
                                  ),
                                  child: Text(
                                    s.cancel,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: isDark
                                          ? Colors.white70
                                          : const Color(0xFF1F2937),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _loading ? null : _send,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _blue,
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor:
                                        _blue.withValues(alpha: 0.5),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 15),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(14)),
                                    elevation: 0,
                                  ),
                                  child: _loading
                                      ? const SizedBox(
                                          width: 20, height: 20,
                                          child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2),
                                        )
                                      : Text(
                                          s.sendBtn,
                                          style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientChip(S s, bool isDark) {
    return GestureDetector(
      onTap: () => _showPatientPicker(s, isDark),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
              color: isDark
                  ? const Color(0xFF3A3A5C)
                  : const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
                blurRadius: 6,
                offset: const Offset(0, 2),
                color: Colors.black
                    .withValues(alpha: isDark ? 0.2 : 0.03)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: _blue.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_outline, color: _blue, size: 16),
            ),
            const SizedBox(width: 8),
            Text(
              _selectedPatientName != null
                  ? s.toPatientName(_selectedPatientName!)
                  : s.selectPatientHint,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _selectedPatientName != null
                    ? (isDark ? Colors.white : const Color(0xFF1F2937))
                    : (isDark ? Colors.white38 : const Color(0xFF94A3B8)),
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.keyboard_arrow_down_rounded,
                color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                size: 18),
          ],
        ),
      ),
    );
  }

  void _showPatientPicker(S s, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _PatientPickerSheet(
        patients:   _patients,
        selectedId: _selectedPatientId,
        onSelect: (id, name) {
          setState(() {
            _selectedPatientId   = id;
            _selectedPatientName = name;
            _selectedMedication  = null;
          });
          _fetchMedications(id);
          Navigator.pop(context);
        },
      ),
    );
  }

  Widget _buildMedicationDropdown(S s, bool isDark) {
    if (_fetchingMedications) {
      return _FieldBox(
        isDark: isDark,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _blue.withValues(alpha: 0.6)),
              ),
              const SizedBox(width: 10),
              Text(s.loadingMedications,
                  style: TextStyle(
                      color: isDark
                          ? Colors.white38
                          : const Color(0xFF94A3B8))),
            ],
          ),
        ),
      );
    }

    return _FieldBox(
      isDark: isDark,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: _selectedMedication,
          isExpanded: true,
          dropdownColor: isDark ? const Color(0xFF1E1E2E) : null,
          hint: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('None',
                style: TextStyle(
                    color: isDark
                        ? Colors.white38
                        : const Color(0xFF94A3B8))),
          ),
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('None',
                    style: TextStyle(
                        color: isDark
                            ? Colors.white38
                            : const Color(0xFF94A3B8))),
              ),
            ),
            ..._medications.map((m) => DropdownMenuItem<String?>(
                  value: m,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(m,
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1F2937))),
                  ),
                )),
          ],
          onChanged: _selectedPatientId == null
              ? null
              : (val) => setState(() => _selectedMedication = val),
        ),
      ),
    );
  }
}

// Patient picker bottom sheet

class _PatientPickerSheet extends StatelessWidget {
  final List<Map<String, String>> patients;
  final String? selectedId;
  final void Function(String id, String name) onSelect;

  const _PatientPickerSheet({
    required this.patients,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        Container(
          width: 40, height: 4,
          decoration: BoxDecoration(
            color: isDark ? Colors.white24 : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 16),
        Text(s.selectPatient,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : null)),
        const SizedBox(height: 8),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: patients.length,
            itemBuilder: (_, i) {
              final p        = patients[i];
              final selected = p['id'] == selectedId;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      const Color(0xFF1E3A8A).withValues(alpha: 0.10),
                  child: Text(
                    p['name']!.isNotEmpty
                        ? p['name']![0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                        color: Color(0xFF1E3A8A),
                        fontWeight: FontWeight.w800),
                  ),
                ),
                title: Text(
                  p['name']!,
                  style: TextStyle(
                      fontWeight:
                          selected ? FontWeight.w800 : FontWeight.w600,
                      color: isDark ? Colors.white : null),
                ),
                trailing: selected
                    ? const Icon(Icons.check, color: Color(0xFF1E3A8A))
                    : null,
                onTap: () => onSelect(p['id']!, p['name']!),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

// Shared widgets

class _Label extends StatelessWidget {
  final String text;
  final bool isDark;
  const _Label(this.text, {required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: isDark ? Colors.white70 : const Color(0xFF334155),
      ),
    );
  }
}

class _FieldBox extends StatelessWidget {
  final Widget child;
  final bool isDark;
  const _FieldBox({required this.child, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isDark
                ? const Color(0xFF3A3A5C)
                : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
              blurRadius: 6,
              offset: const Offset(0, 2),
              color: Colors.black
                  .withValues(alpha: isDark ? 0.2 : 0.03)),
        ],
      ),
      child: child,
    );
  }
}
