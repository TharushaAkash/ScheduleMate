import 'dart:io';
import 'package:gpa_timetable_app/services/timetable_parser.dart';

void main() async {
  final file = File('C:/Users/Tharusha/Downloads/Telegram Desktop/Student_Timetable_for_Semester_II_July_2026_Weekday_Version_II.html');
  final html = await file.readAsString();
  final parsed = TimetableParser.parse(html);
  
  final entries = parsed.filter('Y2.S1', 'Y2.S1.WD.COM.01', 'Y2.S1.WD.COM.0101');
  
  for (final e in entries) {
    print('${e.day} ${e.startTime}-${e.endTime} | ${e.moduleCode} ${e.moduleName} | ${e.lecturer} | ${e.venue} (sub: ${e.subGroup})');
  }
}
