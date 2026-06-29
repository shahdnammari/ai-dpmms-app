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

      // 30-day window — enough for local notifications; reschedules on next open
      final windowEnd = today.add(const Duration(days: 30));

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
      final inboxWriteUntil = today.add(const Duration(days: 7));
      final inboxItems = <({String id, Map<String, dynamic> data})>[];

      int dayOffset = 0;
      for (DateTime d = from;
          !d.isAfter(to);
          d = d.add(const Duration(days: 1)), dayOffset++) {
        // Schedule all time slots for this single day in parallel
        final dayFutures = <Future<void>>[];

        for (int ti = 0; ti < times.length; ti++) {
          final parsed = _parseHHmm(times[ti]);
          final when = DateTime(d.year, d.month, d.day, parsed.h, parsed.m);
          if (when.isBefore(now)) continue;

          final tzWhen = tz.TZDateTime.from(when, tz.local);
          final payload =
              '$uid|$medDocId|$medName|${when.millisecondsSinceEpoch}|$ti|${times[ti]}';

          dayFutures.add(_plugin.zonedSchedule(
            _id(medDocId, dayOffset, ti),
            'Medication Reminder',
            'Time to take $medName',
            tzWhen,
            details,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            payload: payload,
          ));

          if (!when.isAfter(inboxWriteUntil)) {
            final inboxId =
                '${medDocId}_${when.millisecondsSinceEpoch}_${times[ti].replaceAll(':', '_')}';
            inboxItems.add((
              id: inboxId,
              data: {
                'type': 'med',
                'title': 'Time to take $medName',
                'medication_name': medName,
                'body': 'Scheduled at ${times[ti]}',
                'medication_id': medDocId,
                'event_time': Timestamp.fromDate(when),
                'scheduled_time': times[ti],
                'time_index': ti,
                'createdAt': FieldValue.serverTimestamp(),
                'read': false,
                'actionStatus': 'pending',
                'openedFromSystemTap': false,
              },
            ));
          }
        }

        if (dayFutures.isNotEmpty) await Future.wait(dayFutures);

        // Yield to the event loop after each day so the UI stays responsive
        await Future<void>.delayed(Duration.zero);
      }

      // Commit all inbox writes in one batch
      if (inboxItems.isNotEmpty) {
        final db = FirebaseFirestore.instance;
        for (int i = 0; i < inboxItems.length; i += 500) {
          final batch = db.batch();
          for (final item in inboxItems.skip(i).take(500)) {
            batch.set(
              db.collection('users').doc(uid)
                  .collection('inbox_notifications').doc(item.id),
              item.data,
              SetOptions(merge: true),
            );
          }
          await batch.commit();
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
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
        'medication_name': medName,
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