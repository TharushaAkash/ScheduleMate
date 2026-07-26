import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/announcement.dart';
import '../models/course.dart';
import '../models/semester.dart';
import '../models/timetable_entry.dart';

class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'gpa_timetable_app.db');
    return openDatabase(
      path,
      version: 4,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 3) {
          await db.execute('DROP TABLE IF EXISTS timetable_entries');
          await db.execute('DROP TABLE IF EXISTS courses');
          await db.execute('DROP TABLE IF EXISTS semesters');
          await _createTables(db);
          await _createAnnouncementsTable(db);
        }
        if (oldVersion < 4) {
          await _createBlockedAnnouncementsTable(db);
        }
      },
      onCreate: (db, version) async {
        await _createTables(db);
        await _createAnnouncementsTable(db);
        await _createBlockedAnnouncementsTable(db);
      },
    );
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
          CREATE TABLE semesters (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            year INTEGER NOT NULL,
            semesterNumber INTEGER NOT NULL
          )
        ''');
    await db.execute('''
          CREATE TABLE courses (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            semesterId INTEGER NOT NULL,
            moduleCode TEXT NOT NULL,
            moduleName TEXT NOT NULL,
            creditHours REAL NOT NULL,
            grade TEXT NOT NULL,
            FOREIGN KEY (semesterId) REFERENCES semesters (id) ON DELETE CASCADE
          )
        ''');
    await db.execute('''
          CREATE TABLE timetable_entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            semester TEXT NOT NULL,
            groupName TEXT NOT NULL,
            subGroup TEXT NOT NULL,
            day TEXT NOT NULL,
            startTime TEXT NOT NULL,
            endTime TEXT NOT NULL,
            moduleCode TEXT NOT NULL,
            moduleName TEXT NOT NULL,
            venue TEXT NOT NULL,
            lecturer TEXT NOT NULL
          )
        ''');
  }

  Future<void> _createAnnouncementsTable(Database db) async {
    await db.execute('''
          CREATE TABLE IF NOT EXISTS announcements (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            snippet TEXT NOT NULL,
            author TEXT NOT NULL,
            dateText TEXT NOT NULL,
            sourceUrl TEXT NOT NULL,
            courseLabel TEXT NOT NULL,
            importedAt TEXT NOT NULL,
            isRead INTEGER NOT NULL DEFAULT 0,
            dedupeKey TEXT UNIQUE
          )
        ''');
  }

  Future<void> _createBlockedAnnouncementsTable(Database db) async {
    await db.execute('''
          CREATE TABLE IF NOT EXISTS blocked_announcement_keys (
            dedupeKey TEXT PRIMARY KEY
          )
        ''');
  }

  // ---------- Announcements ----------
  Future<int> insertAnnouncementIfNew(Announcement a) async {
    final db = await database;
    try {
      // Check if this key was previously deleted (blocked)
      final blocked = await db.query(
        'blocked_announcement_keys',
        where: 'dedupeKey = ?',
        whereArgs: [a.dedupeKey],
      );
      if (blocked.isNotEmpty) return 0;

      return await db.insert(
        'announcements',
        {...a.toMap()..remove('id'), 'dedupeKey': a.dedupeKey},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    } catch (_) {
      return 0;
    }
  }

  Future<List<Announcement>> getAnnouncements() async {
    final db = await database;
    final rows = await db.query('announcements', orderBy: 'id DESC');
    return rows.map((r) => Announcement.fromMap(r)).toList();
  }

  Future<void> markAnnouncementRead(int id) async {
    final db = await database;
    await db.update('announcements', {'isRead': 1},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> markAllAnnouncementsRead() async {
    final db = await database;
    await db.update('announcements', {'isRead': 1});
  }

  Future<void> deleteAnnouncement(int id) async {
    final db = await database;
    // First, save the dedupeKey to the blocked list so it won't re-appear on next fetch
    final rows = await db.query('announcements', where: 'id = ?', whereArgs: [id]);
    if (rows.isNotEmpty) {
      final key = rows.first['dedupeKey'] as String?;
      if (key != null && key.isNotEmpty) {
        await db.insert(
          'blocked_announcement_keys',
          {'dedupeKey': key},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    }
    await db.delete('announcements', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearAnnouncements() async {
    final db = await database;
    await db.delete('announcements');
  }


  Future<int> insertSemester(Semester s) async {
    final db = await database;
    return db.insert('semesters', s.toMap()..remove('id'));
  }

  Future<List<Semester>> getSemesters() async {
    final db = await database;
    final rows = await db.query('semesters', orderBy: 'year, semesterNumber');
    final semesters = rows.map((r) => Semester.fromMap(r)).toList();
    for (final s in semesters) {
      s.courses = await getCoursesForSemester(s.id!);
    }
    return semesters;
  }

  Future<void> deleteSemester(int id) async {
    final db = await database;
    await db.delete('courses', where: 'semesterId = ?', whereArgs: [id]);
    await db.delete('semesters', where: 'id = ?', whereArgs: [id]);
  }

  // ---------- Courses ----------
  Future<int> insertCourse(Course c) async {
    final db = await database;
    return db.insert('courses', c.toMap()..remove('id'));
  }

  Future<List<Course>> getCoursesForSemester(int semesterId) async {
    final db = await database;
    final rows = await db.query('courses',
        where: 'semesterId = ?', whereArgs: [semesterId]);
    return rows.map((r) => Course.fromMap(r)).toList();
  }

  Future<void> deleteCourse(int id) async {
    final db = await database;
    await db.delete('courses', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateCourse(Course c) async {
    final db = await database;
    await db.update('courses', c.toMap(), where: 'id = ?', whereArgs: [c.id]);
  }

  // ---------- Timetable ----------
  Future<void> replaceTimetableEntries(List<TimetableEntry> entries) async {
    final db = await database;
    final batch = db.batch();
    // Clear entries for the (semester, group) combos being replaced,
    // so multiple groups/years can coexist locally, but old garbage sub-groups are removed.
    final keys = entries
        .map((e) => '${e.semester}|${e.group}')
        .toSet();
    for (final key in keys) {
      final parts = key.split('|');
      batch.delete('timetable_entries',
          where: 'semester = ? AND groupName = ?',
          whereArgs: [parts[0], parts[1]]);
    }
    for (final e in entries) {
      batch.insert('timetable_entries', e.toMap()..remove('id'));
    }
    await batch.commit(noResult: true);
  }

  Future<List<TimetableEntry>> getTimetable(
      String semester, String groupName, String subGroup) async {
    final db = await database;
    final rows = await db.query(
      'timetable_entries',
      where: 'semester = ? AND groupName = ? AND (subGroup = ? OR subGroup = ? OR subGroup LIKE ? OR subGroup LIKE ?)',
      whereArgs: [semester, groupName, subGroup, groupName, '%$subGroup%', '%$groupName%'],
    );
    return rows.map((r) => TimetableEntry.fromMap(r)).toList();
  }

  Future<List<Map<String, String>>> getSavedTimetableProfiles() async {
    final db = await database;
    final rows = await db.rawQuery('SELECT DISTINCT semester, groupName, subGroup FROM timetable_entries');
    
    final map = <String, Map<String, String>>{};
    for (final r in rows) {
      final s = r['semester'] as String;
      final g = r['groupName'] as String;
      final sg = r['subGroup'] as String;
      final key = '$s|$g';
      
      if (!map.containsKey(key)) {
        map[key] = {'semester': s, 'groupName': g, 'subGroup': sg};
      } else {
        if (sg != g && sg.isNotEmpty && !sg.contains(',')) {
           map[key]!['subGroup'] = sg;
        }
      }
    }
    return map.values.toList();
  }

  Future<void> deleteTimetableProfile(String semester, String groupName) async {
    final db = await database;
    await db.delete(
      'timetable_entries',
      where: 'semester = ? AND groupName = ?',
      whereArgs: [semester, groupName],
    );
  }

  Future<void> updateTimetableEntry(TimetableEntry entry) async {
    final db = await database;
    await db.update(
      'timetable_entries',
      entry.toMap(),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }
}
