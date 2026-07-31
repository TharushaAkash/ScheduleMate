import 'dart:io';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

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

class GoogleDriveService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      drive.DriveApi.driveFileScope,
      drive.DriveApi.driveMetadataReadonlyScope,
    ],
  );

  drive.DriveApi? _driveApi;

  Future<bool> signIn() async {
    try {
      GoogleSignInAccount? account = await _googleSignIn.signInSilently();
      account ??= await _googleSignIn.signIn();
      if (account == null) return false;

      final Map<String, String> headers = await account.authHeaders;
      final authenticateClient = GoogleAuthClient(headers);
      _driveApi = drive.DriveApi(authenticateClient);
      
      return true;
    } catch (e) {
      print('Error signing in with Google: $e');
      return false;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _driveApi = null;
  }

  /// Create a new Room (Google Drive Folder) and returns the Folder ID (Key)
  Future<String?> createRoom(String roomName) async {
    if (_driveApi == null) return null;

    try {
      final drive.File folder = drive.File()
        ..name = roomName
        ..mimeType = 'application/vnd.google-apps.folder';

      final drive.File createdFolder = await _driveApi!.files.create(folder);
      final String folderId = createdFolder.id!;

      // Make the folder accessible to anyone with the link (Writer access so students can upload)
      final drive.Permission permission = drive.Permission()
        ..type = 'anyone'
        ..role = 'writer';
      
      await _driveApi!.permissions.create(permission, folderId);

      return folderId;
    } catch (e) {
      print('Error creating room: $e');
      return null;
    }
  }

  /// Create a Subfolder inside an existing Room or Folder
  Future<String?> createSubFolder(String parentId, String folderName) async {
    if (_driveApi == null) return null;

    try {
      final drive.File folder = drive.File()
        ..name = folderName
        ..mimeType = 'application/vnd.google-apps.folder'
        ..parents = [parentId];

      final drive.File createdFolder = await _driveApi!.files.create(folder);
      return createdFolder.id;
    } catch (e) {
      print('Error creating subfolder: $e');
      return null;
    }
  }

  /// Join a room: fetches the folder name from Drive using metadata.readonly scope.
  /// Returns the room name on success, null if key is invalid or inaccessible.
  Future<String?> joinRoom(String folderId) async {
    if (_driveApi == null) return null;
    try {
      final drive.File folder = await _driveApi!.files.get(
        folderId,
        $fields: 'id, name, mimeType',
      ) as drive.File;
      if (folder.mimeType != 'application/vnd.google-apps.folder') return null;
      return folder.name ?? 'Unnamed Room';
    } catch (e) {
      print('Error joining room: $e');
      return null;
    }
  }

  /// Uploads a local file to the specific Room (Folder ID)
  Future<bool> uploadFileToRoom(String folderId, File file) async {
    if (_driveApi == null) return false;

    try {
      final fileName = path.basename(file.path);
      
      final drive.File driveFile = drive.File()
        ..name = fileName
        ..parents = [folderId]; // Set the parent folder to the Room ID

      final result = await _driveApi!.files.create(
        driveFile,
        uploadMedia: drive.Media(file.openRead(), file.lengthSync()),
      );
      
      return result.id != null;
    } catch (e) {
      print('Error uploading file to room: $e');
      return false;
    }
  }

  /// List all files inside the Room (Folder ID)
  Future<List<drive.File>> listFilesInRoom(String folderId) async {
    if (_driveApi == null) return [];

    try {
      final drive.FileList fileList = await _driveApi!.files.list(
        q: "'$folderId' in parents and trashed = false",
        $fields: "files(id, name, mimeType, webViewLink, webContentLink, createdTime, size)",
      );
      
      return fileList.files ?? [];
    } catch (e) {
      print('Error listing files in room: $e');
      return [];
    }
  }

  /// Get members (permissions) of a folder
  Future<List<drive.Permission>> getFolderMembers(String folderId) async {
    if (_driveApi == null) return [];
    
    try {
      final drive.PermissionList perms = await _driveApi!.permissions.list(
        folderId,
        $fields: "permissions(id, role, type, emailAddress, displayName, photoLink)",
      );
      return perms.permissions ?? [];
    } catch (e) {
      print('Error getting members: $e');
      return [];
    }
  }
}
