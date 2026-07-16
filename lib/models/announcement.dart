/// One LMS announcement/forum post imported from CourseWeb (Moodle).
class Announcement {
  int? id;
  String title;
  String snippet;
  String author;
  String dateText; // raw text as shown on CourseWeb, e.g. "Mon, 14 Jul 2026, 9:03 AM"
  String sourceUrl; // page it was imported from, so user can open it again
  String courseLabel; // e.g. course/forum name shown on the page, if found
  DateTime importedAt;
  bool isRead;

  Announcement({
    this.id,
    required this.title,
    required this.snippet,
    required this.author,
    required this.dateText,
    required this.sourceUrl,
    required this.courseLabel,
    required this.importedAt,
    this.isRead = false,
  });

  /// A stable-ish key used to de-duplicate the same post across re-imports.
  String get dedupeKey => '$title|$author|$dateText'.trim();

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'snippet': snippet,
        'author': author,
        'dateText': dateText,
        'sourceUrl': sourceUrl,
        'courseLabel': courseLabel,
        'importedAt': importedAt.toIso8601String(),
        'isRead': isRead ? 1 : 0,
      };

  factory Announcement.fromMap(Map<String, dynamic> map) => Announcement(
        id: map['id'] as int?,
        title: map['title'] as String,
        snippet: map['snippet'] as String,
        author: map['author'] as String,
        dateText: map['dateText'] as String,
        sourceUrl: map['sourceUrl'] as String,
        courseLabel: map['courseLabel'] as String,
        importedAt: DateTime.parse(map['importedAt'] as String),
        isRead: (map['isRead'] as int) == 1,
      );
}
