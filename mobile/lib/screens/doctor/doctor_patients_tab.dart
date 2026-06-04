import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'dart:math' show min;

import '../../l10n/app_strings.dart';
import '../../services/app_refresh.dart';
import 'patient_details_screen.dart';

// Avatar palette

const _kAvatarColors = [
  Color(0xFF6366F1), Color(0xFF8B5CF6), Color(0xFF0EA5E9),
  Color(0xFF10B981), Color(0xFFF59E0B), Color(0xFFEC4899),
  Color(0xFFEF4444), Color(0xFF14B8A6),
];

Color _avatarColor(String name) {
  final hash = name.codeUnits.fold(0, (s, c) => s + c);
  return _kAvatarColors[hash % _kAvatarColors.length];
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.length >= 2 && parts[1].isNotEmpty) {
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
  return name.substring(0, min(2, name.length)).toUpperCase();
}

// Model

class _PatientInfo {
  final String uid;
  final String name;
  final int medicationCount;
  final double adherence;
  final DateTime? lastActivity;

  const _PatientInfo({
    required this.uid,
    required this.name,
    required this.medicationCount,
    required this.adherence,
    this.lastActivity,
  });
}

bool _isSilent(DateTime? dt) =>
    dt == null || DateTime.now().difference(dt).inDays >= 2;

// Main widget

class DoctorPatientsTab extends StatefulWidget {
  const DoctorPatientsTab({super.key});

  @override
  State<DoctorPatientsTab> createState() => _DoctorPatientsTabState();
}

class _DoctorPatientsTabState extends State<DoctorPatientsTab> {
  bool _loading = true;
  String? _error;
  List<_PatientInfo> _patients = [];

  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _filter = 'all';
  String _sortBy = 'name';

  VoidCallback? _refreshListener;

  @override
  void initState() {
    super.initState();
    _loadPatients();
    _searchCtrl.addListener(
      () => setState(
          () => _searchQuery = _searchCtrl.text.trim().toLowerCase()),
    );
    _refreshListener = () { if (mounted) _loadPatients(); };
    AppRefresh.notifier.addListener(_refreshListener!);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    if (_refreshListener != null) {
      AppRefresh.notifier.removeListener(_refreshListener!);
    }
    super.dispose();
  }

  List<_PatientInfo> get _displayed {
    final q = _searchQuery;
    var list = _patients.where((p) {
      if (q.isNotEmpty && !p.name.toLowerCase().contains(q)) return false;
      if (_filter == 'atRisk' && p.adherence >= 0.7) return false;
      if (_filter == 'adherent' && p.adherence < 0.7) return false;
      return true;
    }).toList();

    switch (_sortBy) {
      case 'adherence':
        list.sort((a, b) => a.adherence.compareTo(b.adherence));
        break;
      case 'medications':
        list.sort((a, b) => b.medicationCount.compareTo(a.medicationCount));
        break;
      default:
        list.sort((a, b) =>
            a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
    return list;
  }

  String _sortLabel(S s) {
    switch (_sortBy) {
      case 'adherence':   return s.adherence;
      case 'medications': return s.medications;
      default:            return s.nameAZ;
    }
  }

  String _activityLabel(DateTime? dt, S s) {
    if (dt == null) return s.noRecentActivity;
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1)  return s.justNow;
    if (diff.inHours < 1)    return s.minsAgo(diff.inMinutes);
    if (diff.inHours < 24)   return s.hoursAgo(diff.inHours);
    if (diff.inHours < 48)   return s.yesterday;
    return s.daysAgo(diff.inDays);
  }

  String _dateId(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

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
      for (final entry in (snap.data() ?? {}).values) {
        if (entry is Map) {
          total++;
          if (entry['status'] == 'taken') taken++;
        }
      }
    }
    return total == 0 ? 1.0 : taken / total;
  }

  Future<int> _medicationCountFor(String uid) async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('medications')
        .get();
    return snap.docs.length;
  }

  Future<void> _loadPatients() async {
    setState(() { _loading = true; _error = null; });
    try {
      final db = FirebaseFirestore.instance;
      final results = await Future.wait([
        db.collection('users').where('role', isEqualTo: 'patient').get(),
        db.collection('users').where('role', isEqualTo: 'Patient').get(),
      ]);

      final seen = <String>{};
      final docs = [...results[0].docs, ...results[1].docs]
          .where((d) => seen.add(d.id))
          .toList();

      final patients = <_PatientInfo>[];
      for (final doc in docs) {
        final data = doc.data();
        final name =
            (data['name'] as String?)?.trim().isNotEmpty == true
                ? data['name'] as String
                : (data['username'] as String?) ?? 'Unknown';
        final ts = data['lastActivity'];
        final lastActivity = ts is Timestamp ? ts.toDate() : null;
        final medCount = await _medicationCountFor(doc.id);
        final adherence = await _adherenceFor(doc.id);
        patients.add(_PatientInfo(
          uid: doc.id,
          name: name,
          medicationCount: medCount,
          adherence: adherence,
          lastActivity: lastActivity,
        ));
      }
      patients.sort((a, b) =>
          a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      if (mounted) setState(() { _patients = patients; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _softDelete(_PatientInfo patient) {
    final s = S.of(context);
    final idx = _patients.indexOf(patient);
    if (idx < 0) return;
    setState(() => _patients.removeAt(idx));

    bool undone = false;
    final messenger = ScaffoldMessenger.of(context);
    messenger.removeCurrentSnackBar();
    final controller = messenger.showSnackBar(SnackBar(
      content: Text(s.removedPatient(patient.name)),
      duration: const Duration(seconds: 4),
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () {
          undone = true;
          setState(() => _patients.insert(
              idx.clamp(0, _patients.length), patient));
        },
      ),
    ));

    controller.closed.then((_) async {
      if (undone) return;
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(patient.uid)
            .delete();
      } catch (e) {
        if (mounted) {
          setState(() => _patients.insert(
              idx.clamp(0, _patients.length), patient));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete "${patient.name}": $e')),
          );
        }
      }
    });
  }

  Future<void> _confirmDelete(_PatientInfo patient) async {
    final s = S.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(s.deletePatientTitle,
            style: const TextStyle(fontWeight: FontWeight.w800)),
        content: Text(s.deletePatientConfirm(patient.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.cancel),
          ),
          TextButton(
            style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.delete,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed == true) _softDelete(patient);
  }

  void _onEdit(_PatientInfo patient) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Edit medications for ${patient.name} — coming soon')),
      );

  Future<void> _onDetails(_PatientInfo patient) async {
    final deleted = await Navigator.of(context).push<bool>(
      PageRouteBuilder<bool>(
        opaque: false,
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 380),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (ctx, a1, a2) => PatientDetailsScreen(
          patientUid: patient.uid,
          patientName: patient.name,
        ),
        transitionsBuilder: (ctx, a1, a2, child) => child,
      ),
    );
    if (deleted == true) _loadPatients();
  }

  void _onAddPatient() =>
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add Patient — coming soon')),
      );

  List<Widget> _buildListItems(List<_PatientInfo> items) {
    final s = S.of(context);
    final widgets = <Widget>[];
    String? lastLetter;

    for (final patient in items) {
      if (_sortBy == 'name') {
        final letter =
            patient.name.isNotEmpty ? patient.name[0].toUpperCase() : '#';
        if (letter != lastLetter) {
          lastLetter = letter;
          widgets.add(_AlphaHeader(letter: letter));
        }
      }

      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Slidable(
          key: ValueKey(patient.uid),
          endActionPane: ActionPane(
            motion: const DrawerMotion(),
            extentRatio: 0.22,
            children: [
              SlidableAction(
                onPressed: (_) => _confirmDelete(patient),
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                icon: Icons.delete_outline,
                label: s.delete,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
              ),
            ],
          ),
          child: _PatientCard(
            patient: patient,
            activityLabel: _activityLabel(patient.lastActivity, s),
            isSilent: _isSilent(patient.lastActivity),
            onEdit: () => _onEdit(patient),
            onDelete: () => _confirmDelete(patient),
            onDetails: () => _onDetails(patient),
            onTap: () => _onDetails(patient),
          ),
        ),
      ));
    }
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                          color: Colors.black
                              .withValues(alpha: isDark ? 0.2 : 0.04)),
                    ],
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    style: TextStyle(
                        fontSize: 15,
                        color: isDark ? Colors.white : null),
                    decoration: InputDecoration(
                      hintText: s.searchPatientHint,
                      hintStyle: TextStyle(
                          color: isDark
                              ? Colors.white38
                              : const Color(0xFF94A3B8),
                          fontSize: 15),
                      prefixIcon: Icon(Icons.search,
                          color: isDark
                              ? Colors.white38
                              : const Color(0xFF94A3B8),
                          size: 22),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
              ),

              // Filter chips + sort
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Row(
                  children: [
                    _ChipFilter(
                      label: s.allFilter,
                      active: _filter == 'all',
                      onTap: () => setState(() => _filter = 'all'),
                    ),
                    const SizedBox(width: 8),
                    _ChipFilter(
                      label: s.atRisk,
                      active: _filter == 'atRisk',
                      color: const Color(0xFFDC2626),
                      onTap: () => setState(() => _filter = 'atRisk'),
                    ),
                    const SizedBox(width: 8),
                    _ChipFilter(
                      label: s.adherent,
                      active: _filter == 'adherent',
                      color: const Color(0xFF22C55E),
                      onTap: () => setState(() => _filter = 'adherent'),
                    ),
                    const SizedBox(width: 16),
                    PopupMenuButton<String>(
                      onSelected: (v) => setState(() => _sortBy = v),
                      offset: const Offset(0, 36),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      color: isDark ? const Color(0xFF1E1E2E) : null,
                      itemBuilder: (_) => [
                        PopupMenuItem(
                            value: 'name',
                            child: Text(s.nameAZ,
                                style: TextStyle(
                                    color: isDark ? Colors.white : null))),
                        PopupMenuItem(
                            value: 'adherence',
                            child: Text(s.lowestAdherence,
                                style: TextStyle(
                                    color: isDark ? Colors.white : null))),
                        PopupMenuItem(
                            value: 'medications',
                            child: Text(s.mostMedications,
                                style: TextStyle(
                                    color: isDark ? Colors.white : null))),
                      ],
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E1E2E)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: isDark
                                  ? const Color(0xFF3A3A5C)
                                  : const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.sort,
                                size: 14,
                                color: isDark
                                    ? Colors.white54
                                    : const Color(0xFF64748B)),
                            const SizedBox(width: 4),
                            Text(
                              _sortLabel(s),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.white54
                                    : const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(Icons.keyboard_arrow_down,
                                size: 14,
                                color: isDark
                                    ? Colors.white54
                                    : const Color(0xFF64748B)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(child: _buildContent(s, isDark)),
            ],
          ),
        ),

        // FAB
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            heroTag: 'patients_fab',
            shape: const CircleBorder(),
            onPressed: _onAddPatient,
            backgroundColor: const Color(0xFF1E3A8A),
            child: const Icon(Icons.person_add_outlined, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildContent(S s, bool isDark) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Error: $_error',
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center),
        ),
      );
    }

    if (_loading) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 80),
        children: const [
          _SkeletonCard(),
          _SkeletonCard(),
          _SkeletonCard(),
          _SkeletonCard(),
        ],
      );
    }

    final displayed = _displayed;

    return RefreshIndicator(
      onRefresh: _loadPatients,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 80),
        children: [
          Row(
            children: [
              Text(
                s.patientsListTitle,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF1F2937),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A8A).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${displayed.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (displayed.isEmpty && _searchQuery.isNotEmpty) ...[
            const SizedBox(height: 40),
            Center(
              child: Column(
                children: [
                  Icon(Icons.search_off,
                      size: 52,
                      color: isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
                  const SizedBox(height: 12),
                  Text(
                    s.noMatchSearch(_searchCtrl.text),
                    style: TextStyle(
                      color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  OutlinedButton.icon(
                    onPressed: _onAddPatient,
                    icon: const Icon(Icons.person_add_outlined, size: 16),
                    label: Text(s.addNewPatient),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1E3A8A),
                      side: const BorderSide(color: Color(0xFF1E3A8A)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (displayed.isEmpty) ...[
            const SizedBox(height: 40),
            Center(
              child: Text(
                s.noPatientsFound,
                style: TextStyle(
                  color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ] else
            ..._buildListItems(displayed),
        ],
      ),
    );
  }
}

// Filter chip

class _ChipFilter extends StatelessWidget {
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  const _ChipFilter({
    required this.label,
    required this.active,
    this.color = const Color(0xFF1E3A8A),
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: active
              ? color
              : (isDark ? const Color(0xFF1E1E2E) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active
                  ? color
                  : (isDark
                      ? const Color(0xFF3A3A5C)
                      : const Color(0xFFE2E8F0))),
          boxShadow: active
              ? [
                  BoxShadow(
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                    color: color.withValues(alpha: 0.30),
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: active
                ? Colors.white
                : (isDark ? Colors.white54 : const Color(0xFF64748B)),
          ),
        ),
      ),
    );
  }
}

// Alpha section header

class _AlphaHeader extends StatelessWidget {
  final String letter;
  const _AlphaHeader({required this.letter});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 0, 4),
      child: Text(
        letter,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w900,
          color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// Patient card

class _PatientCard extends StatefulWidget {
  final _PatientInfo patient;
  final String activityLabel;
  final bool isSilent;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onDetails;
  final VoidCallback onTap;

  const _PatientCard({
    required this.patient,
    required this.activityLabel,
    required this.isSilent,
    required this.onEdit,
    required this.onDelete,
    required this.onDetails,
    required this.onTap,
  });

  @override
  State<_PatientCard> createState() => _PatientCardState();
}

class _PatientCardState extends State<_PatientCard> {
  bool _pressed = false;

  Color get _barColor {
    if (widget.patient.adherence >= 0.8) return const Color(0xFF22C55E);
    if (widget.patient.adherence >= 0.5) return const Color(0xFFF97316);
    return const Color(0xFFDC2626);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final p = widget.patient;
    final pct = (p.adherence * 100).round();
    final color = _avatarColor(p.name);
    final initials = _initials(p.name);

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 4, 14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                  color: Colors.black
                      .withValues(alpha: isDark ? 0.25 : 0.06)),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 44, height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: Colors.white, fontSize: 15,
                    fontWeight: FontWeight.w800, letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            p.name,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1F2937),
                            ),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.access_time,
                                size: 11,
                                color: widget.isSilent
                                    ? const Color(0xFFDC2626)
                                    : (isDark
                                        ? Colors.white38
                                        : const Color(0xFF94A3B8))),
                            const SizedBox(width: 3),
                            Text(
                              widget.activityLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: widget.isSilent
                                    ? const Color(0xFFDC2626)
                                    : (isDark
                                        ? Colors.white38
                                        : const Color(0xFF94A3B8)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),

                    Row(
                      children: [
                        Icon(Icons.medication_outlined,
                            size: 13,
                            color: (isDark
                                    ? Colors.white38
                                    : const Color(0xFF64748B))
                                .withValues(alpha: 0.8)),
                        const SizedBox(width: 4),
                        Text(
                          s.nMedications(p.medicationCount),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? Colors.white38
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Text(
                          s.adherence,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? Colors.white38
                                : const Color(0xFF94A3B8),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '$pct%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: _barColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: p.adherence,
                        minHeight: 7,
                        backgroundColor: isDark
                            ? const Color(0xFF3A3A5C)
                            : const Color(0xFFE2E8F0),
                        valueColor: AlwaysStoppedAnimation<Color>(_barColor),
                      ),
                    ),
                  ],
                ),
              ),

              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') widget.onEdit();
                  if (v == 'delete') widget.onDelete();
                  if (v == 'details') widget.onDetails();
                },
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 4,
                color: isDark ? const Color(0xFF1E1E2E) : null,
                icon: Icon(Icons.more_vert,
                    color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                    size: 20),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'edit',
                    height: 44,
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined,
                          color: isDark ? Colors.white :  Color(0xFF1E3A8A), size: 18),
                        const SizedBox(width: 10),
                        Text(s.edit,
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1E3A8A))),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    height: 44,
                    child: Row(
                      children: [
                        const Icon(Icons.delete_outline,
                            color: Color(0xFFDC2626), size: 18),
                        const SizedBox(width: 10),
                        Text(s.delete,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFDC2626))),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'details',
                    height: 44,
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: isDark
                                ? Colors.white54
                                : const Color(0xFF64748B),
                            size: 18),
                        const SizedBox(width: 10),
                        Text(s.details,
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.white54
                                    : const Color(0xFF64748B))),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Skeleton loading card

class _SkeletonCard extends StatefulWidget {
  const _SkeletonCard();

  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard>
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final skelBg = isDark ? const Color(0xFF2A2A4A) : const Color(0xFFE2E8F0);

    return AnimatedBuilder(
      animation: _opacity,
      builder: (_, _) => Opacity(
        opacity: _opacity.value,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: skelBg, shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 14, width: 140,
                      decoration: BoxDecoration(
                          color: skelBg,
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    const SizedBox(height: 7),
                    Container(
                      height: 10, width: 90,
                      decoration: BoxDecoration(
                          color: skelBg,
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 7,
                      decoration: BoxDecoration(
                          color: skelBg,
                          borderRadius: BorderRadius.circular(999)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
