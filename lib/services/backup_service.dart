import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart' as gsi;
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }
}

class BackupService extends ChangeNotifier {
  BackupService._internal();
  static final BackupService instance = BackupService._internal();

  final gsi.GoogleSignIn googleSignIn = gsi.GoogleSignIn(
    scopes: [
      'email',
      'profile',
      drive.DriveApi.driveAppdataScope,
      drive.DriveApi.driveScope,
    ],
  );

  gsi.GoogleSignInAccount? _currentUser;
  gsi.GoogleSignInAccount? get currentUser => _currentUser;

  bool get isSignedIn => _currentUser != null;

  DateTime? _lastBackupTime;
  DateTime? get lastBackupTime => _lastBackupTime;

  DateTime? _lastRestoreTime;
  DateTime? get lastRestoreTime => _lastRestoreTime;

  Future<void> init() async {
    googleSignIn.onCurrentUserChanged.listen((account) {
      _currentUser = account;
      _saveProfileData(account);
      notifyListeners();
    });

    try {
      final account = await googleSignIn.signInSilently();
      if (account != null) {
        _currentUser = account;
        await _saveProfileData(account);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Silent sign in failed: $e');
    }

    // Load saved timestamps
    final prefs = await SharedPreferences.getInstance();
    final backupMs = prefs.getInt('last_backup_time');
    final restoreMs = prefs.getInt('last_restore_time');
    if (backupMs != null) _lastBackupTime = DateTime.fromMillisecondsSinceEpoch(backupMs);
    if (restoreMs != null) _lastRestoreTime = DateTime.fromMillisecondsSinceEpoch(restoreMs);
  }

  Future<void> _saveProfileData(gsi.GoogleSignInAccount? account) async {
    final prefs = await SharedPreferences.getInstance();
    if (account != null) {
      await prefs.setString('google_display_name', account.displayName ?? '');
      await prefs.setString('google_photo_url', account.photoUrl ?? '');
    } else {
      await prefs.remove('google_display_name');
      await prefs.remove('google_photo_url');
    }
  }

  Future<void> signIn() async {
    try {
      final account = await googleSignIn.signIn();
      _currentUser = account;
      await _saveProfileData(account);
      notifyListeners();
    } catch (e) {
      debugPrint("Sign in failed: $e");
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await googleSignIn.disconnect();
      _currentUser = null;
      await _saveProfileData(null);
      notifyListeners();
    } catch (e) {
      debugPrint("Sign out failed: $e");
    }
  }

  Future<drive.DriveApi?> _getDriveApi() async {
    final account = _currentUser;
    if (account == null) return null;

    final authHeaders = await account.authHeaders;

    final authClient = GoogleAuthClient(authHeaders);
    return drive.DriveApi(authClient);
  }

  Future<void> backupDatabase() async {
    final api = await _getDriveApi();
    if (api == null) throw Exception("Not signed in or scopes not granted");

    final dbPath = await getDatabasesPath();
    final dbFile = File(p.join(dbPath, 'gpa_timetable_app.db'));

    if (!await dbFile.exists()) {
      throw Exception("Database file not found");
    }

    final queryDb = "name = 'gpa_timetable_app_backup.db' and 'appDataFolder' in parents and trashed = false";
    final fileListDb = await api.files.list(q: queryDb, spaces: 'appDataFolder');

    String? dbFileId;
    if (fileListDb.files != null && fileListDb.files!.isNotEmpty) {
      dbFileId = fileListDb.files!.first.id;
    }

    final mediaDb = drive.Media(dbFile.openRead(), dbFile.lengthSync());
    final driveFileDb = drive.File()
      ..name = 'gpa_timetable_app_backup.db'
      ..parents = ['appDataFolder'];

    if (dbFileId != null) {
      await api.files.update(drive.File(), dbFileId, uploadMedia: mediaDb);
    } else {
      await api.files.create(driveFileDb, uploadMedia: mediaDb);
    }

    // Backup SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final prefsData = {
      'student_id': prefs.getString('student_id') ?? '',
      'student_name': prefs.getString('student_name') ?? '',
      'saved_ca_marks': prefs.getString('saved_ca_marks') ?? '',
      'assignments_data': prefs.getString('assignments_data') ?? '',
    };
    final prefsJson = jsonEncode(prefsData);
    
    final queryPrefs = "name = 'gpa_timetable_app_prefs.json' and 'appDataFolder' in parents and trashed = false";
    final fileListPrefs = await api.files.list(q: queryPrefs, spaces: 'appDataFolder');

    String? prefsFileId;
    if (fileListPrefs.files != null && fileListPrefs.files!.isNotEmpty) {
      prefsFileId = fileListPrefs.files!.first.id;
    }

    final bytes = utf8.encode(prefsJson);
    final mediaPrefs = drive.Media(Stream.value(bytes), bytes.length);
    final driveFilePrefs = drive.File()
      ..name = 'gpa_timetable_app_prefs.json'
      ..parents = ['appDataFolder'];

    if (prefsFileId != null) {
      await api.files.update(drive.File(), prefsFileId, uploadMedia: mediaPrefs);
    } else {
      await api.files.create(driveFilePrefs, uploadMedia: mediaPrefs);
    }

    // Save timestamp
    final prefs2 = await SharedPreferences.getInstance();
    _lastBackupTime = DateTime.now();
    await prefs2.setInt('last_backup_time', _lastBackupTime!.millisecondsSinceEpoch);
    notifyListeners();
  }

  Future<bool> restoreDatabase() async {
    final api = await _getDriveApi();
    if (api == null) throw Exception("Not signed in or scopes not granted");

    // Restore Database
    final queryDb = "name = 'gpa_timetable_app_backup.db' and 'appDataFolder' in parents and trashed = false";
    final fileListDb = await api.files.list(q: queryDb, spaces: 'appDataFolder');

    if (fileListDb.files != null && fileListDb.files!.isNotEmpty) {
      final dbFileId = fileListDb.files!.first.id!;
      final drive.Media mediaDb = await api.files.get(
        dbFileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final dbPath = await getDatabasesPath();
      final dbFile = File(p.join(dbPath, 'gpa_timetable_app.db'));
      
      final List<int> dataStore = [];
      await for (final chunk in mediaDb.stream) {
        dataStore.addAll(chunk);
      }
      await dbFile.writeAsBytes(dataStore, flush: true);
    } else {
      throw Exception("No DB backup found in Google Drive.");
    }

    // Restore SharedPreferences
    final queryPrefs = "name = 'gpa_timetable_app_prefs.json' and 'appDataFolder' in parents and trashed = false";
    final fileListPrefs = await api.files.list(q: queryPrefs, spaces: 'appDataFolder');

    if (fileListPrefs.files != null && fileListPrefs.files!.isNotEmpty) {
      final prefsFileId = fileListPrefs.files!.first.id!;
      final drive.Media mediaPrefs = await api.files.get(
        prefsFileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final List<int> prefsStore = [];
      await for (final chunk in mediaPrefs.stream) {
        prefsStore.addAll(chunk);
      }
      
      final prefsJson = utf8.decode(prefsStore);
      final Map<String, dynamic> prefsData = jsonDecode(prefsJson);
      
      final prefs = await SharedPreferences.getInstance();
      if (prefsData['student_id'] != null && prefsData['student_id'].toString().isNotEmpty) {
        await prefs.setString('student_id', prefsData['student_id']);
      }
      if (prefsData['student_name'] != null && prefsData['student_name'].toString().isNotEmpty) {
        await prefs.setString('student_name', prefsData['student_name']);
      }
      if (prefsData['saved_ca_marks'] != null && prefsData['saved_ca_marks'].toString().isNotEmpty) {
        await prefs.setString('saved_ca_marks', prefsData['saved_ca_marks']);
      }
      if (prefsData['assignments_data'] != null && prefsData['assignments_data'].toString().isNotEmpty) {
        await prefs.setString('assignments_data', prefsData['assignments_data']);
      }
    }

    // Save restore timestamp
    final prefs2 = await SharedPreferences.getInstance();
    _lastRestoreTime = DateTime.now();
    await prefs2.setInt('last_restore_time', _lastRestoreTime!.millisecondsSinceEpoch);
    notifyListeners();

    return true;
  }
}
