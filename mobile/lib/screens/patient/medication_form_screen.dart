import 'package:flutter/material.dart';
import '../../models/medication.dart';
import '../../services/medications_service.dart';

class MedicationFormScreen extends StatefulWidget {
  final String uid;
  final Medication? existing;

  const MedicationFormScreen({
    super.key,
    required this.uid,
    this.existing,
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

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _dosage = TextEditingController(text: e?.dosage ?? '');
    _freq = TextEditingController(text: (e?.frequencyPerDay ?? 1).toString());
    _notes = TextEditingController(text: e?.notes ?? '');
    _isActive = e?.isActive ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _dosage.dispose();
    _freq.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final freq = int.tryParse(_freq.text.trim()) ?? 1;

    setState(() => _saving = true);
    try {
      if (widget.existing == null) {
        await _service.addMedication(
          uid: widget.uid,
          name: _name.text,
          dosage: _dosage.text,
          frequencyPerDay: freq,
          notes: _notes.text.isEmpty ? null : _notes.text,
        );
      } else {
        await _service.updateMedication(
          uid: widget.uid,
          medId: widget.existing!.id,
          name: _name.text,
          dosage: _dosage.text,
          frequencyPerDay: freq,
          notes: _notes.text.isEmpty ? null : _notes.text,
          isActive: _isActive,
        );
      }
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

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;

    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit Medication' : 'Add Medication')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Medication name'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _dosage,
                decoration: const InputDecoration(labelText: 'Dosage (e.g., 500mg)'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _freq,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Times per day'),
                validator: (v) {
                  final n = int.tryParse((v ?? '').trim());
                  if (n == null || n <= 0 || n > 24) return 'Enter 1..24';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notes,
                decoration: const InputDecoration(labelText: 'Notes (optional)'),
                maxLines: 3,
              ),
              const SizedBox(height: 12),

              if (isEdit)
                SwitchListTile(
                  title: const Text('Active'),
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                ),

              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(isEdit ? 'Update' : 'Create'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
