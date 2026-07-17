import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/timetable_entry.dart';

class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _channelId = 'class_reminders';
  static const _channelName = 'Class Reminders';
  static const _announcementChannelId = 'lms_announcements';
  static const _announcementChannelName = 'LMS Announcements';

  Future<void> init() async {
    tz_data.initializeTimeZones();
    try {
      // Fixed: Removed explicit String type to avoid type mismatch with TimezoneInfo
      final timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName.toString()));
    } catch (e) {
      // Fallback if it fails
    }

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

    const announcementChannel = AndroidNotificationChannel(
      _announcementChannelId,
      _announcementChannelName,
      description: 'New announcements imported from CourseWeb',
      importance: Importance.high,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(announcementChannel);

    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  /// Schedules a repeating weekly notification 30 minutes before [entry]
  /// starts. Uses matchDateTimeComponents = dayOfWeekAndTime so it repeats
  /// every week automatically without re-scheduling each week.
  Future<void> scheduleClassReminder(TimetableEntry entry, int minutes, int notificationId) async {
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
    final reminderTime = classTime.subtract(Duration(minutes: minutes));

    await _plugin.zonedSchedule(
      notificationId,
      '${entry.moduleName} starts in $minutes minutes',
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
    await cancelAll();

    final prefs = await SharedPreferences.getInstance();
    final reminderMinutes = prefs.getInt('notification_time') ?? 30;

    for (final e in entries) {
      await scheduleClassReminder(e, reminderMinutes, e.notificationId);
      if (reminderMinutes != 5) {
        await scheduleClassReminder(e, 5, e.notificationId + 100000);
      }
    }
  }

  Future<void> showAnnouncementsImportedNotification(int count) async {
    await _plugin.show(
      // Fixed id so repeated imports update/replace the same notification
      // instead of piling up.
      9001,
      count == 1 ? 'New announcement' : '$count new announcements',
      'Tap to view what\'s new on CourseWeb.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _announcementChannelId,
          _announcementChannelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
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
