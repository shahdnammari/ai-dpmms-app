import 'dart:async';
import 'dart:ui';
import 'package:ai_dpmms_mobile/services/app_refresh.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
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
    _refreshListener = () {
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
      case 'doctor':  return Icons.medical_information_outlined;
      case 'ai':      return Icons.auto_awesome;
      default:        return Icons.medication_outlined;
    }
  }

  String _timeAgo(DateTime dt, S s) {
    final now  = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1)  return s.justNow;
    if (diff.inMinutes < 60) return s.minsAgo(diff.inMinutes);
    if (diff.inHours < 24)   return s.hoursAgo(diff.inHours);
    if (diff.inDays == 1)    return s.yesterday;
    if (diff.inDays < 7)     return s.daysAgo(diff.inDays);
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final s   = S.of(context);
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final bg      = Theme.of(context).scaffoldBackgroundColor;
    final surface = Theme.of(context).colorScheme.surface;

    if (uid == null) {
      return Scaffold(
        body: Center(child: Text(s.notSignedIn)),
      );
    }

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _query(uid).snapshots(),
          builder: (context, snap) {
            if (snap.hasError) {
              return Center(
                child: Text('Error: ${snap.error}',
                    style: const TextStyle(color: Colors.red)),
              );
            }
            if (!snap.hasData) {
              return const _SkeletonNotifications();
            }

            final docs = snap.data!.docs;
            final now  = DateTime.now();

            final filtered = docs.where((d) {
              final ts = d.data()['event_time'] as Timestamp?;
              if (ts == null) return false;
              return !ts.toDate().isAfter(now);
            }).toList();

            if (filtered.isEmpty) {
              return Center(
                child: Text(
                  s.noNotifications,
                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
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
                  final d    = filtered[i];
                  final data = d.data();

                  final type          = (data['type'] ?? 'med') as String;
                  final title         = (data['title'] ?? '') as String;
                  final body          = (data['body'] ?? '') as String;
                  final read          = (data['read'] ?? false) as bool;
                  final ts            = data['event_time'] as Timestamp?;
                  final dt            = ts?.toDate();
                  final medId         = data['medication_id'] as String?;
                  final medName       = (data['medication_name'] as String?) ?? '';
                  final scheduledTime =
                      (data['scheduled_time'] as String?) ?? '--:--';

                  final displayTitle = type == 'med'
                      ? (medName.isNotEmpty ? s.timeToTake(medName) : s.medReminder)
                      : (title.isEmpty ? s.doctorMessage : title);

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
                        color: surface,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                            color: Colors.black
                                .withValues(alpha: isDark ? 0.2 : 0.04),
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
                            child: Icon(_iconForType(type),
                                color: const Color(0xFF1E3A8A), size: 20),
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
                                        displayTitle,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface,
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
                                            _timeAgo(dt, s),
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
                                      ? s.scheduledAt(scheduledTime)
                                      : body,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF64748B),
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
    );
  }

  void _showNotificationDetails({
    required String uid,
    required String notificationId,
    required Map<String, dynamic> data,
    required String? medId,
    required String scheduledTime,
  }) async {
    final s     = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final onSheet = isDark ? Colors.white : const Color(0xFF0F172A);

    final type  = (data['type'] ?? 'med') as String;
    final title = (data['title'] ?? '') as String;
    final body  = (data['body'] ?? '') as String;
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
            decoration: BoxDecoration(
              color: sheetBg,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(26)),
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
                        color: Colors.grey.shade400,
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
                          return const _SkeletonMedDetail();
                        }
                        final med = snap.data;
                        if (med == null) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _detailRow(
                                  Icons.medication_outlined,
                                  title.isNotEmpty ? title : s.medReminder,
                                  onSheet),
                              if (body.isNotEmpty) ...[
                                const SizedBox(height: 20),
                                _detailRow(Icons.info_outline, body, onSheet),
                              ],
                              const SizedBox(height: 32),
                              SizedBox(
                                width: double.infinity,
                                child: _closeBtn(s, onSheet,
                                    () => Navigator.pop(context)),
                              ),
                            ],
                          );
                        }

                        final medName = (med['name'] ?? '') as String;
                        final dosage  = (med['dosage'] ?? '') as String;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _detailRow(Icons.medication_outlined,
                                s.timeToTake(medName), onSheet),
                            const SizedBox(height: 20),
                            _detailRow(
                                Icons.local_pharmacy_outlined, dosage, onSheet),
                            const SizedBox(height: 20),
                            _detailRow(
                                Icons.access_time_outlined, scheduledTime, onSheet),
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
                                              BorderRadius.circular(12)),
                                    ),
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _goToMedicationDetails(med);
                                    },
                                    child: Text(s.viewMedication,
                                        style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _closeBtn(
                                      s, onSheet, () => Navigator.pop(context)),
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
                        Text(title,
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: onSheet)),
                        const SizedBox(height: 12),
                        Text(body,
                            style: TextStyle(
                                fontSize: 14,
                                color: onSheet.withValues(alpha: 0.6),
                                fontWeight: FontWeight.w500)),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          child: _closeBtn(
                              s, onSheet, () => Navigator.pop(context)),
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

  Widget _detailRow(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, size: 24, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: color)),
        ),
      ],
    );
  }

  Widget _closeBtn(S s, Color color, VoidCallback onPressed) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color, width: 2),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: onPressed,
      child: Text(s.close,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
    );
  }

  Future<Map<String, dynamic>?> _fetchMedicationDetails(
      String uid, String medDocId) async {
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
}

// Skeleton loading

class _SkeletonNotifications extends StatefulWidget {
  const _SkeletonNotifications();

  @override
  State<_SkeletonNotifications> createState() => _SkeletonNotificationsState();
}

class _SkeletonNotificationsState extends State<_SkeletonNotifications>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _opacity = Tween(begin: 0.4, end: 0.85).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _box({double? width, required double height, double radius = 10}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A4A) : const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E2E) : Colors.white;

    return AnimatedBuilder(
      animation: _opacity,
      builder: (_, _) => Opacity(
        opacity: _opacity.value,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          itemCount: 5,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (_, _) => Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF2A2A4A)
                        : const Color(0xFFE2E8F0),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: _box(height: 13, radius: 7)),
                          const SizedBox(width: 12),
                          _box(width: 44, height: 10, radius: 5),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _box(height: 10, width: 200, radius: 6),
                      const SizedBox(height: 5),
                      _box(height: 10, width: 140, radius: 6),
                    ],
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

class _SkeletonMedDetail extends StatefulWidget {
  const _SkeletonMedDetail();

  @override
  State<_SkeletonMedDetail> createState() => _SkeletonMedDetailState();
}

class _SkeletonMedDetailState extends State<_SkeletonMedDetail>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _opacity = Tween(begin: 0.4, end: 0.85).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _box({double? width, required double height, double radius = 8}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A4A) : const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _opacity,
      builder: (_, _) => Opacity(
        opacity: _opacity.value,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(
            3,
            (_) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF2A2A4A)
                          : const Color(0xFFE2E8F0),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _box(height: 12, width: 140, radius: 6),
                        const SizedBox(height: 6),
                        _box(height: 10, width: 90, radius: 5),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
