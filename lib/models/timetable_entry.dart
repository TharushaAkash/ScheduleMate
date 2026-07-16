/// One scheduled class, parsed from the uploaded HTML timetable.
class TimetableEntry {
  int? id;
  String semester;
  String group;
  String subGroup;
  String day; // "Monday".."Sunday"
  String startTime; // "08:30" (24h HH:mm)
  String endTime; // "10:30"
  String moduleCode;
  String moduleName;
  String venue;
  String lecturer;

  TimetableEntry({
    this.id,
    required this.semester,
    required this.group,
    required this.subGroup,
    required this.day,
    required this.startTime,
    required this.endTime,
    required this.moduleCode,
    required this.moduleName,
    required this.venue,
    required this.lecturer,
  });

  /// A stable-ish int id used to schedule a unique local notification
  /// for this class slot (day + time + module all factor in).
  int get notificationId =>
      '$day$startTime$moduleCode'.hashCode & 0x7fffffff;

  Map<String, dynamic> toMap() => {
        'id': id,
        'semester': semester,
        'groupName': group, // Using groupName in DB
        'subGroup': subGroup,
        'day': day,
        'startTime': startTime,
        'endTime': endTime,
        'moduleCode': moduleCode,
        'moduleName': moduleName,
        'venue': venue,
        'lecturer': lecturer,
      };

  factory TimetableEntry.fromMap(Map<String, dynamic> map) => TimetableEntry(
        id: map['id'] as int?,
        semester: map['semester'] as String,
        group: map['groupName'] as String,
        subGroup: map['subGroup'] as String,
        day: map['day'] as String,
        startTime: map['startTime'] as String,
        endTime: map['endTime'] as String,
        moduleCode: map['moduleCode'] as String,
        moduleName: map['moduleName'] as String,
        venue: map['venue'] as String,
        lecturer: map['lecturer'] as String,
      );
}
