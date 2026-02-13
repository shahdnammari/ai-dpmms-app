import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/medication.dart';
import '../../services/medications_service.dart';

class PatientHomeTab extends StatefulWidget {
  const PatientHomeTab({super.key});

  @override
  State<PatientHomeTab> createState() => _PatientHomeTabState();
}

class _PatientHomeTabState extends State<PatientHomeTab> {
  final _service = MedicationsService();

  String _formatToday() {
    final now = DateTime.now();
    const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${days[now.weekday % 7]}, ${now.day} ${months[now.month - 1]} ${now.year}';
  }

  void _onMenuSelected(String v) {
    if (v == 'settings') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings (soon)')));
    } else if (v == 'emergency') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Emergency (soon)')));
    } else if (v == 'help') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Help / About (soon)')));
    }
  }


  String _dayId() {
    final now = DateTime.now();
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    return '${now.year}-$mm-$dd'; // yyyy-MM-dd
  }

  DocumentReference<Map<String, dynamic>> _todayDoc(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('daily_intake')
        .doc(_dayId());
  }

  Stream<Set<String>> _watchCheckedIds(String uid) {
    return _todayDoc(uid).snapshots().map((doc) {
      final data = doc.data();
      final list = (data?['checkedMedIds'] as List?) ?? [];
      return list.map((e) => e.toString()).toSet();
    });
  }

  Future<void> _toggleChecked(String uid, String medId, bool checked) async {
    final ref = _todayDoc(uid);

    if (checked) {
      await ref.set({
        'checkedMedIds': FieldValue.arrayUnion([medId]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } else {
      await ref.set({
        'checkedMedIds': FieldValue.arrayRemove([medId]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(
        title: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
          builder: (context, snap) {
            final data = snap.data?.data();
            final username =
                (data?['username'] as String?) ??
                (data?['displayName'] as String?) ??
                (user.email?.split('@').first ?? 'Patient');

            return Text('Welcome $username');
          },
        ),

        actions: [
        IconButton(
          icon: const Icon(Icons.logout),
          onPressed: () async {
            await FirebaseAuth.instance.signOut();
          },
        ),
      ],
        // ✅ ما في actions هون (التاريخ وال⋮ تحت الويلكم)
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<List<Medication>>(
          stream: _service.watchMedications(user.uid),
          builder: (context, medsSnap) {
            if (medsSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (medsSnap.hasError) return Center(child: Text('Error: ${medsSnap.error}'));

            final meds = (medsSnap.data ?? []).where((m) => m.isActive).toList();

            return StreamBuilder<Set<String>>(
              stream: _watchCheckedIds(user.uid),
              builder: (context, checkedSnap) {
                final checkedIds = checkedSnap.data ?? <String>{};

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatToday(),
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        PopupMenuButton<String>(
                          onSelected: _onMenuSelected,
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'settings', child: Text('Settings')),
                            PopupMenuItem(value: 'emergency', child: Text('Emergency')),
                            PopupMenuItem(value: 'help', child: Text('Help / About')),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'Checklist for Today',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),

                    if (meds.isEmpty)
                      const Expanded(
                        child: Center(child: Text('No active medications yet. Use + to add.')),
                      )
                    else
                      Expanded(
                        child: ListView.builder(
                          itemCount: meds.length,
                          itemBuilder: (context, i) {
                            final m = meds[i];

                            // ✅ بدل _checked المحلي
                            final checked = checkedIds.contains(m.id);

                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              child: Card(
                                elevation: checked ? 3 : 1,
                                child: CheckboxListTile(
                                  value: checked,

                                  // ✅ حفظ في Firestore
                                  onChanged: (v) {
                                    _toggleChecked(user.uid, m.id, v ?? false);
                                  },

                                  controlAffinity: ListTileControlAffinity.leading,
                                  title: Text(
                                    m.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      decoration: checked ? TextDecoration.lineThrough : null,
                                      color: checked ? Colors.green : null,
                                    ),
                                  ),
                                  subtitle: Text('${m.dosage} • ${m.frequencyPerDay} / day'),
                                  secondary: checked
                                      ? const Icon(Icons.check_circle, color: Colors.green)
                                      : const Icon(Icons.medication_outlined),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
