// medication_form_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../models/medication.dart';
import '../../services/medications_service.dart';

enum MedicationFormSource { medicationsList, home }

class MedicationFormScreen extends StatefulWidget {
  final String uid;
  final Medication? existing;
  final DateTime effectiveDate;
  final MedicationFormSource source;

  const MedicationFormScreen({
    super.key,
    required this.uid,
    this.existing,
    required this.effectiveDate,
    this.source = MedicationFormSource.medicationsList,
  });

  @override
  State<MedicationFormScreen> createState() => _MedicationFormScreenState();
}

class _MedicationFormScreenState extends State<MedicationFormScreen> {
  final _service = MedicationsService();

  late final TextEditingController _name;
  late final TextEditingController _dosage;
  late final TextEditingController _notes;

  bool _saving          = false;
  bool _reminderEnabled = true;

  static const List<String> _weekLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
  static const List<String> _weekKeys   = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  late Set<String> _selectedDays;

  final List<TimeOfDay> _times = [];

  static const Color _dark   = Color(0xFF0B1738);
  static const Color _accent = Color(0xFF1E3A8A);
  static const Color _bg     = Color(0xFFF3F6FB);
  static const Color _red    = Color(0xFFDC2626);

  bool get _hasData {
    return _name.text.trim().isNotEmpty ||
        _dosage.text.trim().isNotEmpty ||
        _times.isNotEmpty ||
        _notes.text.trim().isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    final e = widget.existing;

    _name   = TextEditingController(text: e?.name   ?? '');
    _dosage = TextEditingController(text: e?.dosage ?? '');
    _notes  = TextEditingController(text: e?.notes  ?? '');

    _reminderEnabled = e?.reminderEnabled ?? true;

    _selectedDays = e != null
        ? Set<String>.from(e.repeatDays)
        : Set<String>.from(Medication.allDays);

    final existingTimes = e?.times ?? const <String>[];
    for (final t in existingTimes) {
      final parsed = _parseTime(t);
      if (parsed != null) _times.add(parsed);
    }
    _times.sort(_compareTime);
  }

  @override
  void dispose() {
    _name.dispose();
    _dosage.dispose();
    _notes.dispose();
    super.dispose();
  }

  // Time helpers

  int _compareTime(TimeOfDay a, TimeOfDay b) =>
      (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute);

  String _formatTime(TimeOfDay t) {
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  TimeOfDay? _parseTime(String s) {
    final parts = s.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    if (h < 0 || h > 23 || m < 0 || m > 59) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  // iOS-style time picker

  Future<void> _addTime() async {
    TimeOfDay picked = TimeOfDay.now();

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return SizedBox(
          height: 320,
          child: Column(
            children: [
              // Handle
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel',
                          style: TextStyle(color: Colors.grey, fontSize: 16)),
                    ),
                    const Expanded(
                      child: Center(
                        child: Text('Select Time',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 17)),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text('Add',
                          style: TextStyle(
                              color: _accent,
                              fontWeight: FontWeight.w700,
                              fontSize: 16)),
                    ),
                  ],
                ),
              ),
              // CupertinoDatePicker (time mode)
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  use24hFormat: true,
                  initialDateTime: DateTime(
                    2000, 1, 1,
                    TimeOfDay.now().hour,
                    TimeOfDay.now().minute,
                  ),
                  onDateTimeChanged: (dt) {
                    picked = TimeOfDay(hour: dt.hour, minute: dt.minute);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    if (confirmed != true) return;

    final exists =
        _times.any((t) => t.hour == picked.hour && t.minute == picked.minute);
    if (exists) return;

    setState(() {
      _times.add(picked);
      _times.sort(_compareTime);
    });
  }

  void _removeTime(TimeOfDay t) {
    setState(() {
      _times.removeWhere((x) => x.hour == t.hour && x.minute == t.minute);
    });
  }

  // Back / Discard dialog

  Future<void> _handleBack() async {
    final isEdit = widget.existing != null;

    if (!isEdit && !_hasData) {
      _pop();
      return;
    }

    final discard = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Discard changes?',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text(
            'Any information you have entered will not be saved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:
                const Text('Keep editing', style: TextStyle(color: _accent)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    if (discard == true) _pop();
  }

  void _pop() {
    Navigator.pop(context);
  }

  // Delete (Edit mode only)

  Future<void> _handleDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete medication?',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text(
            'Are you sure you want to delete "${widget.existing!.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:
                const Text('Cancel', style: TextStyle(color: _accent)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await _service.deleteMedicationForFuture(
        uid: widget.uid,
        med: widget.existing!,
        effectiveDate: widget.effectiveDate,
      );
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }

  // Save

  Future<void> _save() async {
    if (_saving) return;

    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the medication name.')),
      );
      return;
    }

    if (_dosage.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the dose.')),
      );
      return;
    }

    if (_times.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one time.')),
      );
      return;
    }

    final times      = _times.map(_formatTime).toList();
    final repeatDays = _selectedDays.isEmpty
        ? List<String>.from(Medication.allDays)
        : _weekKeys.where((k) => _selectedDays.contains(k)).toList();

    setState(() => _saving = true);
    try {
      if (widget.existing == null) {
        await _service.addMedication(
          uid: widget.uid,
          name: _name.text,
          dosage: _dosage.text,
          frequencyPerDay: _times.length,
          notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          times: times,
          startDate: widget.effectiveDate,
          endDate: null,
          repeatDays: repeatDays,
          reminderEnabled: _reminderEnabled,
        );
      } else {
        await _service.updateMedicationVersioned(
          uid: widget.uid,
          oldMed: widget.existing!,
          effectiveDate: widget.effectiveDate,
          name: _name.text,
          dosage: _dosage.text,
          frequencyPerDay: _times.length,
          notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          times: times,
          newEndDate: widget.existing!.endDate,
          repeatDays: repeatDays,
          reminderEnabled: _reminderEnabled,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.existing == null
              ? 'Medication added ✅'
              : 'Medication updated ✅'),
        ),
      );

      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // UI helpers

  InputDecoration _fieldDecoration(String hint, {Widget? prefix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
      prefixIcon: prefix,
      filled: true,
      fillColor: Colors.white,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _accent, width: 1.5),
      ),
    );
  }

  Widget _sectionLabel(String text, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: _dark),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _dark,
            ),
          ),
        ],
      ),
    );
  }

  // Build

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;

    return Scaffold(
      backgroundColor: _bg,

      // Custom Header
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(90),
        child: SafeArea(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            decoration: const BoxDecoration(color: _accent),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                
                GestureDetector(
                  onTap: _handleBack,
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),

                Expanded(
                  child: Center(
                    child: Text(
                      isEdit ? 'Edit Medication' : 'Add Medication',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                // Profile Icon
                InkWell(
                  borderRadius: BorderRadius.circular(28),
                  onTap: () {},
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: .12),
                      border: Border.all(color: Colors.white24, width: 1),
                    ),
                    child: const Icon(Icons.person_outline,
                        color: Colors.white, size: 28),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),

      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // Medication Name
                  _sectionLabel('Medication Name',
                      icon: Icons.medication_outlined),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _name,
                          decoration: _fieldDecoration('Insulin'),
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                      ),
                      // Delete button — Edit mode
                      if (isEdit) ...[
                        const SizedBox(width: 10),
                        TextButton.icon(
                          onPressed: _handleDelete,
                          style: TextButton.styleFrom(
                            backgroundColor: _red,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                          ),
                          icon: const Icon(Icons.delete_outline, size: 16),
                          label: const Text('Delete',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 13)),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Dose
                  _sectionLabel('Dose', icon: Icons.colorize_outlined),
                  TextField(
                    controller: _dosage,
                    decoration: _fieldDecoration('500mg'),
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15),
                  ),

                  const SizedBox(height: 20),

                  // Time
                  _sectionLabel('Time', icon: Icons.access_time_rounded),
                  _buildTimeSection(),

                  const SizedBox(height: 20),

                  // Repeat
                  _sectionLabel('Repeat'),
                  _buildRepeatSection(),

                  const SizedBox(height: 20),

                  // Enable Reminder
                  _buildReminderToggle(),

                  const SizedBox(height: 20),

                  // Note
                  _sectionLabel('Note', icon: Icons.notes_outlined),
                  TextField(
                    controller: _notes,
                    maxLines: 3,
                    decoration: _fieldDecoration('15 minuts Before Meal'),
                    style: const TextStyle(fontSize: 15),
                  ),
                ],
              ),
            ),
          ),

          // Bottom buttons
          _buildBottomBar(isEdit),
        ],
      ),
    );
  }

  // Time section

  Widget _buildTimeSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          if (_times.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _times.map((t) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: _dark,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(t),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => _removeTime(t),
                        child: const Icon(Icons.close,
                            color: Colors.white70, size: 16),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
          ],


          GestureDetector(
            onTap: _addTime,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: _bg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300, width: 1),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_circle_outline, color: _accent, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    _times.isEmpty ? 'Add Time' : 'Add Another Time',
                    style: const TextStyle(
                      color: _accent,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Repeat section

  Widget _buildRepeatSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        final key      = _weekKeys[i];
        final label    = _weekLabels[i];
        final selected = _selectedDays.contains(key);

        return GestureDetector(
          onTap: () {
            setState(() {
              if (selected) {

                if (_selectedDays.length > 1) {
                  _selectedDays.remove(key);
                }
              } else {
                _selectedDays.add(key);
              }
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? _dark : Colors.white,
              border: Border.all(
                color: selected ? _dark : Colors.grey.shade300,
                width: 1.5,
              ),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.grey.shade600,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  // Enable Reminder toggle

  Widget _buildReminderToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications_outlined, size: 20, color: _dark),
          const SizedBox(width: 10),
          const Text(
            'Enable Reminder',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: _dark,
            ),
          ),
          const Spacer(),
          Switch(
            value: _reminderEnabled,
            onChanged: (v) => setState(() => _reminderEnabled = v),
            activeThumbColor: Colors.white,
            activeTrackColor: const Color(0xFF16A34A),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Colors.grey.shade300,
          ),
        ],
      ),
    );
  }

  // Bottom bar

  Widget _buildBottomBar(bool isEdit) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      child: Row(
        children: [
          // Cancel
          Expanded(
            child: OutlinedButton(
              onPressed: _saving ? null : _handleBack,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: _dark,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Save / Add
          Expanded(
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: _dark,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      isEdit ? 'Save' : 'Add',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}