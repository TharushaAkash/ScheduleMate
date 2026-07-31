class ExamTimetableEntry {
  int? id;
  String subjectCode;
  String subjectName;
  String location;
  String date;
  String time;
  String seatNo;
  String sessionNo;
  String examType;

  ExamTimetableEntry({
    this.id,
    required this.subjectCode,
    required this.subjectName,
    required this.location,
    required this.date,
    required this.time,
    required this.seatNo,
    required this.sessionNo,
    this.examType = 'Final Exam',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'subjectCode': subjectCode,
      'subjectName': subjectName,
      'location': location,
      'date': date,
      'time': time,
      'dateAndTime': '$date $time', // Legacy field for SQLite NOT NULL constraint
      'seatNo': seatNo,
      'sessionNo': sessionNo,
      'examType': examType,
    };
  }

  factory ExamTimetableEntry.fromMap(Map<String, dynamic> map) {
    return ExamTimetableEntry(
      id: map['id'] as int?,
      subjectCode: map['subjectCode'] ?? '',
      subjectName: map['subjectName'] ?? '',
      location: map['location'] ?? '',
      date: map['date'] ?? map['dateAndTime'] ?? '', // Fallback to old format if 'date' missing
      time: map['time'] ?? '',
      seatNo: map['seatNo'] ?? '',
      sessionNo: map['sessionNo'] ?? '',
      examType: map['examType'] ?? 'Final Exam',
    );
  }
}
