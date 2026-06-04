import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_strings.dart';
import 'send_message_screen.dart';

// Kind

enum _NotifKind { sent, system }

// Model

class _NotifItem {
  final String id;
  final _NotifKind kind;
  final String toName;
  final String? toPatientId;
  final String body;
  final DateTime createdAt;

  const _NotifItem({
    required this.id,
    required this.kind,
    required this.toName,
    this.toPatientId,
    required this.body,
    required this.createdAt,
  });
}

// Filter

enum _Filter { all, sent, system }

// Tab

class DoctorNotificationsTab extends StatefulWidget {
  const DoctorNotificationsTab({super.key});

  @override
  State<DoctorNotificationsTab> createState() => _DoctorNotificationsTabState();
}

class _DoctorNotificationsTabState extends State<DoctorNotificationsTab> {
  _Filter _filter = _Filter.all;

  List<_NotifItem> _alertItems = [];
  List<_NotifItem> _messageItems = [];
  List<_NotifItem> _allItems = [];

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _alertsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _messagesSub;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  void _subscribe() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _alertsSub = FirebaseFirestore.instance
        .collection('alerts')
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      setState(() {
        _alertItems = snap.docs.map((doc) {
          final d = doc.data();
          final ts = d['createdAt'];
          final patientName = (d['patientName'] as String?) ?? 'Unknown';
          final alertType = (d['type'] as String?) ?? 'Alert';
          return _NotifItem(
            id: doc.id,
            kind: _NotifKind.system,
            toName: patientName,
            toPatientId: d['patientId'] as String?,
            body: alertType,
            createdAt: ts is Timestamp ? ts.toDate() : DateTime.now(),
          );
        }).toList();
        _merge();
      });
    });

    _messagesSub = FirebaseFirestore.instance
        .collection('doctor_messages')
        .where('doctorId', isEqualTo: uid)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      setState(() {
        _messageItems = snap.docs.map((doc) {
          final d = doc.data();
          final ts = d['createdAt'];
          return _NotifItem(
            id: doc.id,
            kind: _NotifKind.sent,
            toName: (d['patientName'] as String?) ?? 'Patient',
            toPatientId: d['patientId'] as String?,
            body: (d['message'] as String?) ?? '',
            createdAt: ts is Timestamp ? ts.toDate() : DateTime.now(),
          );
        }).toList();
        _merge();
      });
    });
  }

  void _merge() {
    _allItems = [..._alertItems, ..._messageItems]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  void dispose() {
    _alertsSub?.cancel();
    _messagesSub?.cancel();
    super.dispose();
  }

  List<_NotifItem> get _filtered {
    return switch (_filter) {
      _Filter.all    => _allItems,
      _Filter.sent   => _allItems.where((i) => i.kind == _NotifKind.sent).toList(),
      _Filter.system => _allItems.where((i) => i.kind == _NotifKind.system).toList(),
    };
  }

  static String _timeLabel(DateTime dt, S s) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1)  return s.justNow;
    if (diff.inMinutes < 60) return s.minsAgo(diff.inMinutes);
    if (diff.inHours < 24)   return s.hoursAgo(diff.inHours);
    if (diff.inDays == 1)    return s.yesterday;
    return DateFormat('d MMM').format(dt);
  }

  void _openSendMessage({
    String? prefilledPatientId,
    String? prefilledPatientName,
    String? prefilledMessage,
    bool isReminder = false,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SendMessageScreen(
          prefilledPatientId: prefilledPatientId,
          prefilledPatientName: prefilledPatientName,
          prefilledMessage: prefilledMessage,
          isReminder: isReminder,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final items = _filtered;

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          // Filter bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                _FilterChip(
                  label: s.allFilter,
                  selected: _filter == _Filter.all,
                  onTap: () => setState(() => _filter = _Filter.all),
                  leadingIcon: Icons.filter_list_rounded,
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: s.filterSent,
                  selected: _filter == _Filter.sent,
                  onTap: () => setState(() => _filter = _Filter.sent),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: s.filterSystem,
                  selected: _filter == _Filter.system,
                  onTap: () => setState(() => _filter = _Filter.system),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => _openSendMessage(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3A8A),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Text(
                      s.sendMessageBtn,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // List
          Expanded(
            child: items.isEmpty
                ? _EmptyState(filter: _filter)
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final item = items[i];
                      return _NotifCard(
                        item: item,
                        timeLabel: _timeLabel(item.createdAt, s),
                        isDark: isDark,
                        onSendReminder: item.kind == _NotifKind.system
                            ? () => _openSendMessage(
                                  prefilledPatientId: item.toPatientId,
                                  prefilledPatientName: item.toName,
                                  prefilledMessage: item.body,
                                  isReminder: true,
                                )
                            : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// Filter chip

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? leadingIcon;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.leadingIcon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = selected
        ? const Color(0xFF1E3A8A)
        : (isDark ? Colors.white54 : const Color(0xFF64748B));

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? (isDark ? const Color(0xFF2A2A4A) : const Color(0xFFE8EEF9))
              : (isDark ? const Color(0xFF1E1E2E) : Colors.white),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected
                ? const Color(0xFF1E3A8A)
                : (isDark ? const Color(0xFF3A3A5C) : const Color(0xFFE2E8F0)),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leadingIcon != null) ...[
              Icon(leadingIcon, size: 15, color: color),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Notification card

class _NotifCard extends StatelessWidget {
  final _NotifItem item;
  final String timeLabel;
  final bool isDark;
  final VoidCallback? onSendReminder;

  const _NotifCard({
    required this.item,
    required this.timeLabel,
    required this.isDark,
    this.onSendReminder,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isSystem = item.kind == _NotifKind.system;
    const primaryBlue = Color(0xFF1E3A8A);
    const alertOrange = Color(0xFFF97316);

    final iconBg = isSystem
        ? alertOrange.withValues(alpha: 0.12)
        : primaryBlue.withValues(alpha: 0.10);
    final iconColor = isSystem ? alertOrange : primaryBlue;
    final icon = isSystem ? Icons.warning_amber_rounded : Icons.send_outlined;
    final titleColor = isSystem
        ? alertOrange
        : (isDark ? Colors.white : const Color(0xFF1F2937));
    final title = isSystem
        ? '${item.toName} ${item.body}'.trim()
        : s.toPatientName(item.toName);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            blurRadius: 10,
            offset: const Offset(0, 3),
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: titleColor,
                      ),
                    ),
                    if (!isSystem) ...[
                      const SizedBox(height: 3),
                      Text(
                        item.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? Colors.white54
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),

              Text(
                timeLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),

          if (isSystem && onSendReminder != null) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: onSendReminder,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A8A),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  s.sendReminderQ,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// Empty state

class _EmptyState extends StatelessWidget {
  final _Filter filter;
  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final label = switch (filter) {
      _Filter.all    => s.noNotifications,
      _Filter.sent   => s.noSentMessages,
      _Filter.system => s.noSystemAlerts,
    };

    return Center(
      child: Text(
        label,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
        ),
      ),
    );
  }
}
