import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/medication.dart';
import '../../services/medications_service.dart';
import 'medication_form_screen.dart';

class MedicationsListScreen extends StatelessWidget {
  MedicationsListScreen({super.key});

  final _service = MedicationsService();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not logged in')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My Medications')),
      floatingActionButton: SizedBox(
        height: 64,
        width: 64,
        child: FloatingActionButton(
            onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => MedicationFormScreen(uid: user.uid)),
            );
          },
          child: const Icon(Icons.add),
        ),
      ),
      body: StreamBuilder<List<Medication>>(
        stream: _service.watchMedications(user.uid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }

          final meds = snap.data ?? [];
          if (meds.isEmpty) {
            return const Center(child: Text('No medications yet. Tap + to add.'));
          }

          return ListView.separated(
            itemCount: meds.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final m = meds[i];
              return ListTile(
                title: Text(m.name),
                subtitle: Text('${m.dosage} • ${m.frequencyPerDay} / day'),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'edit') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MedicationFormScreen(uid: user.uid, existing: m),
                        ),
                      );
                    } else if (value == 'delete') {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Delete medication?'),
                          content: Text('Delete "${m.name}"?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                          ],
                        ),
                      );
                      if (ok == true) {
                        await _service.deleteMedication(uid: user.uid, medId: m.id);
                      }
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
