import 'course.dart';

/// Represents one academic semester, e.g. Year 3 Semester 1.
class Semester {
  int? id;
  int year; // 1..4
  int semesterNumber; // 1 or 2
  List<Course> courses;

  Semester({
    this.id,
    required this.year,
    required this.semesterNumber,
    List<Course>? courses,
  }) : courses = courses ?? [];

  String get label => 'Year $year - Semester $semesterNumber';

  double get totalCredits =>
      courses.fold(0.0, (sum, c) => sum + c.creditHours);

  double get totalQualityPoints =>
      courses.fold(0.0, (sum, c) => sum + c.qualityPoints);

  /// GPA for just this semester.
  double get semesterGpa {
    if (totalCredits == 0) return 0.0;
    return totalQualityPoints / totalCredits;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'year': year,
        'semesterNumber': semesterNumber,
      };

  factory Semester.fromMap(Map<String, dynamic> map) => Semester(
        id: map['id'] as int?,
        year: map['year'] as int,
        semesterNumber: map['semesterNumber'] as int,
      );
}

/// Utility to compute cumulative GPA across many semesters.
class CumulativeGpaCalculator {
  static double calculate(List<Semester> semesters) {
    double totalCredits = 0;
    double totalQualityPoints = 0;
    for (final s in semesters) {
      totalCredits += s.totalCredits;
      totalQualityPoints += s.totalQualityPoints;
    }
    if (totalCredits == 0) return 0.0;
    return totalQualityPoints / totalCredits;
  }
}
