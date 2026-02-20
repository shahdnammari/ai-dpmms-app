import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _inited = false;

  Future<void> init() async {
    if (_inited) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(initSettings);

    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('UTC')); // stable, no hardcode country


    _inited = true;
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// times: ["08:30","20:00"]
  ({int h, int m}) _parseHHmm(String s) {
    final parts = s.split(':');
    if (parts.length != 2) return (h: 9, m: 0);
    final h = int.tryParse(parts[0]) ?? 9;
    final m = int.tryParse(parts[1]) ?? 0;
    return (h: h.clamp(0, 23), m: m.clamp(0, 59));
  }

  int _id(String medDocId, int dayOffset, int timeIndex) {
    return medDocId.hashCode ^ ((dayOffset + 1) * 100000) ^ ((timeIndex + 1) * 1000);
  }

  Future<void> scheduleInOneMinute() async {
  await init();
  final now = tz.TZDateTime.now(tz.local);
  final scheduled = now.add(const Duration(minutes: 1));

  const android = AndroidNotificationDetails(
    'test_channel_2',
    'Test Scheduled',
    channelDescription: 'Scheduled test',
    importance: Importance.max,
    priority: Priority.high,
  );

  await _plugin.zonedSchedule(
    888888,
    'Scheduled Test',
    'This should appear in 1 minute',
    scheduled,
    const NotificationDetails(android: android),
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
  );
}


  Future<void> scheduleMedicationRange({
    required String medDocId,
    required String medName,
    required DateTime startDate,
    required DateTime? endDate,
    required List<String> times, // "HH:mm"
  }) async {
    await init();

    final d0 = _dateOnly(startDate);
    final d1 = _dateOnly(endDate ?? d0.add(const Duration(days: 365)));

    if (d1.isBefore(d0) || times.isEmpty) return;

    const androidDetails = AndroidNotificationDetails(
      'med_reminders',
      'Medication Reminders',
      channelDescription: 'Reminders to take medications',
      importance: Importance.max,
      priority: Priority.high,
    );

    final now = DateTime.now();

    int dayOffset = 0;
    for (DateTime d = d0; !d.isAfter(d1); d = d.add(const Duration(days: 1)), dayOffset++) {
      for (int ti = 0; ti < times.length; ti++) {
        final parsed = _parseHHmm(times[ti]);
        final when = DateTime(d.year, d.month, d.day, parsed.h, parsed.m);
        if (when.isBefore(now)) continue;

        await _plugin.zonedSchedule(
          _id(medDocId, dayOffset, ti),
          'Medication Reminder',
          'Time to take $medName',
          tz.TZDateTime.from(when, tz.local),
          const NotificationDetails(android: androidDetails),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
    }
  }

  Future<void> cancelMedicationRange({
    required String medDocId,
    required DateTime startDate,
    required DateTime? endDate,
    required int timesCount,
  }) async {
    await init();

    final d0 = _dateOnly(startDate);
    final d1 = _dateOnly(endDate ?? d0.add(const Duration(days: 365)));
    if (d1.isBefore(d0) || timesCount <= 0) return;

    final days = d1.difference(d0).inDays + 1;
    for (int dayOffset = 0; dayOffset < days; dayOffset++) {
      for (int ti = 0; ti < timesCount; ti++) {
        await _plugin.cancel(_id(medDocId, dayOffset, ti));
      }
    }
  }
}
