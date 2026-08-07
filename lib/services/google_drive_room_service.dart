import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;

import '../models/room_model.dart';
import 'backup_service.dart';
import 'database_helper.dart';

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
      await syncRoomsFromCloud(); // Auto sync on silent sign in too
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
      await syncRoomsFromCloud(); // Auto sync on explicit sign in
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

  Future<void> syncRoomsToCloud() async {
    final api = await _getDriveApi();
    if (api == null) return;
    try {
      final rooms = await DatabaseHelper.instance.getRooms();
      final roomsData = rooms.map((r) => r.toMap()).toList();
      final jsonStr = jsonEncode(roomsData);
      
      final query = "name = 'joined_rooms_sync.json' and 'appDataFolder' in parents and trashed = false";
      final fileList = await api.files.list(q: query, spaces: 'appDataFolder');
      
      String? fileId;
      if (fileList.files != null && fileList.files!.isNotEmpty) {
        fileId = fileList.files!.first.id;
      }
      
      final bytes = utf8.encode(jsonStr);
      final media = drive.Media(Stream.value(bytes), bytes.length);
      final driveFile = drive.File()
        ..name = 'joined_rooms_sync.json'
        ..parents = ['appDataFolder'];
        
      if (fileId != null) {
        await api.files.update(drive.File(), fileId, uploadMedia: media);
      } else {
        await api.files.create(driveFile, uploadMedia: media);
      }
    } catch (e) {
      debugPrint('GoogleDriveRoomService.syncRoomsToCloud error: $e');
    }
  }

  Future<void> syncRoomsFromCloud() async {
    final api = await _getDriveApi();
    if (api == null) return;
    try {
      final query = "name = 'joined_rooms_sync.json' and 'appDataFolder' in parents and trashed = false";
      final fileList = await api.files.list(q: query, spaces: 'appDataFolder');
      
      if (fileList.files != null && fileList.files!.isNotEmpty) {
        final fileId = fileList.files!.first.id!;
        final media = await api.files.get(fileId, downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
        
        final List<int> bytes = [];
        await for (final chunk in media.stream) {
          bytes.addAll(chunk);
        }
        final jsonStr = utf8.decode(bytes);
        final List<dynamic> jsonList = jsonDecode(jsonStr);
        
        final localRooms = await DatabaseHelper.instance.getRooms();
        final localIds = localRooms.map((r) => r.roomId).toSet();
        
        for (var data in jsonList) {
          final roomMap = Map<String, dynamic>.from(data as Map);
          if (!localIds.contains(roomMap['roomId'] ?? roomMap['folderId'])) {
             // Handle case where older model used 'folderId'
             roomMap['folderId'] = roomMap['folderId'] ?? roomMap['roomId'];
             await DatabaseHelper.instance.insertRoom(RoomModel.fromMap(roomMap));
          }
        }
      }
    } catch (e) {
      debugPrint('GoogleDriveRoomService.syncRoomsFromCloud error: $e');
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
      
      await _registerMemberInDrive(api, createdFolder.id!, role: 'admin');
      
      try {
        final topic = _sanitizeTopic(createdFolder.id!);
        await FirebaseMessaging.instance.subscribeToTopic(topic);
      } catch (e) {
        debugPrint('FCM Subscribe error: $e');
      }
      
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
        
        await _registerMemberInDrive(api, folder.id!);
        
        try {
          final topic = _sanitizeTopic(folder.id!);
          await FirebaseMessaging.instance.subscribeToTopic(topic);
        } catch (e) {
          debugPrint('FCM Subscribe error: $e');
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
      
      // Auto-register current user if they are missing
      _registerMemberInDrive(api, roomId).catchError((_) {});
      
      try {
        final topic = _sanitizeTopic(roomId);
        FirebaseMessaging.instance.subscribeToTopic(topic);
      } catch (e) {
        debugPrint('FCM Subscribe error: $e');
      }
      
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
    final query = "'$targetId' in parents and trashed = false and name != '.chat.json' and name != '.members.json'";
    
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
      final List<RoomMember> members = [];
      
      // 1. Get explicit permissions (owners/admins)
      final pList = await api.permissions.list(roomId, $fields: 'permissions(id, emailAddress, displayName, role)');
      if (pList.permissions != null) {
        for (var p in pList.permissions!) {
          if (p.type == 'anyone') continue;
          members.add(RoomMember(
            uid: p.id ?? '',
            displayName: p.displayName ?? p.emailAddress ?? 'Unknown',
            email: p.emailAddress,
            role: p.role == 'owner' ? 'admin' : 'member',
          ));
        }
      }
      
      // 2. Get registered members from .members.json
      final membersFile = await _getMembersFile(api, roomId);
      if (membersFile != null && membersFile.id != null) {
        final media = await api.files.get(membersFile.id!, downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
        final List<int> bytes = [];
        await for (final chunk in media.stream) bytes.addAll(chunk);
        if (bytes.isNotEmpty) {
          final jsonStr = utf8.decode(bytes);
          final List<dynamic> jsonList = jsonDecode(jsonStr);
          
          for (var j in jsonList) {
            final uid = j['uid'] as String?;
            final email = j['email'] as String?;
            
            final exists = members.any((m) => 
               (email != null && m.email == email) || 
               (uid != null && m.uid == uid && m.uid.isNotEmpty));
            
            if (!exists) {
              members.add(RoomMember(
                uid: uid ?? '',
                displayName: j['displayName'] ?? 'Unknown',
                email: email,
                photoUrl: j['photoUrl'],
                role: j['role'] ?? 'member',
              ));
            }
          }
        }
      }
      
      // 3. Fallback to recover members from chat history
      final chatFile = await _getChatFile(api, roomId);
      if (chatFile != null && chatFile.id != null) {
        final media = await api.files.get(chatFile.id!, downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
        final List<int> bytes = [];
        await for (final chunk in media.stream) bytes.addAll(chunk);
        if (bytes.isNotEmpty) {
          final jsonStr = utf8.decode(bytes);
          final List<dynamic> jsonList = jsonDecode(jsonStr);
          
          for (var j in jsonList) {
            final uid = j['senderId'] as String?;
            final exists = members.any((m) => uid != null && m.uid == uid && m.uid.isNotEmpty);
            
            if (!exists && uid != null) {
              members.add(RoomMember(
                uid: uid,
                displayName: j['senderName'] ?? 'Unknown',
                email: null,
                photoUrl: j['senderPhotoUrl'],
                role: 'member',
              ));
            }
          }
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
      try {
        await api.permissions.delete(roomId, memberUid);
      } catch (_) {}
      
      final membersFile = await _getMembersFile(api, roomId);
      if (membersFile != null && membersFile.id != null) {
        final media = await api.files.get(membersFile.id!, downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
        final List<int> bytes = [];
        await for (final chunk in media.stream) bytes.addAll(chunk);
        if (bytes.isNotEmpty) {
          final jsonStr = utf8.decode(bytes);
          List<dynamic> jsonList = jsonDecode(jsonStr);
          
          final initialLength = jsonList.length;
          jsonList.removeWhere((m) => m['uid'] == memberUid);
          
          if (jsonList.length < initialLength) {
            final newJsonStr = jsonEncode(jsonList);
            final newBytes = utf8.encode(newJsonStr);
            final uploadMedia = drive.Media(Stream.value(newBytes), newBytes.length);
            await api.files.update(drive.File(), membersFile.id!, uploadMedia: uploadMedia);
          }
        }
      }
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
    
    String? lastMd5;
    String? currentFileId;
    List<RoomMessage> lastMessages = [];
    
    while (true) {
      try {
        if (currentFileId == null) {
          final chatFile = await _getChatFile(api, roomId);
          currentFileId = chatFile?.id;
        }
        
        if (currentFileId != null) {
          final meta = await api.files.get(currentFileId, $fields: 'id, md5Checksum') as drive.File;
          
          if (lastMd5 == null || meta.md5Checksum == null || meta.md5Checksum != lastMd5) {
            lastMd5 = meta.md5Checksum;
            
            final media = await api.files.get(currentFileId, downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
            final List<int> bytes = [];
            await for (final chunk in media.stream) {
              bytes.addAll(chunk);
            }
            final jsonStr = utf8.decode(bytes);
            final List<dynamic> jsonList = jsonDecode(jsonStr);
            lastMessages = jsonList.map((j) => RoomMessage.fromJson(j)).toList();
            yield lastMessages;
          }
        } else {
          yield [];
        }
      } catch (e) {
        if (e.toString().contains('404')) {
          currentFileId = null;
          lastMd5 = null;
          lastMessages = [];
          yield lastMessages;
        }
        debugPrint('GoogleDriveRoomService.messagesStream error: $e');
      }
      await Future.delayed(const Duration(seconds: 4)); 
    }
  }

  Future<bool> clearChat(String roomId) async {
    final api = await _getDriveApi();
    if (api == null) return false;
    try {
      final chatFile = await _getChatFile(api, roomId);
      if (chatFile != null && chatFile.id != null) {
        await api.files.delete(chatFile.id!);
      }
      return true;
    } catch (e) {
      debugPrint('GoogleDriveRoomService.clearChat error: $e');
      return false;
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
      
      // Trigger Vercel Push Notification API
      try {
        final topic = _sanitizeTopic(roomId);
        final vercelUrl = 'https://schedule-mate-livid.vercel.app/api/notify'; 
        
        http.post(
          Uri.parse(vercelUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'topic': topic,
            'title': 'New Message',
            'body': '${user.displayName}: $text',
            'senderId': user.id,
          }),
        ).catchError((_) => http.Response('Error', 500));
      } catch (e) {
        debugPrint('FCM Trigger error: $e');
      }
      
      return true;
    } catch (e) {
      debugPrint('GoogleDriveRoomService.sendMessage error: $e');
      return false;
    }
  }

  Future<drive.File?> _getMembersFile(drive.DriveApi api, String roomId) async {
    final query = "'$roomId' in parents and name = '.members.json' and trashed = false";
    final fileList = await api.files.list(q: query);
    if (fileList.files != null && fileList.files!.isNotEmpty) {
      return fileList.files!.first;
    }
    return null;
  }

  Future<void> _registerMemberInDrive(drive.DriveApi api, String roomId, {String role = 'member'}) async {
    final user = currentUser;
    if (user == null) return;
    try {
      final membersFile = await _getMembersFile(api, roomId);
      List<dynamic> currentMembers = [];
      String? fileId;
      
      if (membersFile != null) {
        fileId = membersFile.id;
        final media = await api.files.get(fileId!, downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
        final List<int> bytes = [];
        await for (final chunk in media.stream) bytes.addAll(chunk);
        if (bytes.isNotEmpty) {
          final jsonStr = utf8.decode(bytes);
          currentMembers = jsonDecode(jsonStr);
        }
      }
      
      final exists = currentMembers.any((m) => m['uid'] == user.id);
      if (!exists) {
        currentMembers.add({
          'uid': user.id,
          'displayName': user.displayName,
          'email': user.email,
          'photoUrl': user.photoUrl,
          'role': role,
          'joinedAt': DateTime.now().toIso8601String(),
        });
        
        final jsonStr = jsonEncode(currentMembers);
        final bytes = utf8.encode(jsonStr);
        final uploadMedia = drive.Media(Stream.value(bytes), bytes.length);
        
        if (fileId != null) {
          await api.files.update(drive.File(), fileId, uploadMedia: uploadMedia);
        } else {
          final newFile = drive.File()
            ..name = '.members.json'
            ..parents = [roomId];
          await api.files.create(newFile, uploadMedia: uploadMedia);
        }
      }
    } catch (e) {
      debugPrint('GoogleDriveRoomService._registerMemberInDrive error: $e');
    }
  }

  String _sanitizeTopic(String id) {
    return 'room_${id.replaceAll(RegExp(r'[^a-zA-Z0-9-_.~%]'), '')}';
  }
}

class User {
  final String id;
  final String email;
  final String displayName;
  final String? photoUrl;
  
  User({required this.id, required this.email, required this.displayName, this.photoUrl});
}
