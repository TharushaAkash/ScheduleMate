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

  final gsi.GoogleSignIn _googleSignIn = gsi.GoogleSignIn.instance;

  gsi.GoogleSignInAccount? _currentUser;
  gsi.GoogleSignInAccount? get currentUser => _currentUser;

  bool get isSignedIn => _currentUser != null;

  Future<void> init() async {
    await _googleSignIn.initialize();
    
    _googleSignIn.authenticationEvents.listen((event) {
      if (event is gsi.GoogleSignInAuthenticationEventSignIn) {
        _currentUser = event.user;
        _saveProfileData(event.user);
      } else if (event is gsi.GoogleSignInAuthenticationEventSignOut) {
        _currentUser = null;
        _saveProfileData(null);
      }
      notifyListeners();
    });

    try {
      await _googleSignIn.attemptLightweightAuthentication();
    } catch (e) {
      debugPrint('Silent sign in failed: $e');
    }
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
      final account = await _googleSignIn.authenticate(scopeHint: [drive.DriveApi.driveAppdataScope]);
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
      await _googleSignIn.disconnect();
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

    final authHeaders = await account.authorizationClient.authorizationHeaders(
      [drive.DriveApi.driveAppdataScope],
      promptIfNecessary: true,
    );
    if (authHeaders == null) return null;

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
    }

    return true;
  }
}
