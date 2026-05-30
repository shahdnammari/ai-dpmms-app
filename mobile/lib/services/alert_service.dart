import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AlertService {
  static const _baseUrl = 'http://172.20.10.3:8000';

  /// Call after every dose status change. Fire-and-forget — never throws.
  static Future<void> analyzeAndAlert() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final firestore = FirebaseFirestore.instance;

      // ── Cooldown: max 1 alert per patient per day ─────────────────────────
      final todayStart = DateTime.now();
      final midnight = DateTime(todayStart.year, todayStart.month, todayStart.day);

      final existing = await firestore
          .collection('alerts')
          .where('patientId', isEqualTo: uid)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(midnight))
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) return; // already alerted today

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

        if (countingConsecutive && anyMissedToday) {
          consecutiveMissed++;
        }
      }

      if (total == 0) return; // no data yet, nothing to analyze

      // ── Call backend /analyze ─────────────────────────────────────────────
      final body = {
        'patient_name': patientName,
        'medications': medications,
        'conditions': conditions,
        'total_doses': total,
        'taken_doses': taken,
        'missed_doses': missed,
        'consecutive_missed': consecutiveMissed,
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/analyze'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode != 200) return;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final shouldAlert = data['should_alert'] as bool? ?? false;

      if (!shouldAlert) return;

      // ── Write alert to Firestore ──────────────────────────────────────────
      await firestore.collection('alerts').add({
        'patientId': uid,
        'patientName': patientName,
        'type': data['message'] as String? ?? 'Medication adherence concern',
        'severity': data['severity'] as String? ?? 'warning',
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
      });
    } catch (_) {
      // Silent — never interrupt the patient's dose logging flow
    }
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
