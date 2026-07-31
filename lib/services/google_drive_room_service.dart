import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;

import 'backup_service.dart';

class RoomFile {
  final String id;
  final String name;
  final String? url;
  final String? storagePath;
  final DateTime? createdAt;
  final bool isFolder;
  final String? parentId;
  final String? addedByName;

  const RoomFile({
    required this.id,
    required this.name,
    this.url,
    this.storagePath,
    this.createdAt,
    this.isFolder = false,
    this.parentId,
    this.addedByName,
  });
}

class RoomMessage {
  final String id;
  final String text;
  final String senderId;
  final String senderName;
  final String? senderPhotoUrl;
  final DateTime createdAt;

  const RoomMessage({
    required this.id,
    required this.text,
    required this.senderId,
    required this.senderName,
    this.senderPhotoUrl,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'senderId': senderId,
        'senderName': senderName,
        'senderPhotoUrl': senderPhotoUrl,
        'createdAt': createdAt.toIso8601String(),
      };

  factory RoomMessage.fromJson(Map<String, dynamic> json) => RoomMessage(
        id: json['id'],
        text: json['text'],
        senderId: json['senderId'],
        senderName: json['senderName'],
        senderPhotoUrl: json['senderPhotoUrl'],
        createdAt: DateTime.parse(json['createdAt']),
      );
}

class RoomMember {
  final String uid;
  final String displayName;
  final String? email;
  final String? photoUrl;
  final String role;
  final DateTime? joinedAt;

  const RoomMember({
    required this.uid,
    required this.displayName,
    this.email,
    this.photoUrl,
    this.role = 'member',
    this.joinedAt,
  });
}

class GoogleDriveRoomService {
  static final GoogleDriveRoomService instance = GoogleDriveRoomService._();
  GoogleDriveRoomService._();

  GoogleSignIn get _googleSignIn => BackupService.instance.googleSignIn;

  User? get currentUser {
    final account = BackupService.instance.currentUser;
    if (account == null) return null;
    return User(
      id: account.id,
      email: account.email,
      displayName: account.displayName ?? 'Unknown',
      photoUrl: account.photoUrl,
    );
  }

  Future<drive.DriveApi?> _getDriveApi() async {
    final account = BackupService.instance.currentUser;
    if (account == null) return null;
    final authHeaders = await account.authHeaders;
    final authClient = GoogleAuthClient(authHeaders);
    return drive.DriveApi(authClient);
  }

  Future<User?> signInSilently() async {
    try {
      final account = await _googleSignIn.signInSilently();
      if (account == null) return null;
      return User(
        id: account.id,
        email: account.email,
        displayName: account.displayName ?? 'Unknown',
        photoUrl: account.photoUrl,
      );
    } catch (e) {
      debugPrint('GoogleDriveRoomService.signInSilently error: $e');
      return null;
    }
  }

  Future<User?> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) return null;
      return User(
        id: account.id,
        email: account.email,
        displayName: account.displayName ?? 'Unknown',
        photoUrl: account.photoUrl,
      );
    } catch (e) {
      debugPrint('GoogleDriveRoomService.signIn error: $e');
      return null;
    }
  }

  Future<String?> createRoom(String roomName) async {
    final api = await _getDriveApi();
    if (api == null) return null;
    
    try {
      final folder = drive.File()
        ..name = '[ScheduleMate] $roomName'
        ..mimeType = 'application/vnd.google-apps.folder';
      
      final createdFolder = await api.files.create(folder);
      
      try {
        await api.permissions.create(
          drive.Permission()..type = 'anyone'..role = 'writer',
          createdFolder.id!,
        );
      } catch (_) {}
      
      return createdFolder.id;
    } catch (e) {
      debugPrint('GoogleDriveRoomService.createRoom error: $e');
      return null;
    }
  }

  Future<Map<String, String>?> joinRoom(String joinCode) async {
    final api = await _getDriveApi();
    if (api == null) return null;
    
    try {
      final folder = await api.files.get(joinCode, $fields: 'id, name') as drive.File;
      if (folder.id != null && folder.name != null) {
        String name = folder.name!;
        if (name.startsWith('[ScheduleMate] ')) {
          name = name.substring(15);
        }
        return {'roomId': folder.id!, 'roomName': name};
      }
    } catch (e) {
      debugPrint('GoogleDriveRoomService.joinRoom error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> getRoom(String roomId) async {
    final api = await _getDriveApi();
    if (api == null) return null;
    try {
      final folder = await api.files.get(roomId, $fields: 'id, name, owners') as drive.File;
      String name = folder.name ?? 'Unknown Room';
      if (name.startsWith('[ScheduleMate] ')) name = name.substring(15);
      
      return {
        'id': folder.id,
        'name': name,
        'joinCode': folder.id,
        'creatorUid': folder.owners?.first.emailAddress ?? '',
        'creatorName': folder.owners?.first.displayName ?? 'Unknown',
        'memberCount': 1,
      };
    } catch (e) {
      return null;
    }
  }

  Stream<List<RoomFile>> filesStream(String roomId, {String? parentId}) async* {
    final api = await _getDriveApi();
    if (api == null) {
      yield [];
      return;
    }
    
    final targetId = parentId ?? roomId;
    final query = "'$targetId' in parents and trashed = false and name != '.chat.json'";
    
    try {
      final fileList = await api.files.list(q: query, $fields: 'files(id, name, webViewLink, mimeType, createdTime)');
      final List<RoomFile> roomFiles = [];
      
      if (fileList.files != null) {
        for (var f in fileList.files!) {
          final isFolder = f.mimeType == 'application/vnd.google-apps.folder';
          roomFiles.add(RoomFile(
            id: f.id!,
            name: f.name ?? '',
            url: f.webViewLink,
            storagePath: f.id,
            createdAt: f.createdTime,
            isFolder: isFolder,
            parentId: parentId,
            addedByName: 'Unknown',
          ));
        }
      }
      
      roomFiles.sort((a, b) {
        if (a.isFolder && !b.isFolder) return -1;
        if (!a.isFolder && b.isFolder) return 1;
        return a.name.compareTo(b.name);
      });
      
      yield roomFiles;
    } catch (e) {
      debugPrint('GoogleDriveRoomService.filesStream error: $e');
      yield [];
    }
  }

  Future<bool> addLink(String roomId, String name, String url, {String? parentId}) async {
    final api = await _getDriveApi();
    if (api == null) return false;
    
    try {
      final file = drive.File()
        ..name = '$name.url'
        ..parents = [parentId ?? roomId]
        ..mimeType = 'text/uri-list';
        
      final bytes = utf8.encode(url);
      final media = drive.Media(Stream.value(bytes), bytes.length);
      
      await api.files.create(file, uploadMedia: media);
      return true;
    } catch (e) {
      debugPrint('GoogleDriveRoomService.addLink error: $e');
      return false;
    }
  }

  Future<String?> createFolder(String roomId, String folderName, {String? parentId}) async {
    final api = await _getDriveApi();
    if (api == null) return null;
    try {
      final folder = drive.File()
        ..name = folderName
        ..parents = [parentId ?? roomId]
        ..mimeType = 'application/vnd.google-apps.folder';
      final created = await api.files.create(folder);
      return created.id;
    } catch (e) {
      debugPrint('GoogleDriveRoomService.createFolder error: $e');
      return null;
    }
  }

  Future<bool> uploadFile(
    String roomId,
    File file,
    String fileName, {
    String? parentId,
    void Function(int, int)? onProgress,
  }) async {
    final api = await _getDriveApi();
    if (api == null) return false;
    
    try {
      final driveFile = drive.File()
        ..name = fileName
        ..parents = [parentId ?? roomId];
        
      final media = drive.Media(file.openRead(), file.lengthSync());
      await api.files.create(driveFile, uploadMedia: media);
      return true;
    } catch (e) {
      debugPrint('GoogleDriveRoomService.uploadFile error: $e');
      return false;
    }
  }

  Future<void> deleteFile(String roomId, RoomFile file) async {
    final api = await _getDriveApi();
    if (api == null) return;
    try {
      await api.files.delete(file.id);
    } catch (e) {
      debugPrint('GoogleDriveRoomService.deleteFile error: $e');
    }
  }

  Stream<List<RoomMember>> membersStream(String roomId) async* {
    final api = await _getDriveApi();
    if (api == null) {
      yield [];
      return;
    }
    try {
      final pList = await api.permissions.list(roomId, $fields: 'permissions(id, emailAddress, displayName, role)');
      final List<RoomMember> members = [];
      if (pList.permissions != null) {
        for (var p in pList.permissions!) {
          if (p.type == 'anyone') continue;
          members.add(RoomMember(
            uid: p.id!,
            displayName: p.displayName ?? p.emailAddress ?? 'Unknown',
            email: p.emailAddress,
            role: p.role == 'owner' ? 'admin' : 'member',
          ));
        }
      }
      yield members;
    } catch (e) {
      debugPrint('GoogleDriveRoomService.membersStream error: $e');
      yield [];
    }
  }

  Future<void> removeMember(String roomId, String memberUid) async {
    final api = await _getDriveApi();
    if (api == null) return;
    try {
      await api.permissions.delete(roomId, memberUid);
    } catch (e) {
      debugPrint('GoogleDriveRoomService.removeMember error: $e');
    }
  }

  Future<void> leaveRoom(String roomId) async {
    // For Google Drive, just removing from local DB is enough for the user.
  }

  Future<void> deleteRoom(String roomId) async {
    final api = await _getDriveApi();
    if (api == null) return;
    try {
      await api.files.delete(roomId);
    } catch (e) {
      debugPrint('GoogleDriveRoomService.deleteRoom error: $e');
    }
  }

  Future<drive.File?> _getChatFile(drive.DriveApi api, String roomId) async {
    final query = "'$roomId' in parents and name = '.chat.json' and trashed = false";
    final fileList = await api.files.list(q: query);
    if (fileList.files != null && fileList.files!.isNotEmpty) {
      return fileList.files!.first;
    }
    return null;
  }

  Stream<List<RoomMessage>> messagesStream(String roomId) async* {
    final api = await _getDriveApi();
    if (api == null) {
      yield [];
      return;
    }
    
    while (true) {
      try {
        final chatFile = await _getChatFile(api, roomId);
        if (chatFile != null) {
          final media = await api.files.get(chatFile.id!, downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
          final List<int> bytes = [];
          await for (final chunk in media.stream) {
            bytes.addAll(chunk);
          }
          final jsonStr = utf8.decode(bytes);
          final List<dynamic> jsonList = jsonDecode(jsonStr);
          yield jsonList.map((j) => RoomMessage.fromJson(j)).toList();
        } else {
          yield [];
        }
      } catch (e) {
        debugPrint('GoogleDriveRoomService.messagesStream error: $e');
      }
      await Future.delayed(const Duration(seconds: 5)); 
    }
  }

  Future<bool> sendMessage(String roomId, String text) async {
    final api = await _getDriveApi();
    final user = currentUser;
    if (api == null || user == null) return false;
    
    try {
      final chatFile = await _getChatFile(api, roomId);
      List<RoomMessage> messages = [];
      String? fileId;
      
      if (chatFile != null) {
        fileId = chatFile.id;
        final media = await api.files.get(fileId!, downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
        final List<int> bytes = [];
        await for (final chunk in media.stream) {
          bytes.addAll(chunk);
        }
        final jsonStr = utf8.decode(bytes);
        final List<dynamic> jsonList = jsonDecode(jsonStr);
        messages = jsonList.map((j) => RoomMessage.fromJson(j)).toList();
      }
      
      messages.add(RoomMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: text,
        senderId: user.id,
        senderName: user.displayName,
        senderPhotoUrl: user.photoUrl,
        createdAt: DateTime.now(),
      ));
      
      final jsonStr = jsonEncode(messages.map((m) => m.toJson()).toList());
      final bytes = utf8.encode(jsonStr);
      final uploadMedia = drive.Media(Stream.value(bytes), bytes.length);
      
      if (fileId != null) {
        await api.files.update(drive.File(), fileId, uploadMedia: uploadMedia);
      } else {
        final newFile = drive.File()
          ..name = '.chat.json'
          ..parents = [roomId];
        await api.files.create(newFile, uploadMedia: uploadMedia);
      }
      return true;
    } catch (e) {
      debugPrint('GoogleDriveRoomService.sendMessage error: $e');
      return false;
    }
  }
}

class User {
  final String id;
  final String email;
  final String displayName;
  final String? photoUrl;
  
  User({required this.id, required this.email, required this.displayName, this.photoUrl});
}
