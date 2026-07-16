import 'package:flutter/foundation.dart';

import '../models/course.dart';
import '../models/semester.dart';
import '../services/database_helper.dart';

class GpaProvider extends ChangeNotifier {
  List<Semester> _semesters = [];
  List<Semester> get semesters => _semesters;

  double get cumulativeGpa => CumulativeGpaCalculator.calculate(_semesters);

  Future<void> loadSemesters() async {
    _semesters = await DatabaseHelper.instance.getSemesters();
    notifyListeners();
  }

  Future<void> addSemester(int year, int semesterNumber) async {
    final id = await DatabaseHelper.instance
        .insertSemester(Semester(year: year, semesterNumber: semesterNumber));
    _semesters.add(Semester(id: id, year: year, semesterNumber: semesterNumber));
    notifyListeners();
  }

  Future<void> addCourse(int semesterId, Course course) async {
    final id = await DatabaseHelper.instance.insertCourse(course);
    final semester = _semesters.firstWhere((s) => s.id == semesterId);
    semester.courses.add(Course(
      id: id,
      semesterId: semesterId,
      moduleCode: course.moduleCode,
      moduleName: course.moduleName,
      creditHours: course.creditHours,
      grade: course.grade,
    ));
    notifyListeners();
  }

  Future<void> deleteCourse(int semesterId, int courseId) async {
    await DatabaseHelper.instance.deleteCourse(courseId);
    final semester = _semesters.firstWhere((s) => s.id == semesterId);
    semester.courses.removeWhere((c) => c.id == courseId);
    notifyListeners();
  }

  Future<void> deleteSemester(int semesterId) async {
    await DatabaseHelper.instance.deleteSemester(semesterId);
    _semesters.removeWhere((s) => s.id == semesterId);
    notifyListeners();
  }
}
