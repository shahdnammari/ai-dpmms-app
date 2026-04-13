import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../role_select_screen.dart';
import 'patient_details_screen.dart';

// ─── Severity ─────────────────────────────────────────────────────────────────

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

// ─── Models ───────────────────────────────────────────────────────────────────

class _PatientStat {
  final String uid;
  final String name;
  final double adherence; // 0.0 – 1.0
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

// ─── Main widget ──────────────────────────────────────────────────────────────

class DoctorHomeTab extends StatefulWidget {
  const DoctorHomeTab({super.key});

  @override
  State<DoctorHomeTab> createState() => _DoctorHomeTabState();
}

class _DoctorHomeTabState extends State<DoctorHomeTab> {
  late Future<List<_PatientStat>> _statsFuture;

  // null = show alerts, 'all' | 'adherent' | 'atRisk' = show filtered list
  String? _activeFilter;

  @override
  void initState() {
    super.initState();
    _statsFuture = _loadPatientStats();
  }

  void _reloadStats() => setState(() { _statsFuture = _loadPatientStats(); });

  // ─── helpers ────────────────────────────────────────────────────────────────

  String _formatToday() => DateFormat('d MMMM, EEEE').format(DateTime.now());

  String _dateId(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static String relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1)  return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)   return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  void _toggleFilter(String key) =>
      setState(() => _activeFilter = _activeFilter == key ? null : key);

  // ─── menu ────────────────────────────────────────────────────────────────────

  Future<void> _showMoreMenu() async {
    final selected = await showMenu<String>(
      context: context,
      position: const RelativeRect.fromLTRB(1000, 145, 16, 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      items: const [
        PopupMenuItem(
          value: 'settings',
          child: ListTile(
            dense: true,
            leading: Icon(Icons.settings_outlined, color: Color(0xFF1E3A8A)),
            title: Text('Setting', style: TextStyle(color: Color(0xFF1E3A8A))),
          ),
        ),
        PopupMenuItem(
          value: 'help',
          child: ListTile(
            dense: true,
            leading: Icon(Icons.help_outline, color: Color(0xFF0B1B3A)),
            title: Text('Help & Support', style: TextStyle(color: Color(0xFF0B1B3A))),
          ),
        ),
        PopupMenuDivider(),
        PopupMenuItem(
          value: 'logout',
          child: ListTile(
            dense: true,
            leading: Icon(Icons.logout, color: Color(0xFFDC2626)),
            title: Text('Logout', style: TextStyle(color: Color(0xFFDC2626))),
          ),
        ),
      ],
    );

    if (!mounted || selected == null) return;

    if (selected == 'settings') {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const _SettingsPlaceholder()));
    } else if (selected == 'help') {
      _showHelpSheet();
    } else if (selected == 'logout') {
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
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (_) => const Padding(
        padding: EdgeInsets.fromLTRB(20, 18, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 42, child: Divider(thickness: 4)),
            SizedBox(height: 14),
            Text('Help & Support',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A))),
            SizedBox(height: 8),
            Text(
              'For help with the dashboard, patients, or account issues,\nplease contact support.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF64748B), height: 1.4),
            ),
            SizedBox(height: 18),
            ListTile(
                leading: Icon(Icons.email_outlined),
                title: Text('support@ai-dpmms.com')),
            ListTile(
                leading: Icon(Icons.phone_outlined),
                title: Text('+970 000 000 000')),
          ],
        ),
      ),
    );
  }

  // ─── quick action callbacks ──────────────────────────────────────────────────

  void _onAddPatient() => ScaffoldMessenger.of(context)
      .showSnackBar(const SnackBar(content: Text('Add Patient — coming soon')));

  void _onSendReminderGlobal() => ScaffoldMessenger.of(context)
      .showSnackBar(const SnackBar(content: Text('Send Reminder — coming soon')));

  void _onViewReports() => ScaffoldMessenger.of(context)
      .showSnackBar(const SnackBar(content: Text('View Reports — coming soon')));

  // ─── alert action callbacks ──────────────────────────────────────────────────

  Future<void> _sendReminderFor(_Alert alert) async {
    await FirebaseFirestore.instance
        .collection('alerts')
        .doc(alert.id)
        .update({'isRead': true});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Reminder sent to ${alert.patientName}')),
    );
  }

  void _viewPatient(_Alert alert) {
    // TODO: Navigate to PatientDetailsScreen(uid: alert.patientId)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('View ${alert.patientName} — coming soon')),
    );
  }

  // ─── data loading ────────────────────────────────────────────────────────────

  Future<double> _adherenceFor(String uid) async {
    final db = FirebaseFirestore.instance;
    final today = DateTime.now();
    int total = 0, taken = 0;

    for (int i = 0; i < 7; i++) {
      final day = today.subtract(Duration(days: i));
      final snap = await db
          .collection('users')
          .doc(uid)
          .collection('daily_intake')
          .doc(_dateId(day))
          .get();
      final data = snap.data() ?? {};
      for (final entry in data.values) {
        if (entry is Map) {
          total++;
          if (entry['status'] == 'taken') taken++;
        }
      }
    }
    return total == 0 ? 1.0 : taken / total;
  }

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

  // ─── build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (FirebaseAuth.instance.currentUser == null) {
      return const Center(child: Text('Not logged in.'));
    }

    return Container(
      color: const Color(0xFFF3F6FB),
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
          final atRisk =
              stats?.where((s) => s.adherence < 0.7).toList() ?? [];
          final adherent =
              stats?.where((s) => s.adherence >= 0.7).toList() ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Date row ────────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _formatToday(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                    ),
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(
                              builder: (_) => const _AiPlaceholder())),
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(Icons.auto_awesome_outlined,
                            color: Color(0xFF1E3A8A), size: 22),
                      ),
                    ),
                    const SizedBox(width: 2),
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _showMoreMenu,
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(Icons.more_vert,
                            color: Color(0xFF334155), size: 22),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // ── Overview ─────────────────────────────────────────────
                const Text(
                  'Overview',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 12),

                if (loading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: _InteractiveCard(
                          label: 'Patients',
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
                          label: 'Adherent',
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
                          label: 'At Risk',
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

                // ── Quick Actions ─────────────────────────────────────────
                if (!loading) ...[
                  const SizedBox(height: 20),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _QuickAction(
                          icon: Icons.person_add_outlined,
                          label: 'Add Patient',
                          onTap: _onAddPatient,
                        ),
                        const SizedBox(width: 10),
                        _QuickAction(
                          icon: Icons.notifications_active_outlined,
                          label: 'Send Reminder',
                          onTap: _onSendReminderGlobal,
                        ),
                        const SizedBox(width: 10),
                        _QuickAction(
                          icon: Icons.bar_chart_outlined,
                          label: 'View Reports',
                          onTap: _onViewReports,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // ── Animated content area ─────────────────────────────────
                if (!loading)
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
            ),
          );
        },
      ),
    );
  }
}

// ─── Interactive overview card ────────────────────────────────────────────────

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

// ─── Quick action button ──────────────────────────────────────────────────────

class _QuickAction extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<_QuickAction> createState() => _QuickActionState();
}

class _QuickActionState extends State<_QuickAction> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: _pressed ? const Color(0xFF1E3A8A) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _pressed
                ? const Color(0xFF1E3A8A)
                : const Color(0xFFE2E8F0),
            width: 0.5,
          ),
          boxShadow: const [
            BoxShadow(
              blurRadius: 8,
              offset: Offset(0, 2),
              color: Color(0x0A000000),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              widget.icon,
              color: _pressed ? Colors.white : const Color(0xFF1E3A8A),
              size: 22,
            ),
            const SizedBox(height: 6),
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _pressed ? Colors.white : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Alerts section (Firestore stream) ───────────────────────────────────────

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
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('alerts')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        final alerts =
            snap.data?.docs.map(_Alert.fromDoc).toList() ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: Color(0xFFDC2626), size: 20),
                const SizedBox(width: 6),
                Text(
                  'ALERTS (${alerts.length})',
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Text(
                  'No alerts at this time. All patients are on track.',
                  style: TextStyle(
                      color: Color(0xFF64748B),
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

// ─── Smart alert card ─────────────────────────────────────────────────────────

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
    final color = alert.severity.color;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              blurRadius: 10,
              offset: Offset(0, 3),
              color: Color(0x0F000000),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Colored left border
                Container(width: 3, color: color),
                // Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name + timestamp row
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                alert.patientName,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                            ),
                            Text(
                              _DoctorHomeTabState.relativeTime(alert.createdAt),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF94A3B8),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Issue type
                        Text(
                          alert.type,
                          style: TextStyle(
                            fontSize: 13,
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Action buttons
                        Row(
                          children: [
                            _AlertActionBtn(
                              label: 'Send Reminder',
                              icon: Icons.notifications_active_outlined,
                              color: const Color(0xFF1E3A8A),
                              onTap: () => onSendReminder(alert),
                            ),
                            const SizedBox(width: 8),
                            _AlertActionBtn(
                              label: 'View Patient',
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
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Filtered patient list ────────────────────────────────────────────────────

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

  String get _title {
    switch (filter) {
      case 'all':      return 'All Patients';
      case 'adherent': return 'Adherent Patients';
      case 'atRisk':   return 'At Risk Patients';
      default:         return 'Patients';
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 18,
              decoration: BoxDecoration(
                color: _accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: Color(0xFF334155),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${stats.length}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: _accent,
                ),
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Text(
              'No patients in this category.',
              style: TextStyle(
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600),
            ),
          )
        else
          ...stats.map((s) => _PatientFilterCard(stat: s, accent: _accent, onDeleted: onDeleted)),
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              blurRadius: 10,
              offset: Offset(0, 3),
              color: Color(0x0F000000),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
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
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Adherence: $pct%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: accent,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: Color(0xFF94A3B8), size: 20),
          ],
        ),
      ),
      ),
    );
  }
}

// ─── Placeholders ─────────────────────────────────────────────────────────────

class _AiPlaceholder extends StatelessWidget {
  const _AiPlaceholder();
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('AI Assistant')),
      body: const Center(
          child: Text('AI Screen — coming soon',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600))));
}

class _SettingsPlaceholder extends StatelessWidget {
  const _SettingsPlaceholder();
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: const Center(
          child: Text('Settings Screen — coming soon',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600))));
}
