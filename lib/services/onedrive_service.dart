import 'dart:convert';
import 'dart:io';

import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

/// OneDrive Personal integration via Microsoft Graph API.
/// Handles OAuth sign-in, file upload, and public link generation.
class OneDriveService {
  static final OneDriveService instance = OneDriveService._();
  OneDriveService._();

  // ─── IMPORTANT: Replace with your Azure App's Client ID after registration ──
  static const String clientId = 'YOUR_AZURE_CLIENT_ID';

  static const String _redirectScheme = 'com.example.gpa_timetable_app';
  static const String _redirectUri = '$_redirectScheme://auth';
  static const String _scopes = 'Files.ReadWrite offline_access User.Read';
  static const String _tokenUrl =
      'https://login.microsoftonline.com/common/oauth2/v2.0/token';
  static const String _authUrl =
      'https://login.microsoftonline.com/common/oauth2/v2.0/authorize';

  static const String _prefAccessToken = 'onedrive_access_token';
  static const String _prefRefreshToken = 'onedrive_refresh_token';
  static const String _prefExpiry = 'onedrive_token_expiry';

  String? _accessToken;
  String? _refreshToken;
  DateTime? _expiry;
  String? _userName;
  String? _userEmail;

  String? get userName => _userName;
  String? get userEmail => _userEmail;
  bool get isSignedIn => _accessToken != null;

  // ─── Auth ────────────────────────────────────────────────────────────────────

  /// Load saved tokens from SharedPreferences.
  Future<bool> loadSavedSession() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString(_prefAccessToken);
    _refreshToken = prefs.getString(_prefRefreshToken);
    final expiryMs = prefs.getInt(_prefExpiry);
    _expiry = expiryMs != null
        ? DateTime.fromMillisecondsSinceEpoch(expiryMs)
        : null;

    if (_accessToken != null) {
      if (_isExpired()) {
        final refreshed = await _refreshAccessToken();
        if (!refreshed) {
          await signOut();
          return false;
        }
      }
      await _loadUserInfo();
      return true;
    }
    return false;
  }

  bool _isExpired() =>
      _expiry != null && DateTime.now().isAfter(_expiry!.subtract(const Duration(minutes: 5)));

  /// OAuth sign-in via browser. Returns true on success.
  Future<bool> signIn() async {
    try {
      // Try silent refresh first
      if (_refreshToken != null) {
        final refreshed = await _refreshAccessToken();
        if (refreshed) {
          await _loadUserInfo();
          return true;
        }
      }

      final authUri = Uri.parse(_authUrl).replace(queryParameters: {
        'client_id': clientId,
        'response_type': 'code',
        'redirect_uri': _redirectUri,
        'scope': _scopes,
        'response_mode': 'query',
        'prompt': 'select_account',
      });

      final result = await FlutterWebAuth2.authenticate(
        url: authUri.toString(),
        callbackUrlScheme: _redirectScheme,
      );

      final code = Uri.parse(result).queryParameters['code'];
      if (code == null) return false;

      final response = await http.post(Uri.parse(_tokenUrl), body: {
        'client_id': clientId,
        'code': code,
        'redirect_uri': _redirectUri,
        'grant_type': 'authorization_code',
        'scope': _scopes,
      });

      if (response.statusCode != 200) return false;
      final json = jsonDecode(response.body);
      await _saveTokens(json);
      await _loadUserInfo();
      return true;
    } catch (e) {
      print('OneDriveService.signIn error: $e');
      return false;
    }
  }

  Future<bool> _refreshAccessToken() async {
    if (_refreshToken == null) return false;
    try {
      final response = await http.post(Uri.parse(_tokenUrl), body: {
        'client_id': clientId,
        'refresh_token': _refreshToken!,
        'grant_type': 'refresh_token',
        'scope': _scopes,
      });
      if (response.statusCode != 200) return false;
      final json = jsonDecode(response.body);
      await _saveTokens(json);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> _saveTokens(Map<String, dynamic> json) async {
    _accessToken = json['access_token'] as String?;
    _refreshToken = json['refresh_token'] as String? ?? _refreshToken;
    final expiresIn = (json['expires_in'] as num?)?.toInt() ?? 3600;
    _expiry = DateTime.now().add(Duration(seconds: expiresIn));

    final prefs = await SharedPreferences.getInstance();
    if (_accessToken != null) await prefs.setString(_prefAccessToken, _accessToken!);
    if (_refreshToken != null) await prefs.setString(_prefRefreshToken, _refreshToken!);
    await prefs.setInt(_prefExpiry, _expiry!.millisecondsSinceEpoch);
  }

  Future<void> _loadUserInfo() async {
    final resp = await _graphGet('/me?\$select=displayName,mail,userPrincipalName');
    if (resp != null) {
      _userName = resp['displayName'] as String?;
      _userEmail = (resp['mail'] ?? resp['userPrincipalName']) as String?;
    }
  }

  Future<void> signOut() async {
    _accessToken = null;
    _refreshToken = null;
    _expiry = null;
    _userName = null;
    _userEmail = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefAccessToken);
    await prefs.remove(_prefRefreshToken);
    await prefs.remove(_prefExpiry);
  }

  // ─── Graph API Helpers ───────────────────────────────────────────────────────

  Map<String, String> get _authHeader => {'Authorization': 'Bearer $_accessToken'};

  Future<Map<String, dynamic>?> _graphGet(String path) async {
    if (_accessToken == null) return null;
    if (_isExpired()) await _refreshAccessToken();
    final resp = await http.get(
      Uri.parse('https://graph.microsoft.com/v1.0$path'),
      headers: _authHeader,
    );
    if (resp.statusCode == 200) return jsonDecode(resp.body) as Map<String, dynamic>;
    return null;
  }

  // ─── File Upload ─────────────────────────────────────────────────────────────

  /// Uploads a local file to OneDrive under /ScheduleMate/Rooms/{roomName}/
  /// Returns the public sharing URL on success, or null on failure.
  Future<String?> uploadFile(File file, {String roomFolder = 'General'}) async {
    if (_accessToken == null) return null;
    if (_isExpired()) await _refreshAccessToken();

    try {
      final fileName = p.basename(file.path);
      final fileBytes = await file.readAsBytes();
      final fileSize = fileBytes.length;

      String? itemId;

      if (fileSize <= 4 * 1024 * 1024) {
        // Small file — simple PUT upload
        final uploadUri = Uri.parse(
            'https://graph.microsoft.com/v1.0/me/drive/root:/ScheduleMate/Rooms/$roomFolder/$fileName:/content');
        final resp = await http.put(
          uploadUri,
          headers: {
            ..._authHeader,
            'Content-Type': 'application/octet-stream',
          },
          body: fileBytes,
        );
        if (resp.statusCode != 200 && resp.statusCode != 201) {
          print('OneDrive small upload failed: ${resp.statusCode} ${resp.body}');
          return null;
        }
        final json = jsonDecode(resp.body) as Map<String, dynamic>;
        itemId = json['id'] as String?;
      } else {
        // Large file — upload session
        itemId = await _largeFileUpload(file, fileBytes, roomFolder, fileName);
      }

      if (itemId == null) return null;

      // Create a public sharing link
      return await _createSharingLink(itemId);
    } catch (e) {
      print('OneDriveService.uploadFile error: $e');
      return null;
    }
  }

  Future<String?> _largeFileUpload(
      File file, List<int> fileBytes, String roomFolder, String fileName) async {
    // Create upload session
    final sessionUri = Uri.parse(
        'https://graph.microsoft.com/v1.0/me/drive/root:/ScheduleMate/Rooms/$roomFolder/$fileName:/createUploadSession');

    final sessionResp = await http.post(
      sessionUri,
      headers: {..._authHeader, 'Content-Type': 'application/json'},
      body: jsonEncode({'item': {'@microsoft.graph.conflictBehavior': 'rename'}}),
    );
    if (sessionResp.statusCode != 200) return null;

    final uploadUrl = jsonDecode(sessionResp.body)['uploadUrl'] as String?;
    if (uploadUrl == null) return null;

    // Upload in 5MB chunks
    const chunkSize = 5 * 1024 * 1024;
    final totalSize = fileBytes.length;
    String? itemId;

    for (int start = 0; start < totalSize; start += chunkSize) {
      final end = (start + chunkSize).clamp(0, totalSize);
      final chunk = fileBytes.sublist(start, end);
      final resp = await http.put(
        Uri.parse(uploadUrl),
        headers: {
          'Content-Range': 'bytes $start-${end - 1}/$totalSize',
          'Content-Length': '${chunk.length}',
        },
        body: chunk,
      );
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        itemId = jsonDecode(resp.body)['id'] as String?;
      } else if (resp.statusCode != 202) {
        return null; // Error
      }
    }
    return itemId;
  }

  Future<String?> _createSharingLink(String itemId) async {
    final resp = await http.post(
      Uri.parse('https://graph.microsoft.com/v1.0/me/drive/items/$itemId/createLink'),
      headers: {..._authHeader, 'Content-Type': 'application/json'},
      body: jsonEncode({'type': 'view', 'scope': 'anonymous'}),
    );
    if (resp.statusCode == 200 || resp.statusCode == 201) {
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      return json['link']?['webUrl'] as String?;
    }
    return null;
  }

  // ─── List files ──────────────────────────────────────────────────────────────

  /// Lists files in a given OneDrive folder path.
  Future<List<Map<String, dynamic>>> listRoomFiles(String roomFolder) async {
    final data = await _graphGet(
        '/me/drive/root:/ScheduleMate/Rooms/$roomFolder:/children?\$select=id,name,size,createdDateTime,webUrl,file,folder');
    if (data == null) return [];
    final items = data['value'] as List<dynamic>? ?? [];
    return items.cast<Map<String, dynamic>>();
  }
}
