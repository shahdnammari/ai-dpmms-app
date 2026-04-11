import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:flutter/material.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _inited = false;
  GlobalKey<NavigatorState>? navigatorKey;

  Future<void> init({required GlobalKey<NavigatorState> navKey}) async {
    if (_inited) return;

    navigatorKey = navKey;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) async {
        await _handleNotificationTap(response.payload);
      },
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    tzdata.initializeTimeZones();
    final String localTz = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localTz));

    _inited = true;
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  ({int h, int m}) _parseHHmm(String s) {
    final parts = s.split(':');
    final h = int.tryParse(parts[0]) ?? 9;
    final m = int.tryParse(parts[1]) ?? 0;
    return (h: h, m: m);
  }

  int _id(String medDocId, int dayOffset, int timeIndex) {
    return medDocId.hashCode + dayOffset * 100 + timeIndex;
  }

  Future<void> scheduleMedicationRange({
    required String uid,
    required String medDocId,
    required String medName,
    required DateTime startDate,
    required DateTime? endDate,
    required List<String> times,
  }) async {
    try {
      if (!_inited) return;
      if (times.isEmpty) return;

      final today = _dateOnly(DateTime.now());
      final d0 = _dateOnly(startDate);

      final windowEnd = today.add(const Duration(days: 90));

      final from = d0.isAfter(today) ? d0 : today;
      final realEnd = endDate != null ? _dateOnly(endDate) : windowEnd;
      final to = realEnd.isBefore(windowEnd) ? realEnd : windowEnd;

      if (to.isBefore(from)) return;

      const androidDetails = AndroidNotificationDetails(
        'med_reminders',
        'Medication Reminders',
        channelDescription: 'Reminders to take medications',
        importance: Importance.max,
        priority: Priority.high,
      );

      const details = NotificationDetails(android: androidDetails);

      final now = DateTime.now();
      int dayOffset = 0;

      for (DateTime d = from;
          !d.isAfter(to);
          d = d.add(const Duration(days: 1)), dayOffset++) {
        for (int ti = 0; ti < times.length; ti++) {
          final parsed = _parseHHmm(times[ti]);
          final when = DateTime(d.year, d.month, d.day, parsed.h, parsed.m);

          if (when.isBefore(now)) continue;

          final tzWhen = tz.TZDateTime.from(when, tz.local);
          final payload =
              '$uid|$medDocId|$medName|${when.millisecondsSinceEpoch}|$ti|${times[ti]}';

          final inboxWriteUntil = today.add(const Duration(days: 7));

          await _plugin.zonedSchedule(
            _id(medDocId, dayOffset, ti),
            'Medication Reminder',
            'Time to take $medName',
            tzWhen,
            details,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            payload: payload,
          );

          if (!when.isAfter(inboxWriteUntil)) {
            await _upsertScheduledInboxNotification(
              uid: uid,
              medDocId: medDocId,
              medName: medName,
              when: when,
              timeIndex: ti,
              timeString: times[ti],
            );
          }
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> cancelMedicationNotifications({
    required String medDocId,
  }) async {
    try {
      for (int dayOffset = 0; dayOffset < 100; dayOffset++) {
        for (int ti = 0; ti < 10; ti++) {
          final id = _id(medDocId, dayOffset, ti);
          try {
            await _plugin.cancel(id);
          } catch (_) {}
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _handleNotificationTap(String? payload) async {
    if (payload == null) return;

    try {
      final parts = payload.split('|');
      if (parts.length < 6) return;

      final uid = parts[0];
      final medId = parts[1];
      final medName = parts[2];
      final millis = int.parse(parts[3]);
      final timeIndex = int.parse(parts[4]);
      final timeString = parts[5];

      final when = DateTime.fromMillisecondsSinceEpoch(millis);

      await _markInboxNotificationOpened(
        uid: uid,
        medDocId: medId,
        medName: medName,
        when: when,
        timeIndex: timeIndex,
        timeString: timeString,
      );

      if (navigatorKey?.currentState != null) {
        navigatorKey?.currentState?.pushNamed('/notifications');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _upsertScheduledInboxNotification({
    required String uid,
    required String medDocId,
    required String medName,
    required DateTime when,
    required int timeIndex,
    required String timeString,
  }) async {
    try {
      final inboxId =
          '${medDocId}_${when.millisecondsSinceEpoch}_${timeString.replaceAll(':', '_')}';

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('inbox_notifications')
          .doc(inboxId)
          .set({
        'type': 'med',
        'title': 'Time to take $medName',
        'body': 'Scheduled at $timeString',
        'medication_id': medDocId,
        'event_time': Timestamp.fromDate(when),
        'scheduled_time': timeString,
        'time_index': timeIndex,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
        'actionStatus': 'pending',
        'openedFromSystemTap': false,
      }, SetOptions(merge: true));
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _markInboxNotificationOpened({
    required String uid,
    required String medDocId,
    required String medName,
    required DateTime when,
    required int timeIndex,
    required String timeString,
  }) async {
    try {
      final inboxId =
          '${medDocId}_${when.millisecondsSinceEpoch}_${timeString.replaceAll(':', '_')}';

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('inbox_notifications')
          .doc(inboxId)
          .set({
        'type': 'med',
        'title': 'Time to take $medName',
        'body': 'Scheduled at $timeString',
        'medication_id': medDocId,
        'event_time': Timestamp.fromDate(when),
        'scheduled_time': timeString,
        'time_index': timeIndex,
        'openedFromSystemTap': true,
        'openedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      rethrow;
    }
  }
}