// medication_form_screen.dart
import 'package:flutter/material.dart';
import '../../models/medication.dart';
import '../../services/medications_service.dart';

class MedicationFormScreen extends StatefulWidget {
  final String uid;
  final Medication? existing;
  final DateTime effectiveDate;

  const MedicationFormScreen({
    super.key,
    required this.uid,
    this.existing,
    required this.effectiveDate,
  });

  @override
  State<MedicationFormScreen> createState() => _MedicationFormScreenState();
}

class _MedicationFormScreenState extends State<MedicationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = MedicationsService();

  late final TextEditingController _name;
  late final TextEditingController _dosage;
  late final TextEditingController _freq;
  late final TextEditingController _notes;

  bool _isActive = true;
  bool _saving = false;

  final List<TimeOfDay> _times = [];
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 7));


  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _startDate = e?.startDate ?? widget.effectiveDate;
    _endDate = e?.endDate ?? _startDate.add(const Duration(days: 7));

    _name = TextEditingController(text: e?.name ?? '');
    _dosage = TextEditingController(text: e?.dosage ?? '');
    _freq = TextEditingController(text: (e?.frequencyPerDay ?? 1).toString());
    _notes = TextEditingController(text: e?.notes ?? '');
    _isActive = e?.isActive ?? true;

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
    _freq.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDate(DateTime initial) async {
    return showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
  }

  int _compareTime(TimeOfDay a, TimeOfDay b) {
    final aMin = a.hour * 60 + a.minute;
    final bMin = b.hour * 60 + b.minute;
    return aMin.compareTo(bMin);
  }

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

  Future<void> _addTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked == null) return;

    final exists = _times.any((t) => t.hour == picked.hour && t.minute == picked.minute);
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

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<void> _save() async {
    if (_saving) return;

    final okForm = _formKey.currentState?.validate() ?? false;
    if (!okForm) return;

    if (_times.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one time.')),
      );
      return;
    }

    final freq = int.tryParse(_freq.text.trim()) ?? 1;
    final times = _times.map(_formatTime).toList();

    setState(() => _saving = true);
    try {
      if (widget.existing == null) {
        await _service.addMedication(
          uid: widget.uid,
          name: _name.text,
          dosage: _dosage.text,
          frequencyPerDay: freq,
          notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          times: times,
          startDate: _dateOnly(_startDate),
          endDate: _dateOnly(_endDate),
          isActive: _isActive,
        );
      } else {
        await _service.updateMedicationVersioned(
          uid: widget.uid,
          oldMed: widget.existing!,
          effectiveDate: _dateOnly(widget.effectiveDate),
          name: _name.text,
          dosage: _dosage.text,
          frequencyPerDay: freq,
          notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          times: times,
          isActive: _isActive,
          newEndDate: _dateOnly(_endDate),
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.existing == null ? 'Medication created ✅' : 'Medication updated ✅'),
        ),
      );

      await Future.delayed(const Duration(milliseconds: 350));
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

  InputDecoration _inputDecoration(String label, {String? hint, Widget? prefixIcon}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: prefixIcon,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final canEditeStart = !isEdit;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Medication' : 'Add Medication'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Card(
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _name,
                        decoration: _inputDecoration('Medication name', prefixIcon: const Icon(Icons.medication)),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _dosage,
                        decoration: _inputDecoration('Dosage', hint: 'e.g., 500mg'),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _freq,
                        keyboardType: TextInputType.number,
                        decoration: _inputDecoration('Times per day'),
                        validator: (v) {
                          final n = int.tryParse((v ?? '').trim());
                          if (n == null || n <= 0 || n > 24) return 'Enter 1..24';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Medication times',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final t in _times)
                            InputChip(
                              label: Text(_formatTime(t)),
                              onDeleted: () => _removeTime(t),
                              deleteIcon: const Icon(Icons.close),
                            ),
                          ActionChip(
                            label: const Text('Add time'),
                            avatar: const Icon(Icons.add),
                            onPressed: _addTime,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _times.isEmpty ? 'No times selected' : 'Selected: ${_times.map(_formatTime).join(', ')}',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
              ),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Treatment period',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: canEditeStart ? () async {
                                final d = await _pickDate(_startDate);
                                if (d == null) return;
                                setState(() {
                                  _startDate = DateTime(d.year, d.month, d.day);
                                  if (_endDate.isBefore(_startDate)) _endDate = _startDate;
                                  }); 
                              }: null,

                              icon: const Icon(Icons.calendar_today_outlined),
                              label: Text('Start: ${_startDate.toString().substring(0, 10)}'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final d = await _pickDate(_endDate);
                                if (d == null) return;
                                setState(() {
                                  _endDate = DateTime(d.year, d.month, d.day);
                                  if (_endDate.isBefore(_startDate)) {
                                    _endDate = _startDate;
                                  }
                                });
                              },
                              icon: const Icon(Icons.event_available_outlined),
                              label: Text('End: ${_endDate.toString().substring(0, 10)}'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'The reminder will run only between these dates.',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),
              Card(
                elevation: 1,
                child: ExpansionTile(
                  title: const Text('Notes (optional)'),
                  childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  children: [
                    TextFormField(
                      controller: _notes,
                      maxLines: 3,
                      decoration: _inputDecoration('Notes'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (isEdit)
                Card(
                  elevation: 1,
                  child: SwitchListTile(
                    title: const Text('Active'),
                    value: _isActive,
                    onChanged: (v) => setState(() => _isActive = v),
                  ),
                ),
              const SizedBox(height: 90),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(isEdit ? 'Update' : 'Create'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}