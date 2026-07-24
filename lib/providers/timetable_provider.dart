import 'package:flutter/foundation.dart';

import '../models/timetable_entry.dart';
import '../services/database_helper.dart';
import '../services/notification_service.dart';
import '../services/timetable_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TimetableProvider extends ChangeNotifier {
  ParsedTimetable? _parsed;
  String? selectedSemester;
  String? selectedGroup;
  String? selectedSubGroup;
  List<TimetableEntry> currentTimetable = [];
  List<TimetableEntry> notifiedTimetable = [];

  bool get hasParsedData => _parsed != null && _parsed!.entries.isNotEmpty;

  List<String> get availableSemesters {
    if (_parsed == null) return [];
    return _parsed!.entries.map((e) => e.semester).toSet().toList()..sort();
  }

  List<String> getAvailableGroups(String semester) {
    if (_parsed == null) return [];
    return _parsed!.entries
        .where((e) => e.semester == semester)
        .map((e) => e.group)
        .toSet()
        .toList()
        ..sort();
  }

  List<String> getAvailableSubGroups(String semester, String group) {
    if (_parsed == null) return [];
    final allSubGroups = _parsed!.entries
        .where((e) => e.semester == semester && e.group == group)
        .map((e) => e.subGroup)
        .toSet()
        .toList();
    
    // Remove the main group and empty names from the sub-group list if there are actual sub-groups
    final actualSubGroups = allSubGroups.where((sg) => sg != group && sg.isNotEmpty && !sg.contains(',')).toList();
    if (actualSubGroups.isNotEmpty) {
      actualSubGroups.sort();
      return actualSubGroups;
    }
    
    // If no actual sub-groups, return whatever is there
    allSubGroups.sort();
    return allSubGroups;
  }

  Future<void> loadFromHtml(String htmlContent) async {
    _parsed = TimetableParser.parse(htmlContent);
    notifyListeners();
  }

  Future<void> loadNotifiedTimetable() async {
    final prefs = await SharedPreferences.getInstance();
    final semester = prefs.getString('notified_semester');
    final group = prefs.getString('notified_group');
    final subGroup = prefs.getString('notified_subgroup');

    if (semester != null && group != null && subGroup != null) {
      notifiedTimetable =
          await DatabaseHelper.instance.getTimetable(semester, group, subGroup);
    } else {
      notifiedTimetable = [];
    }
    notifyListeners();
  }

  Future<void> selectTimetable(String semester, String group, String subGroup) async {
    selectedSemester = semester;
    selectedGroup = group;
    selectedSubGroup = subGroup;

    final entries = _parsed!.filter(semester, group, subGroup);
    currentTimetable = entries;

    await DatabaseHelper.instance.replaceTimetableEntries(entries);

    // Save the notification prefs so scheduleReminders() can find them.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('notified_semester', semester);
    await prefs.setString('notified_group', group);
    await prefs.setString('notified_subgroup', subGroup);

    await loadNotifiedTimetable();
  }

  Future<void> updateEntry(TimetableEntry updatedEntry) async {
    final index = currentTimetable.indexWhere((e) => e.id == updatedEntry.id);
    if (index != -1) {
      currentTimetable[index] = updatedEntry;
      await DatabaseHelper.instance.updateTimetableEntry(updatedEntry);
      // Re-schedule notifications so edited times take effect immediately.
      await scheduleReminders();
      await loadNotifiedTimetable();
      notifyListeners();
    }
  }

  Future<void> loadSavedTimetable(String semester, String groupName, String subGroup) async {
    selectedSemester = semester;
    selectedGroup = groupName;
    selectedSubGroup = subGroup;
    currentTimetable =
        await DatabaseHelper.instance.getTimetable(semester, groupName, subGroup);
    notifyListeners();
  }

  Future<void> loadDefaultTimetable() async {
    await loadNotifiedTimetable();

    if (currentTimetable.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final semester = prefs.getString('notified_semester');
      final group = prefs.getString('notified_group');
      final subGroup = prefs.getString('notified_subgroup');

      if (semester != null && group != null && subGroup != null && notifiedTimetable.isNotEmpty) {
        selectedSemester = semester;
        selectedGroup = group;
        selectedSubGroup = subGroup;
        currentTimetable = List.from(notifiedTimetable);
      } else {
        final profiles = await DatabaseHelper.instance.getSavedTimetableProfiles();
        if (profiles.isNotEmpty) {
          final p = profiles.first;
          await loadSavedTimetable(p['semester']!, p['groupName']!, p['subGroup']!);
        }
      }
    }
  }

  /// Schedules reminders for the currently notified timetable profile.
  /// Returns a debug summary string (alarm times per class) for display.
  Future<String?> scheduleReminders() async {
    final prefs = await SharedPreferences.getInstance();
    final semester = prefs.getString('notified_semester');
    final group = prefs.getString('notified_group');
    final subGroup = prefs.getString('notified_subgroup');
    if (semester == null || group == null || subGroup == null) {
      // No timetable selected for notifications yet — nothing to do.
      return null;
    }
    final entries = await DatabaseHelper.instance.getTimetable(semester, group, subGroup);
    if (entries.isEmpty) return null;
    return await NotificationService.instance.scheduleAll(entries);
  }

  /// Groups the current timetable's classes by day for card display,
  /// in Monday -> Sunday order.
  Map<String, List<TimetableEntry>> get groupedByDay {
    const order = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    final map = <String, List<TimetableEntry>>{};
    for (final day in order) {
      final dayEntries = currentTimetable.where((e) => e.day == day).toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime));
      if (dayEntries.isNotEmpty) map[day] = dayEntries;
    }
    return map;
  }
}
