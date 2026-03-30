import 'dart:async';
import 'dart:ui';
import 'package:ai_dpmms_mobile/services/app_refresh.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/medication.dart';
import 'medication_details_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => NotificationsScreenState();
}

class NotificationsScreenState extends State<NotificationsScreen> {
  Timer? _ticker;
  VoidCallback? _refreshListener;

  @override
  void initState() {
    super.initState();
    
    _refreshListener = (){
      if (mounted) setState(() {});
    };

    AppRefresh.notifier.addListener(_refreshListener!);
    
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();

    if (_refreshListener != null) {
      AppRefresh.notifier.removeListener(_refreshListener!);
    }

    super.dispose();
  }

  Query<Map<String, dynamic>> _query(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('inbox_notifications')
        .orderBy('event_time', descending: true);
  }

  Future<void> _markRead(String uid, String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('inbox_notifications')
          .doc(docId)
          .update({'read': true});
    } catch (e) {
      rethrow;
    }

    AppRefresh.trigger();
  }

  Future<void> _onRefresh() async {
    AppRefresh.trigger();
    await Future.delayed(const Duration(milliseconds: 400));
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'doctor':
        return Icons.medical_information_outlined;
      case 'ai':
        return Icons.auto_awesome;
      default:
        return Icons.medication_outlined;
    }
  }

  String _timeAgo(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    const bg = Color(0xFFF3F6FB);

    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('Not signed in')),
      );
    }

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Container(
                color: bg,
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _query(uid).snapshots(),
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return Center(
                        child: Text(
                          'Error: ${snap.error}',
                          style: const TextStyle(color: Colors.red),
                        ),
                      );
                    }

                    if (!snap.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    final docs = snap.data!.docs;
                    final now = DateTime.now();

                    final filtered = docs.where((d) {
                      final data = d.data();
                      final ts = data['event_time'] as Timestamp?;
                      if (ts == null) return false;

                      final eventTime = ts.toDate();

                      // show only notifications whose time already arrived
                      return !eventTime.isAfter(now);
                    }).toList();

                    if (filtered.isEmpty) {
                      return Center(
                        child: Text(
                          'No notifications yet.',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: _onRefresh,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          final d = filtered[i];
                          final data = d.data();

                          final type = (data['type'] ?? 'med') as String;
                          final title = (data['title'] ?? '') as String;
                          final body = (data['body'] ?? '') as String;
                          final read = (data['read'] ?? false) as bool;
                          final ts = data['event_time'] as Timestamp?;
                          final dt = ts?.toDate();
                          final medId = data['medication_id'] as String?;
                          final scheduledTime =
                              (data['scheduled_time'] as String?) ?? '--:--';

                          return InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () async {
                              await _markRead(uid, d.id);

                              if (!mounted) return;

                              _showNotificationDetails(
                                uid: uid,
                                notificationId: d.id,
                                data: data,
                                medId: medId,
                                scheduledTime: scheduledTime,
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                    color: Colors.black.withValues(alpha: 0.04),
                                  ),
                                ],
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor:
                                        const Color(0xFF1E3A8A).withValues(alpha: 0.12),
                                    child: Icon(
                                      _iconForType(type),
                                      color: const Color(0xFF1E3A8A),
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                title.isEmpty
                                                    ? (type == 'doctor'
                                                        ? 'Doctor message'
                                                        : 'Medication reminder')
                                                    : title,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 15,
                                                  color: Color(0xFF0F172A),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                if (dt != null)
                                                  Text(
                                                    _timeAgo(dt),
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.grey.shade500,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                const SizedBox(height: 4),
                                                if (!read)
                                                  Container(
                                                    width: 8,
                                                    height: 8,
                                                    decoration: const BoxDecoration(
                                                      color: Color(0xFFDC2626),
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          type == 'med'
                                              ? 'Scheduled at $scheduledTime'
                                              : body,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade600,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNotificationDetails({
    required String uid,
    required String notificationId,
    required Map<String, dynamic> data,
    required String? medId,
    required String scheduledTime,
  }) async {
    final type = (data['type'] ?? 'med') as String;
    final title = (data['title'] ?? '') as String;
    final body = (data['body'] ?? '') as String;
    final isMed = type == 'med';

    Future<Map<String, dynamic>?>? medFuture;
    if (isMed && medId != null) {
      medFuture = _fetchMedicationDetails(uid, medId);
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      isScrollControlled: true,
      builder: (_) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(26),
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (isMed && medFuture != null)
                    FutureBuilder<Map<String, dynamic>?>(
                      future: medFuture,
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          );
                        }

                        final med = snap.data;

                        if (med == null) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildDetailRowWithIcon(
                                Icons.medication_outlined,
                                title.isNotEmpty
                                    ? title
                                    : 'Medication Reminder',
                              ),
                              if (body.isNotEmpty) ...[
                                const SizedBox(height: 20),
                                _buildDetailRowWithIcon(
                                  Icons.info_outline,
                                  body,
                                ),
                              ],
                              const SizedBox(height: 32),
                              SizedBox(
                                width: double.infinity,
                                child: _closeButton(() {
                                  Navigator.pop(context);
                                }),
                              ),
                            ],
                          );
                        }

                        final medName = (med['name'] ?? '') as String;
                        final dosage = (med['dosage'] ?? '') as String;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildDetailRowWithIcon(
                              Icons.medication_outlined,
                              'Time to take $medName',
                            ),
                            const SizedBox(height: 20),
                            _buildDetailRowWithIcon(
                              Icons.local_pharmacy_outlined,
                              dosage,
                            ),
                            const SizedBox(height: 20),
                            _buildDetailRowWithIcon(
                              Icons.access_time_outlined,
                              scheduledTime,
                            ),
                            const SizedBox(height: 32),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0F172A),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                    ),
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _goToMedicationDetails(med);
                                    },
                                    child: const Text(
                                      'View Medication',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _closeButton(() {
                                    Navigator.pop(context);
                                  }),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          body,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          child: _closeButton(() {
                            Navigator.pop(context);
                          }),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<Map<String, dynamic>?> _fetchMedicationDetails(
    String uid,
    String medDocId,
  ) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('medications')
          .doc(medDocId)
          .get();

      return snap.data();
    } catch (e) {
      return null;
    }
  }

  void _goToMedicationDetails(Map<String, dynamic> medData) {
    final med = Medication(
      id: medData['id'] ?? '',
      groupId: medData['groupId'] ?? '',
      name: (medData['name'] ?? '') as String,
      dosage: (medData['dosage'] ?? '') as String,
      frequencyPerDay: (medData['frequencyPerDay'] ?? 1) as int,
      notes: medData['notes'] as String?,
      startDate:
          (medData['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (medData['endDate'] as Timestamp?)?.toDate(),
      times: ((medData['times'] as List?)?.cast<String>() ?? []),
      repeatDays: ((medData['repeatDays'] as List?)?.cast<String>() ??
          Medication.allDays),
      reminderEnabled: (medData['reminderEnabled'] ?? true) as bool,
    );

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        pageBuilder: (_, _, _) => MedicationDetailsScreen(
          medication: med,
          uid: FirebaseAuth.instance.currentUser!.uid,
          effectiveDate: DateTime.now(),
        ),
      ),
    );
  }

  Widget _closeButton(VoidCallback onPressed) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF0F172A),
        side: const BorderSide(color: Color(0xFF0F172A), width: 2),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      onPressed: onPressed,
      child: const Text(
        'Close',
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildDetailRowWithIcon(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 24, color: const Color(0xFF0F172A)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }
}