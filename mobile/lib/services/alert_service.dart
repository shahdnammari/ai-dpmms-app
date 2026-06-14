import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AlertService {
  static const _baseUrl = 'http://172.20.10.3:8000';

  // In-memory guard: prevents race-condition duplicates within a single session.
  static final _inFlight = <String>{};

  /// Fire-and-forget — never throws.
  /// Pass [targetUid] to check a specific patient (doctor-side).
  /// Omit it to check the currently logged-in patient.
  static Future<void> analyzeAndAlert({String? targetUid}) async {
    final uid = targetUid ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    if (_inFlight.contains(uid)) return;
    _inFlight.add(uid);
    try {

      final firestore = FirebaseFirestore.instance;

      // ── Cooldown: max 1 alert per patient per day ─────────────────────────
      final today = DateTime.now();
      final midnight = DateTime(today.year, today.month, today.day);

      final existing = await firestore
          .collection('alerts')
          .where('patientId', isEqualTo: uid)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(midnight))
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) return;

      // ── Fetch patient profile ─────────────────────────────────────────────
      final userDoc = await firestore.collection('users').doc(uid).get();
      final userData = userDoc.data() ?? {};
      final patientName = (userData['name'] as String?)?.trim().isNotEmpty == true
          ? userData['name'] as String
          : (userData['username'] as String?) ?? 'Patient';

      final medications = await _fetchMedicationNames(uid, firestore);
      final conditions =
          List<String>.from((userData['conditions'] as List?) ?? []);

      // ── Compute adherence stats (last 7 days) ─────────────────────────────
      int total = 0, taken = 0, missed = 0;
      int consecutiveMissed = 0;
      bool countingConsecutive = true;

      for (int i = 0; i < 7; i++) {
        final date = DateTime.now().subtract(Duration(days: i));
        final dateStr = DateFormat('yyyy-MM-dd').format(date);

        final dayDoc = await firestore
            .collection('users')
            .doc(uid)
            .collection('daily_intake')
            .doc(dateStr)
            .get();

        if (!dayDoc.exists) continue;

        final dayData = dayDoc.data() ?? {};
        bool anyMissedToday = false;

        for (final value in dayData.values) {
          if (value is Map) {
            final status = value['status'] as String? ?? '';
            if (status == 'taken') {
              total++;
              taken++;
              countingConsecutive = false;
            } else if (status == 'missed' || status == 'skipped') {
              total++;
              missed++;
              anyMissedToday = true;
            }
          }
        }

        if (countingConsecutive && anyMissedToday) consecutiveMissed++;
      }

      if (total == 0) return;

      // ── Try backend /analyze (5-second timeout) ───────────────────────────
      bool handledByBackend = false;
      try {
        final response = await http
            .post(
              Uri.parse('$_baseUrl/analyze'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'patient_name': patientName,
                'medications': medications,
                'conditions': conditions,
                'total_doses': total,
                'taken_doses': taken,
                'missed_doses': missed,
                'consecutive_missed': consecutiveMissed,
              }),
            )
            .timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          handledByBackend = true;
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          if (data['should_alert'] == true) {
            await _writeAlert(
              firestore, uid, patientName,
              data['message'] as String? ?? 'Medication adherence concern',
              data['severity'] as String? ?? 'warning',
            );
          }
        }
      } catch (_) {
        // Backend unreachable — fall through to client-side logic below
      }

      if (handledByBackend) return;

      // ── Client-side fallback when backend is unavailable ──────────────────
      // Same thresholds as the backend (chat.py /analyze rules)
      final adherence = taken / total;

      if (adherence < 0.5 || consecutiveMissed >= 3) {
        await _writeAlert(
          firestore, uid, patientName,
          'Critical: ${(adherence * 100).round()}% adherence over the last days',
          'critical',
        );
      } else if (adherence < 0.7 || consecutiveMissed >= 2) {
        await _writeAlert(
          firestore, uid, patientName,
          'Low adherence: ${(adherence * 100).round()}% over the last days',
          'warning',
        );
      }
      // else: adherence >= 70% and no consecutive misses — no alert needed
    } catch (_) {
      // Silent — never interrupt the patient's dose logging flow
    } finally {
      _inFlight.remove(uid);
    }
  }

  static Future<void> _writeAlert(
    FirebaseFirestore firestore,
    String uid,
    String patientName,
    String message,
    String severity,
  ) async {
    await firestore.collection('alerts').add({
      'patientId': uid,
      'patientName': patientName,
      'type': message,
      'severity': severity,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
    });
  }

  static Future<List<String>> _fetchMedicationNames(
      String uid, FirebaseFirestore firestore) async {
    final snap = await firestore
        .collection('users')
        .doc(uid)
        .collection('medications')
        .get();
    return snap.docs
        .map((d) => (d.data()['name'] as String?) ?? '')
        .where((n) => n.isNotEmpty)
        .toList();
  }
}
