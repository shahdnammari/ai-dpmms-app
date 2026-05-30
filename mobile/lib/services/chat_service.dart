import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ChatService {
  // Use your computer's local IP when testing on a physical device
  // Run: (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias Wi-Fi).IPAddress
  static const _baseUrl = 'http://172.20.10.3:8000';

  static Future<String> ask(String question) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Not authenticated');

    final firestore = FirebaseFirestore.instance;

    // Fetch user profile (age, gender, conditions if stored)
    final userDoc = await firestore.collection('users').doc(uid).get();
    final userData = userDoc.data() ?? {};

    // Fetch active medications
    final medsSnap = await firestore
        .collection('users')
        .doc(uid)
        .collection('medications')
        .get();

    final medications = medsSnap.docs
        .map((d) => (d.data()['name'] as String?) ?? '')
        .where((n) => n.isNotEmpty)
        .toList();

    // Compute adherence summary over the last 7 days
    int taken = 0;
    int missed = 0;
    final now = DateTime.now();
    for (int i = 0; i < 7; i++) {
      final date =
          DateFormat('yyyy-MM-dd').format(now.subtract(Duration(days: i)));
      final dayDoc = await firestore
          .collection('users')
          .doc(uid)
          .collection('daily_intake')
          .doc(date)
          .get();
      if (dayDoc.exists) {
        final dayData = dayDoc.data() ?? {};
        for (final value in dayData.values) {
          if (value is Map) {
            final status = value['status'] as String? ?? '';
            if (status == 'taken') taken++;
            if (status == 'missed') missed++;
          }
        }
      }
    }

    final adherenceSummary = (taken + missed) > 0
        ? 'Took $taken doses, missed $missed doses in the last 7 days'
        : 'No recent adherence data';

    // Compute age from birthday Timestamp
    int? age;
    final birthdayValue = userData['birthday'];
    if (birthdayValue is Timestamp) {
      final birthday = birthdayValue.toDate();
      final today = DateTime.now();
      age = today.year - birthday.year;
      if (today.month < birthday.month ||
          (today.month == birthday.month && today.day < birthday.day)) {
        age--;
      }
    }

    final body = <String, dynamic>{
      'question': question,
      'medications': medications,
      'conditions': List<String>.from((userData['conditions'] as List?) ?? []),
      'age': age,
      'gender': userData['gender'] as String?,
      'adherence_summary': adherenceSummary,
    };

    final response = await http.post(
      Uri.parse('$_baseUrl/chat'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['answer'] as String;
    }

    final errorBody = jsonDecode(response.body);
    throw Exception(errorBody['detail'] ?? 'Unknown error');
  }
}