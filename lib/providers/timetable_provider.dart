import 'package:flutter/foundation.dart';

import '../models/timetable_entry.dart';
import '../services/database_helper.dart';
import '../services/notification_service.dart';
import '../services/timetable_parser.dart';

class TimetableProvider extends ChangeNotifier {
  ParsedTimetable? _parsed;
  String? selectedSemester;
  String? selectedGroup;
  String? selectedSubGroup;
  List<TimetableEntry> currentTimetable = [];

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

  Future<void> selectTimetable(String semester, String group, String subGroup) async {
    selectedSemester = semester;
    selectedGroup = group;
    selectedSubGroup = subGroup;

    final entries = _parsed!.filter(semester, group, subGroup);
    currentTimetable = entries;

    await DatabaseHelper.instance.replaceTimetableEntries(entries);
    notifyListeners();
  }

  Future<void> updateEntry(TimetableEntry updatedEntry) async {
    final index = currentTimetable.indexWhere((e) => e.id == updatedEntry.id);
    if (index != -1) {
      currentTimetable[index] = updatedEntry;
      await DatabaseHelper.instance.updateTimetableEntry(updatedEntry);
      notifyListeners();
    }
  }

  Future<void> loadSavedTimetable(String semester, String groupName, String subGroup) async {
    currentTimetable =
        await DatabaseHelper.instance.getTimetable(semester, groupName, subGroup);
    notifyListeners();
  }

  Future<void> scheduleReminders() async {
    await NotificationService.instance.scheduleAll(currentTimetable);
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
