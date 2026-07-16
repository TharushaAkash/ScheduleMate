import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;

import '../models/timetable_entry.dart';

class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _channelId = 'class_reminders';
  static const _channelName = 'Class Reminders';

  Future<void> init() async {
    tz_data.initializeTimeZones();
    // If you need the device's real local timezone rather than the
    // default UTC-based one, use the `flutter_timezone` package to fetch
    // it and call tz.setLocalLocation(...) here.

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings =
        InitializationSettings(android: androidInit, iOS: iosInit);
    await _plugin.initialize(initSettings);

    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'Reminders 30 minutes before each scheduled class',
      importance: Importance.high,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  /// Schedules a repeating weekly notification 30 minutes before [entry]
  /// starts. Uses matchDateTimeComponents = dayOfWeekAndTime so it repeats
  /// every week automatically without re-scheduling each week.
  Future<void> scheduleClassReminder(TimetableEntry entry) async {
    final startParts = entry.startTime.split(':');
    if (startParts.length != 2) return;
    final hour = int.tryParse(startParts[0]);
    final minute = int.tryParse(startParts[1]);
    if (hour == null || minute == null) return;

    final weekday = _weekdayNumber(entry.day);
    if (weekday == null) return;

    final now = tz.TZDateTime.now(tz.local);
    var classTime = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, hour, minute);
    // Move to the correct upcoming weekday.
    while (classTime.weekday != weekday) {
      classTime = classTime.add(const Duration(days: 1));
    }
    final reminderTime = classTime.subtract(const Duration(minutes: 30));

    await _plugin.zonedSchedule(
      entry.notificationId,
      '${entry.moduleName} starts in 30 minutes',
      '${entry.moduleCode.isNotEmpty ? '${entry.moduleCode} • ' : ''}'
          '${entry.venue.isNotEmpty ? 'Venue: ${entry.venue} • ' : ''}'
          'Starts at ${entry.startTime}',
      reminderTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  Future<void> scheduleAll(List<TimetableEntry> entries) async {
    for (final e in entries) {
      await scheduleClassReminder(e);
    }
  }

  Future<void> cancelAll() async => _plugin.cancelAll();

  int? _weekdayNumber(String day) {
    const map = {
      'Monday': DateTime.monday,
      'Tuesday': DateTime.tuesday,
      'Wednesday': DateTime.wednesday,
      'Thursday': DateTime.thursday,
      'Friday': DateTime.friday,
      'Saturday': DateTime.saturday,
      'Sunday': DateTime.sunday,
    };
    return map[day];
  }
}
