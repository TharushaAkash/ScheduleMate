/// A single module/course result within a semester.
class Course {
  int? id;
  int semesterId; // FK -> Semester.id
  String moduleCode;
  String moduleName;
  double creditHours;
  String grade; // e.g. "A+", "B-", "C"

  Course({
    this.id,
    required this.semesterId,
    required this.moduleCode,
    required this.moduleName,
    required this.creditHours,
    required this.grade,
  });

  /// Standard 4.0 grade point scale (common in SL university SE programmes).
  /// Adjust here if your faculty uses a different scale.
  static const Map<String, double> gradePoints = {
    'A+': 4.0,
    'A': 4.0,
    'A-': 3.7,
    'B+': 3.3,
    'B': 3.0,
    'B-': 2.7,
    'C+': 2.3,
    'C': 2.0,
    'C-': 1.7,
    'D+': 1.3,
    'D': 1.0,
    'E': 0.0,
    'F': 0.0,
  };

  double get gradePoint => gradePoints[grade] ?? 0.0;

  double get qualityPoints => gradePoint * creditHours;

  Map<String, dynamic> toMap() => {
        'id': id,
        'semesterId': semesterId,
        'moduleCode': moduleCode,
        'moduleName': moduleName,
        'creditHours': creditHours,
        'grade': grade,
      };

  factory Course.fromMap(Map<String, dynamic> map) => Course(
        id: map['id'] as int?,
        semesterId: map['semesterId'] as int,
        moduleCode: map['moduleCode'] as String,
        moduleName: map['moduleName'] as String,
        creditHours: (map['creditHours'] as num).toDouble(),
        grade: map['grade'] as String,
      );
}
