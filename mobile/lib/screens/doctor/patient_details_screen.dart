import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_strings.dart';
import '../../models/medication.dart';
import '../../services/report_service.dart';
import '../patient/medication_form_screen.dart';
import 'doctor_reports_tab.dart';
import 'doctor_shell.dart';
import 'send_message_screen.dart';

// Models

class _ActivityEntry {
  final DateTime date;
  final String status; // 'taken' | 'skipped'
  const _ActivityEntry({required this.date, required this.status});
}

class _MedActivity {
  final Medication med;
  final List<_ActivityEntry> activity;
  const _MedActivity({required this.med, required this.activity});
}

class _PatientDetails {
  final String name;
  final double adherence;
  final List<_MedActivity> medications;
  const _PatientDetails({
    required this.name,
    required this.adherence,
    required this.medications,
  });
}

// Screen

class PatientDetailsScreen extends StatefulWidget {
  final String patientUid;
  final String patientName; // shown instantly before Firestore loads

  const PatientDetailsScreen({
    super.key,
    required this.patientUid,
    required this.patientName,
  });

  @override
  State<PatientDetailsScreen> createState() => _PatientDetailsScreenState();
}

class _PatientDetailsScreenState extends State<PatientDetailsScreen> {
  _PatientDetails? _data;
  bool _loading = true;
  String? _error;
  bool _showAll = false;

  static const _bg = Color(0xFF0F172A);
  static const _cardLimit = 3;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // helpers

  String _dateId(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  String _formatDate(DateTime d) => DateFormat('d MMM').format(d);

  String _formatDays(List<String> days, S s) {
    if (days.length >= 7) return s.everyday;
    if (days.isEmpty) return '—';
    return days.join(' • ');
  }

  String _formatTimes(List<String> times) =>
      times.isEmpty ? '—' : times.join(', ');

  // data

  Future<List<_ActivityEntry>> _activityFor(Medication med) async {
    final db = FirebaseFirestore.instance;
    final today = DateTime.now();
    final entries = <_ActivityEntry>[];

    for (int i = 0; i < 14 && entries.length < 4; i++) {
      final day = today.subtract(Duration(days: i));
      final snap = await db
          .collection('users')
          .doc(widget.patientUid)
          .collection('daily_intake')
          .doc(_dateId(day))
          .get();

      final data = snap.data() ?? {};
      for (final e in data.entries) {
        if (e.key.startsWith('${med.id}_') && e.value is Map) {
          final status = (e.value as Map)['status'] as String?;
          if (status == 'taken' || status == 'skipped') {
            entries.add(_ActivityEntry(date: day, status: status!));
            break; // one entry per day
          }
        }
      }
    }
    return entries;
  }

  Future<double> _adherenceFor() =>
      ReportService().getAdherenceLast7Days(widget.patientUid);

  Future<void> _loadData() async {
    setState(() { _loading = true; _error = null; });
    try {
      final db = FirebaseFirestore.instance;

      // Load patient name from Firestore (override the passed name if richer)
      final userDoc =
          await db.collection('users').doc(widget.patientUid).get();
      final userData = userDoc.data() ?? {};
      final name =
          (userData['name'] as String?)?.trim().isNotEmpty == true
              ? userData['name'] as String
              : widget.patientName;

      // Load medications
      final medSnap = await db
          .collection('users')
          .doc(widget.patientUid)
          .collection('medications')
          .get();
      final meds = medSnap.docs.map(Medication.fromDoc).toList();

      // Parallel: adherence + per-medication activity
      final adherence = await _adherenceFor();
      final activityList =
          await Future.wait(meds.map(_activityFor));

      final medActivities = List.generate(
        meds.length,
        (i) => _MedActivity(med: meds[i], activity: activityList[i]),
      );

      if (mounted) {
        setState(() {
          _data = _PatientDetails(
            name: name,
            adherence: adherence,
            medications: medActivities,
          );
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  // actions

  Future<void> _addMedication() async {
    final savedName = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => MedicationFormScreen(
          uid: widget.patientUid,
          effectiveDate: DateTime.now(),
          source: MedicationFormSource.medicationsList,
        ),
      ),
    );
    if (savedName != null && savedName.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.patientUid)
            .collection('inbox_notifications')
            .add({
          'type': 'medication_added',
          'medication_name': savedName,
          'title': 'Medication Added',
          'body': savedName,
          'read': false,
          'event_time': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {}
    }
    _loadData();
  }

  Future<void> _editMedication(Medication med) async {
    final savedName = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => MedicationFormScreen(
          uid: widget.patientUid,
          existing: med,
          effectiveDate: DateTime.now(),
          source: MedicationFormSource.medicationsList,
        ),
      ),
    );
    if (savedName != null && savedName.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.patientUid)
            .collection('inbox_notifications')
            .add({
          'type': 'medication_updated',
          'medication_name': savedName,
          'title': 'Medication Updated',
          'body': savedName,
          'read': false,
          'event_time': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {}
    }
    _loadData();
  }

  Future<void> _deletePatient() async {
    final s = S.of(context);
    final name = _data?.name ?? widget.patientName;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text(s.deletePatientTitle,
            style: const TextStyle(fontWeight: FontWeight.w800)),
        content: Text(s.deletePatientWithUndo(name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.cancel),
          ),
          TextButton(
            style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.delete,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.patientUid)
          .delete();
      if (!mounted) return;
      Navigator.pop(context, true); // signal to parent to refresh
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _deleteMedication(Medication med) async {
    final s = S.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(s.deleteMedTitle,
            style: const TextStyle(fontWeight: FontWeight.w800)),
        content: Text(s.deleteConfirm(med.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.cancel),
          ),
          TextButton(
            style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.delete,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.patientUid)
          .collection('medications')
          .doc(med.id)
          .delete();
      _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _sendMessage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SendMessageScreen(
          prefilledPatientId:   widget.patientUid,
          prefilledPatientName: _data?.name ?? widget.patientName,
        ),
      ),
    );
  }

  void _viewReport() {
    DoctorReportsTab.patientNotifier.value =
        (id: widget.patientUid, name: widget.patientName);
    DoctorShell.tabNotifier.value = 3;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  // build

  @override
  Widget build(BuildContext context) {
    final routeAnim = ModalRoute.of(context)?.animation
        ?? const AlwaysStoppedAnimation<double>(1.0);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Blurred backdrop (tapping it dismisses the modal)
          AnimatedBuilder(
            animation: routeAnim,
            builder: (_, child) {
              final v = routeAnim.value;
              return BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 7 * v, sigmaY: 7 * v),
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.45 * v),
                  ),
                ),
              );
            },
          ),

          // Floating card
          AnimatedBuilder(
            animation: routeAnim,
            builder: (_, child) {
              final t = Curves.easeOutCubic.transform(routeAnim.value);
              return FractionalTranslation(
                translation: Offset(0, 1 - t),
                child: child,
              );
            },
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                14,
                MediaQuery.of(context).padding.top + 56, // status bar + gap
                14,
                MediaQuery.of(context).padding.bottom + 20,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Container(
                  decoration: BoxDecoration(
                    color: _bg,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: const [
                      BoxShadow(
                        blurRadius: 40,
                        spreadRadius: 4,
                        color: Color(0x55000000),
                      ),
                    ],
                  ),
                  child: _buildCardContent(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardContent(BuildContext context) {
    final s = S.of(context);
    final displayName = _data?.name ?? widget.patientName;
    final adherencePct = _data != null
        ? '${(_data!.adherence * 100).round()}%'
        : '—';
    final medCount = _data?.medications.length ?? 0;
    final hasMore = !_showAll && medCount > _cardLimit;

    return SafeArea(
      top: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 2, 16, 0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close,
                      color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
                const Icon(Icons.person_outline,
                    color: Colors.white60, size: 20),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add,
                      color: Color(0xFF3B82F6)),
                  onPressed: _addMedication,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: Color(0xFFEF4444)),
                  onPressed: _deletePatient,
                ),
                IconButton(
                  icon: const Icon(Icons.send_outlined,
                      color: Colors.white70),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),

          // Patient stats
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$adherencePct ${s.adherence}',
                  style: const TextStyle(
                    color: Color(0xFF22C55E),
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.medication_outlined,
                        color: Colors.white60, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      _loading
                          ? s.loadingLabel
                          : s.nMedications(medCount),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Medications list
          Expanded(child: _buildContent(s)),

          // Bottom bar
          Container(
            color: _bg,
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 14),
            child: Row(
              children: [
                if (hasMore)
                  _BottomAction(
                    label: s.viewMore,
                    onTap: () => setState(() => _showAll = true),
                  )
                else if (_showAll && medCount > _cardLimit)
                  _BottomAction(
                    label: s.viewLess,
                    onTap: () => setState(() => _showAll = false),
                  )
                else
                  const SizedBox.shrink(),
                const Spacer(),
                _BottomAction(label: s.viewReport, onTap: _viewReport),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(S s) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Error: $_error',
              style: const TextStyle(color: Colors.redAccent),
              textAlign: TextAlign.center),
        ),
      );
    }

    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.white));
    }

    final meds = _data!.medications;

    if (meds.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.medication_outlined,
                color: Colors.white24, size: 56),
            const SizedBox(height: 14),
            Text(
              s.noMedicationsYet,
              style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _addMedication,
              icon: const Icon(Icons.add, size: 18),
              label: Text(s.addMedication),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      );
    }

    final visible = _showAll ? meds : meds.take(_cardLimit).toList();

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      itemCount: visible.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _MedCard(
        medActivity: visible[i],
        onEdit: () => _editMedication(visible[i].med),
        onDelete: () => _deleteMedication(visible[i].med),
        formatDate: _formatDate,
        formatDays: (days) => _formatDays(days, s),
        formatTimes: _formatTimes,
      ),
    );
  }
}

// Bottom text action

class _BottomAction extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _BottomAction({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// Medication card

class _MedCard extends StatelessWidget {
  final _MedActivity medActivity;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final String Function(DateTime) formatDate;
  final String Function(List<String>) formatDays;
  final String Function(List<String>) formatTimes;

  const _MedCard({
    required this.medActivity,
    required this.onEdit,
    required this.onDelete,
    required this.formatDate,
    required this.formatDays,
    required this.formatTimes,
  });

  @override
  Widget build(BuildContext context) {
    final med = medActivity.med;
    final activity = medActivity.activity;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 14, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
              blurRadius: 16,
              offset: Offset(0, 6),
              color: Color(0x22000000)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name + edit
          Row(
            children: [
              const Icon(Icons.medication_outlined,
                  color: Color(0xFF1E3A8A), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  med.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: onDelete,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.delete_outline,
                      color: Color(0xFFEF4444), size: 18),
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: onEdit,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.edit_outlined,
                      color: Color(0xFF94A3B8), size: 18),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),

          // Details
          _DetailRow(Icons.science_outlined, med.dosage),
          const SizedBox(height: 6),
          _DetailRow(
              Icons.access_time_rounded, formatTimes(med.times)),
          const SizedBox(height: 6),
          _DetailRow(Icons.repeat, formatDays(med.repeatDays)),

          // Recent activity
          if (activity.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 10),
            Builder(builder: (context) {
              final s = S.of(context);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.history,
                          size: 14, color: Color(0xFF64748B)),
                      const SizedBox(width: 6),
                      Text(
                        s.recentActivity,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...activity.map((e) {
                    final isTaken = e.status == 'taken';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '${formatDate(e.date)} - ${isTaken ? s.statusTaken : s.statusSkipped}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isTaken
                              ? const Color(0xFF22C55E)
                              : const Color(0xFFEF4444),
                        ),
                      ),
                    );
                  }),
                ],
              );
            }),
          ],
        ],
      ),
    );
  }
}

// Detail row

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _DetailRow(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 15, color: const Color(0xFF64748B)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF374151),
            ),
          ),
        ),
      ],
    );
  }
}
