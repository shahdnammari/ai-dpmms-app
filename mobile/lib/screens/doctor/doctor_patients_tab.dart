import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'dart:math' show min;

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
  final double adherence; // 0.0 – 1.0
  final DateTime? lastActivity;

  const _PatientInfo({
    required this.uid,
    required this.name,
    required this.medicationCount,
    required this.adherence,
    this.lastActivity,
  });
}

// Relative-time helpers

String _activityLabel(DateTime? dt) {
  if (dt == null) return 'No activity';
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inHours < 48) return 'Yesterday';
  return '${diff.inDays} days ago';
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
  String _filter = 'all';   // 'all' | 'atRisk' | 'adherent'
  String _sortBy = 'name';  // 'name' | 'adherence' | 'medications'

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

  // computed

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

  String get _sortLabel {
    switch (_sortBy) {
      case 'adherence':   return 'Adherence';
      case 'medications': return 'Medications';
      default:            return 'A–Z';
    }
  }

  // data

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

  // actions

  void _softDelete(_PatientInfo patient) {
    final idx = _patients.indexOf(patient);
    if (idx < 0) return;
    setState(() => _patients.removeAt(idx));

    bool undone = false;
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(
          content: Text('"${patient.name}" deleted'),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              undone = true;
              setState(() => _patients.insert(
                  idx.clamp(0, _patients.length), patient));
            },
          ),
        )).closed.then((_) async {
          if (!undone) {
            try {
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(patient.uid)
                  .delete();
            } catch (_) {}
          }
        });
  }

  Future<void> _confirmDelete(_PatientInfo patient) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Patient',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text(
          'Are you sure you want to remove "${patient.name}" from the system?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(fontWeight: FontWeight.w700)),
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
    // If the patient was deleted from inside the details screen, reload the list
    if (deleted == true) _loadPatients();
  }

  void _onAddPatient() =>
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add Patient — coming soon')),
      );

  // list builder

  List<Widget> _buildListItems(List<_PatientInfo> items) {
    final widgets = <Widget>[];
    String? lastLetter;

    for (final patient in items) {
      // Alpha header only when sorted A–Z
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
                label: 'Delete',
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
              ),
            ],
          ),
          child: _PatientCard(
            patient: patient,
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

  // build

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          color: const Color(0xFFF3F6FB),
          child: Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                          blurRadius: 8,
                          offset: Offset(0, 2),
                          color: Color(0x0A000000)),
                    ],
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    style: const TextStyle(fontSize: 15),
                    decoration: const InputDecoration(
                      hintText: 'Search Patient name...',
                      hintStyle: TextStyle(
                          color: Color(0xFF94A3B8), fontSize: 15),
                      prefixIcon: Icon(Icons.search,
                          color: Color(0xFF94A3B8), size: 22),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
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
                      label: 'All',
                      active: _filter == 'all',
                      onTap: () => setState(() => _filter = 'all'),
                    ),
                    const SizedBox(width: 8),
                    _ChipFilter(
                      label: 'At Risk',
                      active: _filter == 'atRisk',
                      color: const Color(0xFFDC2626),
                      onTap: () => setState(() => _filter = 'atRisk'),
                    ),
                    const SizedBox(width: 8),
                    _ChipFilter(
                      label: 'Adherent',
                      active: _filter == 'adherent',
                      color: const Color(0xFF22C55E),
                      onTap: () => setState(() => _filter = 'adherent'),
                    ),
                    const SizedBox(width: 16),
                    // Sort dropdown
                    PopupMenuButton<String>(
                      onSelected: (v) =>
                          setState(() => _sortBy = v),
                      offset: const Offset(0, 36),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                            value: 'name', child: Text('Name A–Z')),
                        PopupMenuItem(
                            value: 'adherence',
                            child: Text('Lowest adherence')),
                        PopupMenuItem(
                            value: 'medications',
                            child: Text('Most medications')),
                      ],
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.sort,
                                size: 14, color: Color(0xFF64748B)),
                            const SizedBox(width: 4),
                            Text(
                              _sortLabel,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(width: 2),
                            const Icon(Icons.keyboard_arrow_down,
                                size: 14, color: Color(0xFF64748B)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(child: _buildContent()),
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
            child: const Icon(Icons.person_add_outlined,
                color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
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
          // Section heading
          Row(
            children: [
              const Text(
                'Patients List',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
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

          // Empty states
          if (displayed.isEmpty && _searchQuery.isNotEmpty) ...[
            const SizedBox(height: 40),
            Center(
              child: Column(
                children: [
                  const Icon(Icons.search_off,
                      size: 52, color: Color(0xFFCBD5E1)),
                  const SizedBox(height: 12),
                  Text(
                    'No patients match\n"${_searchCtrl.text}"',
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  OutlinedButton.icon(
                    onPressed: _onAddPatient,
                    icon: const Icon(Icons.person_add_outlined, size: 16),
                    label: const Text('Add new patient'),
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
            const Center(
              child: Text(
                'No patients found.',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: active ? color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active ? color : const Color(0xFFE2E8F0)),
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
            color: active ? Colors.white : const Color(0xFF64748B),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 0, 4),
      child: Text(
        letter,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w900,
          color: Color(0xFF94A3B8),
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// Patient card

class _PatientCard extends StatefulWidget {
  final _PatientInfo patient;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onDetails;
  final VoidCallback onTap;

  const _PatientCard({
    required this.patient,
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
    final p = widget.patient;
    final pct = (p.adherence * 100).round();
    final medLabel = p.medicationCount == 1
        ? '1 Medication'
        : '${p.medicationCount} Medications';
    final color = _avatarColor(p.name);
    final initials = _initials(p.name);
    final silent = _isSilent(p.lastActivity);
    final label = _activityLabel(p.lastActivity);

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
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                  blurRadius: 10,
                  offset: Offset(0, 3),
                  color: Color(0x0F000000)),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Initials avatar
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: color, shape: BoxShape.circle),
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Name · activity · medications · adherence
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name + last activity timestamp
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            p.name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.access_time,
                                size: 11,
                                color: silent
                                    ? const Color(0xFFDC2626)
                                    : const Color(0xFF94A3B8)),
                            const SizedBox(width: 3),
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: silent
                                    ? const Color(0xFFDC2626)
                                    : const Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),

                    // Medication count
                    Row(
                      children: [
                        Icon(Icons.medication_outlined,
                            size: 13,
                            color: const Color(0xFF64748B)
                                .withValues(alpha: 0.8)),
                        const SizedBox(width: 4),
                        Text(
                          medLabel,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Adherence label + %
                    Row(
                      children: [
                        const Text(
                          'Adherence',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF94A3B8),
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

                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: p.adherence,
                        minHeight: 7,
                        backgroundColor: const Color(0xFFE2E8F0),
                        valueColor:
                            AlwaysStoppedAnimation<Color>(_barColor),
                      ),
                    ),
                  ],
                ),
              ),

              // Three-dot menu
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') widget.onEdit();
                  if (v == 'delete') widget.onDelete();
                  if (v == 'details') widget.onDetails();
                },
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 4,
                icon: const Icon(Icons.more_vert,
                    color: Color(0xFF94A3B8), size: 20),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'edit',
                    height: 44,
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined,
                            color: Color(0xFF1E3A8A), size: 18),
                        SizedBox(width: 10),
                        Text('Edit',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1E3A8A))),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    height: 44,
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline,
                            color: Color(0xFFDC2626), size: 18),
                        SizedBox(width: 10),
                        Text('Delete',
                            style: TextStyle(
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
                            color: Color(0xFF64748B), size: 18),
                        SizedBox(width: 10),
                        Text('Details',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B))),
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
    return AnimatedBuilder(
      animation: _opacity,
      builder: (_, _) => Opacity(
        opacity: _opacity.value,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              // Avatar placeholder
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Color(0xFFE2E8F0),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 14,
                      width: 140,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Container(
                      height: 10,
                      width: 90,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 7,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(999),
                      ),
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
