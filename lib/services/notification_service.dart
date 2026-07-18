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
      final timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName.toString()));
    } catch (e) {
      // Fallback to Sri Lanka IST
      try {
        tz.setLocalLocation(tz.getLocation('Asia/Colombo'));
      } catch (_) {}
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings =
        InitializationSettings(android: androidInit, iOS: iosInit);
    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {},
    );

    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'Reminders 30 minutes before each scheduled class',
      importance: Importance.high,
    );
    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidImpl?.createNotificationChannel(androidChannel);

    // Request notification permission on Android 13+
    await androidImpl?.requestNotificationsPermission();
    // Request exact alarm permission (Android 12+)
    await androidImpl?.requestExactAlarmsPermission();

    const announcementChannel = AndroidNotificationChannel(
      _announcementChannelId,
      _announcementChannelName,
      description: 'New announcements imported from CourseWeb',
      importance: Importance.high,
    );
    await androidImpl?.createNotificationChannel(announcementChannel);

    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }


  /// Returns true if the app can schedule exact alarms on this device.
  Future<bool> canScheduleExactAlarms() async {
    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl == null) return false;
    return await androidImpl.canScheduleExactNotifications() ?? false;
  }

  /// Schedules a repeating weekly notification before [entry] starts.
  /// Returns the exact [tz.TZDateTime] the alarm was scheduled for (for debug).
  Future<tz.TZDateTime?> scheduleClassReminder(
      TimetableEntry entry, int minutes, int notificationId) async {
    final startParts = entry.startTime.split(':');
    if (startParts.length != 2) return null;
    final hour = int.tryParse(startParts[0]);
    final minute = int.tryParse(startParts[1]);
    if (hour == null || minute == null) return null;

    final weekday = _weekdayNumber(entry.day);
    if (weekday == null) return null;

    final now = tz.TZDateTime.now(tz.local);
    var classTime = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, hour, minute);
    // Move to the correct upcoming weekday.
    while (classTime.weekday != weekday) {
      classTime = classTime.add(const Duration(days: 1));
    }
    var reminderTime = classTime.subtract(Duration(minutes: minutes));
    // If the reminder time is already in the past, jump to next week's occurrence.
    if (reminderTime.isBefore(now)) {
      reminderTime = reminderTime.add(const Duration(days: 7));
    }

    final title = minutes == 0
        ? '${entry.moduleName} is starting now!'
        : '${entry.moduleName} starts in $minutes minutes';

    // Format fire time for display: e.g. "Fri 11:25"
    final _weekdays = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dayLabel = _weekdays[reminderTime.weekday];
    final fireHH = reminderTime.hour.toString().padLeft(2, '0');
    final fireMM = reminderTime.minute.toString().padLeft(2, '0');
    final fireLabel = '$dayLabel $fireHH:$fireMM';

    await _plugin.zonedSchedule(
      notificationId,
      title,
      '${entry.moduleCode.isNotEmpty ? '${entry.moduleCode} • ' : ''}'
          '${entry.venue.isNotEmpty ? 'Venue: ${entry.venue} • ' : ''}'
          'Class at ${entry.startTime} | Alarm: $fireLabel',
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
      // Use alarmClock only if exact alarm permission is granted.
      // Fall back to exactAllowWhileIdle which works without special permission.
      androidScheduleMode: await canScheduleExactAlarms()
          ? AndroidScheduleMode.alarmClock
          : AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );

    return reminderTime;
  }

  /// Schedules all reminders and returns a debug summary string.
  Future<String> scheduleAll(List<TimetableEntry> entries) async {
    await cancelAll();

    final prefs = await SharedPreferences.getInstance();
    final reminderMinutes = prefs.getInt('notification_time') ?? 30;

    int scheduled = 0;
    final List<String> skipped = [];
    final List<String> alarmLines = [];

    for (final e in entries) {
      final weekday = _weekdayNumber(e.day);
      if (weekday == null) {
        skipped.add('${e.day} ${e.startTime} [unknown day]');
        continue;
      }

      // Skip entries with invalid/empty start time (e.g. "00:00" = parse error)
      if (e.startTime == '00:00' || e.startTime.isEmpty) {
        skipped.add('${e.day} [invalid time "${e.startTime}"]');
        continue;
      }

      // Main reminder (user-configured minutes)
      final mainTime =
          await scheduleClassReminder(e, reminderMinutes, e.notificationId);
      // 5-min reminder (always, unless user picked 5)
      if (reminderMinutes != 5) {
        await scheduleClassReminder(e, 5, e.notificationId + 100000);
      }
      // At-class-start reminder
      await scheduleClassReminder(e, 0, e.notificationId + 200000);

      scheduled++;
      if (mainTime != null) {
        final hh = mainTime.hour.toString().padLeft(2, '0');
        final mm = mainTime.minute.toString().padLeft(2, '0');
        final _wd = ['','Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
        final alarmDay = _wd[mainTime.weekday];
        alarmLines.add('${e.day.substring(0, 3)} ${e.startTime} -> alarm $alarmDay $hh:$mm');
      }
    }

    // Debug notification: shows exact scheduled alarm times per class
    final tzName = tz.local.name;
    final exactOk = await canScheduleExactAlarms();
    final modeLabel = exactOk ? '[OK] AlarmClock' : '[!] ExactWhileIdle (grant Alarms permission!)';
    final skippedText =
        skipped.isEmpty ? '' : '\nSkipped: ${skipped.join(', ')}';
    final alarmSummary = alarmLines.take(5).join('\n');
    final moreText = alarmLines.length > 5
        ? '\n+${alarmLines.length - 5} more…'
        : '';
    final fullBody =
        'Mode: $modeLabel\nTZ: $tzName | ${reminderMinutes}min reminders\n$alarmSummary$moreText$skippedText';

    await _plugin.show(
      7999,
      'Scheduled $scheduled / ${entries.length} classes ✅',
      fullBody,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          // Pass fullBody here so BigText actually shows multiline content
          styleInformation: BigTextStyleInformation(fullBody),
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );

    // Return summary for the in-app snackbar
    return 'Scheduled $scheduled classes | $modeLabel\n'
        '${reminderMinutes}min + 5min + at-start reminders\n'
        '${alarmLines.take(3).join("\n")}'
        '${alarmLines.length > 3 ? "\n+${alarmLines.length - 3} more" : ''}';
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

  Future<void> showTestNotification() async {
    await _plugin.show(
      8000,
      'Test Notification',
      'If you see this, notifications are working perfectly!',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
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
