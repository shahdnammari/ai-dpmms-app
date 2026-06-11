import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_strings.dart';
import '../../services/report_service.dart';
import '../../services/settings_service.dart';
import '../role_select_screen.dart';
import '../patient/settings_screen.dart';
import 'doctor_ai_screen.dart';
import 'patient_details_screen.dart';
import 'send_message_screen.dart';

// Severity

enum _Severity { critical, warning, info }

extension _SeverityX on _Severity {
  Color get color {
    switch (this) {
      case _Severity.critical: return const Color(0xFFDC2626);
      case _Severity.warning:  return const Color(0xFFF97316);
      case _Severity.info:     return const Color(0xFF3B82F6);
    }
  }

  static _Severity fromString(String? s) {
    switch (s) {
      case 'critical': return _Severity.critical;
      case 'warning':  return _Severity.warning;
      default:         return _Severity.info;
    }
  }
}

// Models

class _PatientStat {
  final String uid;
  final String name;
  final double adherence;
  const _PatientStat({required this.uid, required this.name, required this.adherence});
}

class _Alert {
  final String id;
  final String patientName;
  final String patientId;
  final String type;
  final _Severity severity;
  final DateTime createdAt;

  const _Alert({
    required this.id,
    required this.patientName,
    required this.patientId,
    required this.type,
    required this.severity,
    required this.createdAt,
  });

  factory _Alert.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final ts = d['createdAt'];
    return _Alert(
      id: doc.id,
      patientName: (d['patientName'] as String?) ?? 'Unknown',
      patientId: (d['patientId'] as String?) ?? '',
      type: (d['type'] as String?) ?? 'Alert',
      severity: _SeverityX.fromString(d['severity'] as String?),
      createdAt: ts is Timestamp ? ts.toDate() : DateTime.now(),
    );
  }
}

// Main widget

class DoctorHomeTab extends StatefulWidget {
  const DoctorHomeTab({super.key});

  @override
  State<DoctorHomeTab> createState() => _DoctorHomeTabState();
}

class _DoctorHomeTabState extends State<DoctorHomeTab> {
  late Future<List<_PatientStat>> _statsFuture;
  String? _activeFilter;

  @override
  void initState() {
    super.initState();
    _statsFuture = _loadPatientStats();
  }

  void _reloadStats() => setState(() { _statsFuture = _loadPatientStats(); });

  String _formatToday() => DateFormat('d MMMM, EEEE').format(DateTime.now());

  static String relativeTime(DateTime dt, S s) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1)  return s.justNow;
    if (diff.inMinutes < 60) return s.minsAgo(diff.inMinutes);
    if (diff.inHours < 24)   return s.hoursAgo(diff.inHours);
    return s.daysAgo(diff.inDays);
  }

  void _toggleFilter(String key) =>
      setState(() => _activeFilter = _activeFilter == key ? null : key);

  Future<void> _showMoreMenu() async {
    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isRtl = SettingsService.instance.isRtl;

    final selected = await showMenu<String>(
      context: context,
      position: isRtl
          ? const RelativeRect.fromLTRB(16, 145, 1000, 0)
          : const RelativeRect.fromLTRB(1000, 145, 16, 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
      items: [
        PopupMenuItem(
          value: 'settings',
          child: ListTile(
            dense: true,
            leading: Icon(Icons.settings_outlined, 
                  color: isDark ? Colors.white : const Color(0xFF0B1B3A)),
            title: Text(s.menuSetting,
                style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0B1B3A))),
          ),
        ),
        PopupMenuItem(
          value: 'help',
          child: ListTile(
            dense: true,
            leading: Icon(Icons.help_outline,
                color: isDark ? Colors.white : const Color(0xFF0B1B3A)),
            title: Text(s.menuHelp,
                style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0B1B3A))),
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'logout',
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.logout, color: Color(0xFFDC2626)),
            title: Text(s.menuLogout,
                style: const TextStyle(color: Color(0xFFDC2626))),
          ),
        ),
      ],
    );

    if (!mounted || selected == null) return;

    if (selected == 'settings') {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const SettingsScreen()));
    } else if (selected == 'help') {
      _showHelpSheet();
    } else if (selected == 'logout') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(s.logoutConfirmTitle,
              style: const TextStyle(fontWeight: FontWeight.w800)),
          content: Text(s.logoutConfirmMsg),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(s.cancel,
                  style: const TextStyle(color: Color(0xFF3B82F6))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: Text(s.logoutButton),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const RoleSelectScreen()),
        (_) => false,
      );
    }
  }

  void _showHelpSheet() {
    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
                width: 42,
                child: Divider(
                    thickness: 4,
                    color: isDark ? Colors.white24 : Colors.grey.shade300)),
            const SizedBox(height: 14),
            Text(s.helpTitle,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A))),
            const SizedBox(height: 8),
            Text(
              s.helpDoctorBody,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: isDark ? Colors.white54 : const Color(0xFF64748B),
                  height: 1.4),
            ),
            const SizedBox(height: 18),
            ListTile(
              leading: Icon(Icons.email_outlined,
                  color: isDark ? Colors.white70 : null),
              title: Text('support@ai-dpmms.com',
                  style: TextStyle(
                      color: isDark ? Colors.white : null)),
            ),
            ListTile(
              leading: Icon(Icons.phone_outlined,
                  color: isDark ? Colors.white70 : null),
              title: Text('+970 000 000 000',
                  style: TextStyle(
                      color: isDark ? Colors.white : null)),
            ),
          ],
        ),
      ),
    );
  }

  void _onAddPatient() => ScaffoldMessenger.of(context)
      .showSnackBar(const SnackBar(content: Text('Add Patient — coming soon')));

  Future<void> _sendReminderFor(_Alert alert) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SendMessageScreen(
          prefilledPatientId: alert.patientId,
          prefilledPatientName: alert.patientName,
        ),
      ),
    );
    // Alert stays visible until it auto-expires after 24 hours.
    // Deleting it here would reset the cooldown and cause duplicate alerts.
  }

  void _viewPatient(_Alert alert) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 380),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (ctx, a1, a2) => PatientDetailsScreen(
          patientUid: alert.patientId,
          patientName: alert.patientName,
        ),
        transitionsBuilder: (ctx, a1, a2, child) => child,
      ),
    );
  }

  Future<double> _adherenceFor(String uid) =>
      ReportService().getAdherenceLast7Days(uid);

  Future<List<_PatientStat>> _loadPatientStats() async {
    final db = FirebaseFirestore.instance;
    final results = await Future.wait([
      db.collection('users').where('role', isEqualTo: 'patient').get(),
      db.collection('users').where('role', isEqualTo: 'Patient').get(),
    ]);

    final seen = <String>{};
    final docs = [...results[0].docs, ...results[1].docs]
        .where((d) => seen.add(d.id))
        .toList();

    final stats = <_PatientStat>[];
    for (final doc in docs) {
      final data = doc.data();
      final name = (data['name'] as String?)?.trim().isNotEmpty == true
          ? data['name'] as String
          : (data['username'] as String?) ?? 'Unknown';
      final adherence = await _adherenceFor(doc.id);
      stats.add(_PatientStat(uid: doc.id, name: name, adherence: adherence));
    }
    return stats;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (FirebaseAuth.instance.currentUser == null) {
      return Center(child: Text(s.notSignedIn));
    }

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: FutureBuilder<List<_PatientStat>>(
        future: _statsFuture,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Error: ${snap.error}',
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center),
              ),
            );
          }

          final stats = snap.data;
          final loading = snap.connectionState != ConnectionState.done;
          final atRisk = stats?.where((s) => s.adherence < 0.7).toList() ?? [];
          final adherent = stats?.where((s) => s.adherence >= 0.7).toList() ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date row
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _formatToday(),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF1F2937),
                        ),
                      ),
                    ),
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _onAddPatient,
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(Icons.person_add_outlined,
                            color: isDark
                                ? Colors.white70
                                : const Color(0xFF1E3A8A),
                            size: 22),
                      ),
                    ),
                    const SizedBox(width: 2),
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(
                              builder: (_) => const DoctorAiScreen())),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(Icons.auto_awesome_outlined,
                            color: isDark
                                ? Colors.white70
                                : const Color(0xFF1E3A8A),
                            size: 22),
                      ),
                    ),
                    const SizedBox(width: 2),
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _showMoreMenu,
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(Icons.more_vert,
                            color: isDark
                                ? Colors.white54
                                : const Color(0xFF334155),
                            size: 22),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                Text(
                  s.overview,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 12),

                if (loading)
                  const _SkeletonHomeContent()
                else ...[
                  Row(
                    children: [
                      Expanded(
                        child: _InteractiveCard(
                          label: s.patients,
                          value: (stats?.length ?? 0),
                          icon: Icons.people_outline,
                          bg: const Color(0xFF0F172A),
                          filterKey: 'all',
                          activeFilter: _activeFilter,
                          onTap: () => _toggleFilter('all'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _InteractiveCard(
                          label: s.adherent,
                          value: adherent.length,
                          icon: Icons.emoji_events_outlined,
                          bg: const Color(0xFF22C55E),
                          filterKey: 'adherent',
                          activeFilter: _activeFilter,
                          onTap: () => _toggleFilter('adherent'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _InteractiveCard(
                          label: s.atRisk,
                          value: atRisk.length,
                          icon: Icons.warning_amber_outlined,
                          bg: const Color(0xFFF97316),
                          filterKey: 'atRisk',
                          activeFilter: _activeFilter,
                          onTap: () => _toggleFilter('atRisk'),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.06),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: _activeFilter == null
                        ? _AlertsSection(
                            key: const ValueKey('alerts'),
                            onSendReminder: _sendReminderFor,
                            onViewPatient: _viewPatient,
                          )
                        : _FilteredPatientList(
                            key: ValueKey(_activeFilter),
                            stats: _activeFilter == 'all'
                                ? (stats ?? [])
                                : _activeFilter == 'adherent'
                                    ? adherent
                                    : atRisk,
                            filter: _activeFilter!,
                            onDeleted: _reloadStats,
                          ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

// Skeleton loading

class _SkeletonHomeContent extends StatefulWidget {
  const _SkeletonHomeContent();

  @override
  State<_SkeletonHomeContent> createState() => _SkeletonHomeContentState();
}

class _SkeletonHomeContentState extends State<_SkeletonHomeContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _opacity = Tween(begin: 0.35, end: 0.75).animate(
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

    return AnimatedBuilder(
      animation: _opacity,
      builder: (_, _) => Opacity(
        opacity: _opacity.value,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: List.generate(3, (i) => i)
                  .expand((i) => [
                        Expanded(
                          child: Container(
                            height: 118,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF2A2A4A)
                                  : const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _box(width: 36, height: 36, radius: 12),
                                const SizedBox(height: 10),
                                _box(width: 42, height: 22, radius: 6),
                                const SizedBox(height: 6),
                                _box(width: 56, height: 12, radius: 4),
                              ],
                            ),
                          ),
                        ),
                        if (i < 2) const SizedBox(width: 10),
                      ])
                  .toList(),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                _box(width: 20, height: 20, radius: 4),
                const SizedBox(width: 8),
                _box(width: 100, height: 14, radius: 6),
              ],
            ),
            const SizedBox(height: 12),
            ...List.generate(3, (_) => _SkeletonAlertCard()),
          ],
        ),
      ),
    );
  }
}

class _SkeletonAlertCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final skelBg = isDark ? const Color(0xFF2A2A4A) : const Color(0xFFE2E8F0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              blurRadius: 10,
              offset: const Offset(0, 3),
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 3, color: skelBg),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 8, height: 8,
                              decoration: BoxDecoration(
                                  color: skelBg, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 120, height: 14,
                              decoration: BoxDecoration(
                                  color: skelBg,
                                  borderRadius: BorderRadius.circular(6)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: 80, height: 11,
                          decoration: BoxDecoration(
                              color: skelBg,
                              borderRadius: BorderRadius.circular(4)),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Container(
                              width: 110, height: 28,
                              decoration: BoxDecoration(
                                  color: skelBg,
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 90, height: 28,
                              decoration: BoxDecoration(
                                  color: skelBg,
                                  borderRadius: BorderRadius.circular(10)),
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
        ),
      ),
    );
  }
}

// Interactive overview card

class _InteractiveCard extends StatefulWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color bg;
  final String filterKey;
  final String? activeFilter;
  final VoidCallback onTap;

  const _InteractiveCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.bg,
    required this.filterKey,
    required this.activeFilter,
    required this.onTap,
  });

  @override
  State<_InteractiveCard> createState() => _InteractiveCardState();
}

class _InteractiveCardState extends State<_InteractiveCard> {
  bool _pressed = false;

  bool get _active => widget.activeFilter == widget.filterKey;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
          decoration: BoxDecoration(
            color: widget.bg,
            borderRadius: BorderRadius.circular(20),
            border: _active
                ? const Border(
                    bottom: BorderSide(color: Colors.white, width: 3))
                : null,
            boxShadow: [
              BoxShadow(
                blurRadius: _active ? 22 : 14,
                offset: const Offset(0, 4),
                color: widget.bg.withValues(alpha: _active ? 0.55 : 0.2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(widget.icon, color: Colors.white, size: 20),
              ),
              const SizedBox(height: 10),
              Text(
                '${widget.value}',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: .85),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Alerts section (Firestore stream)

class _AlertsSection extends StatelessWidget {
  final Future<void> Function(_Alert) onSendReminder;
  final void Function(_Alert) onViewPatient;

  const _AlertsSection({
    super.key,
    required this.onSendReminder,
    required this.onViewPatient,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cutoff = Timestamp.fromDate(
      DateTime.now().subtract(const Duration(hours: 24)),
    );

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('alerts')
          .where('createdAt', isGreaterThanOrEqualTo: cutoff)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        final alerts = snap.data?.docs.map(_Alert.fromDoc).toList() ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: Color(0xFFDC2626), size: 20),
                const SizedBox(width: 6),
                Text(
                  s.alertsCount(alerts.length),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFDC2626),
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (alerts.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  s.noAlerts,
                  style: TextStyle(
                      color: isDark ? Colors.white54 : const Color(0xFF64748B),
                      fontWeight: FontWeight.w600),
                ),
              )
            else
              ...alerts.map(
                (a) => _SmartAlertCard(
                  alert: a,
                  onSendReminder: onSendReminder,
                  onViewPatient: onViewPatient,
                ),
              ),
          ],
        );
      },
    );
  }
}

// Smart alert card

class _SmartAlertCard extends StatelessWidget {
  final _Alert alert;
  final Future<void> Function(_Alert) onSendReminder;
  final void Function(_Alert) onViewPatient;

  const _SmartAlertCard({
    required this.alert,
    required this.onSendReminder,
    required this.onViewPatient,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = alert.severity.color;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
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
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 3, color: color),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 8, height: 8,
                              decoration: BoxDecoration(
                                  color: color, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                alert.patientName,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF1F2937),
                                ),
                              ),
                            ),
                            Text(
                              _DoctorHomeTabState.relativeTime(
                                  alert.createdAt, s),
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? Colors.white38
                                    : const Color(0xFF94A3B8),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          alert.type,
                          style: TextStyle(
                            fontSize: 13,
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _AlertActionBtn(
                              label: s.sendReminder,
                              icon: Icons.notifications_active_outlined,
                              color: const Color(0xFF1E3A8A),
                              onTap: () => onSendReminder(alert),
                            ),
                            const SizedBox(width: 8),
                            _AlertActionBtn(
                              label: s.viewPatient,
                              icon: Icons.person_outline,
                              color: const Color(0xFF64748B),
                              onTap: () => onViewPatient(alert),
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
        ),
      ),
    );
  }
}

class _AlertActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _AlertActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

// Filtered patient list

class _FilteredPatientList extends StatelessWidget {
  final List<_PatientStat> stats;
  final String filter;
  final VoidCallback? onDeleted;

  const _FilteredPatientList({
    super.key,
    required this.stats,
    required this.filter,
    this.onDeleted,
  });

  String _title(S s) {
    switch (filter) {
      case 'all':      return s.allPatients;
      case 'adherent': return s.adherentPatients;
      case 'atRisk':   return s.atRiskPatients;
      default:         return s.patients;
    }
  }

  Color get _accent {
    switch (filter) {
      case 'adherent': return const Color(0xFF22C55E);
      case 'atRisk':   return const Color(0xFFF97316);
      default:         return const Color(0xFF1E3A8A);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4, height: 18,
              decoration: BoxDecoration(
                color: _accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _title(s),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF334155),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${stats.length}',
                style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w800, color: _accent),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (stats.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              s.noPatientsCategory,
              style: TextStyle(
                  color: isDark ? Colors.white54 : const Color(0xFF64748B),
                  fontWeight: FontWeight.w600),
            ),
          )
        else
          ...stats.map((s) =>
              _PatientFilterCard(stat: s, accent: _accent, onDeleted: onDeleted)),
      ],
    );
  }
}

class _PatientFilterCard extends StatelessWidget {
  final _PatientStat stat;
  final Color accent;
  final VoidCallback? onDeleted;

  const _PatientFilterCard({
    required this.stat,
    required this.accent,
    this.onDeleted,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pct = (stat.adherence * 100).round();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () async {
          final deleted = await Navigator.of(context).push<bool>(
            PageRouteBuilder<bool>(
              opaque: false,
              barrierColor: Colors.transparent,
              transitionDuration: const Duration(milliseconds: 380),
              reverseTransitionDuration: const Duration(milliseconds: 300),
              pageBuilder: (ctx, a1, a2) => PatientDetailsScreen(
                patientUid: stat.uid,
                patientName: stat.name,
              ),
              transitionsBuilder: (ctx, a1, a2, child) => child,
            ),
          );
          if (deleted == true) onDeleted?.call();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
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
          child: Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.person_outline, color: accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stat.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      s.adherencePct(pct),
                      style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600, color: accent),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                  size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
