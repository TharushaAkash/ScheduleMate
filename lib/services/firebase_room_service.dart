import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Represents a shared link or folder saved in a Room (Firestore only, no Storage).
class RoomFile {
  final String id;
  final String name;
  final String? url;      // shareable link (Google Drive, OneDrive, etc.)
  final DateTime? createdAt;
  final bool isFolder;
  final String? parentId;
  final String? addedByName;

  const RoomFile({
    required this.id,
    required this.name,
    this.url,
    this.createdAt,
    this.isFolder = false,
    this.parentId,
    this.addedByName,
  });

  factory RoomFile.fromMap(String id, Map<String, dynamic> map) {
    return RoomFile(
      id: id,
      name: map['name'] ?? '',
      url: map['url'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      isFolder: map['isFolder'] == true,
      parentId: map['parentId'] as String?,
      addedByName: map['addedByName'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'url': url,
        'createdAt': FieldValue.serverTimestamp(),
        'isFolder': isFolder,
        'parentId': parentId,
        'addedByName': addedByName,
      };
}

/// Data model for a Room member stored in Firestore.
class RoomMember {
  final String uid;
  final String displayName;
  final String? email;
  final String? photoUrl;
  final String role; // 'admin' or 'member'
  final DateTime? joinedAt;

  const RoomMember({
    required this.uid,
    required this.displayName,
    this.email,
    this.photoUrl,
    this.role = 'member',
    this.joinedAt,
  });

  factory RoomMember.fromMap(String uid, Map<String, dynamic> map) {
    return RoomMember(
      uid: uid,
      displayName: map['displayName'] ?? 'Unknown',
      email: map['email'] as String?,
      photoUrl: map['photoUrl'] as String?,
      role: map['role'] ?? 'member',
      joinedAt: (map['joinedAt'] as Timestamp?)?.toDate(),
    );
  }
}

class FirebaseRoomService {
  static final FirebaseRoomService instance = FirebaseRoomService._();
  FirebaseRoomService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  // ─── Auth ───────────────────────────────────────────────────────────────────

  User? get currentUser => _auth.currentUser;

  /// Signs in the user with Google and links to Firebase Auth.
  /// Uses existing session silently if available.
  Future<User?> signIn() async {
    try {
      if (_auth.currentUser != null) return _auth.currentUser;

      GoogleSignInAccount? googleUser = await _googleSignIn.signInSilently();
      googleUser ??= await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      return userCredential.user;
    } catch (e) {
      print('FirebaseRoomService.signIn error: $e');
      return null;
    }
  }

  // ─── Room Management ────────────────────────────────────────────────────────

  /// Generates a short random join code (e.g. "HX93K2")
  String _generateJoinCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  /// Creates a new room in Firestore. Returns the roomId.
  Future<String?> createRoom(String roomName) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      String joinCode = _generateJoinCode();
      // Ensure uniqueness
      while (true) {
        final existing = await _db
            .collection('rooms')
            .where('joinCode', isEqualTo: joinCode)
            .limit(1)
            .get();
        if (existing.docs.isEmpty) break;
        joinCode = _generateJoinCode();
      }

      final roomRef = await _db.collection('rooms').add({
        'name': roomName,
        'joinCode': joinCode,
        'creatorUid': user.uid,
        'creatorName': user.displayName ?? 'Unknown',
        'createdAt': FieldValue.serverTimestamp(),
        'memberCount': 1,
      });

      // Add creator as admin member
      await roomRef.collection('members').doc(user.uid).set({
        'displayName': user.displayName ?? 'Unknown',
        'email': user.email,
        'photoUrl': user.photoURL,
        'role': 'admin',
        'joinedAt': FieldValue.serverTimestamp(),
      });

      return roomRef.id;
    } catch (e) {
      print('FirebaseRoomService.createRoom error: $e');
      return null;
    }
  }

  /// Joins a room with a join code. Returns the room name, or null on failure.
  Future<Map<String, String>?> joinRoom(String joinCode) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final query = await _db
          .collection('rooms')
          .where('joinCode', isEqualTo: joinCode.trim().toUpperCase())
          .limit(1)
          .get();

      if (query.docs.isEmpty) return null;

      final roomDoc = query.docs.first;
      final roomId = roomDoc.id;
      final roomName = roomDoc.data()['name'] as String? ?? 'Unnamed Room';

      // Check if already a member
      final memberDoc =
          await roomDoc.reference.collection('members').doc(user.uid).get();

      if (!memberDoc.exists) {
        // Add as member
        await roomDoc.reference.collection('members').doc(user.uid).set({
          'displayName': user.displayName ?? 'Unknown',
          'email': user.email,
          'photoUrl': user.photoURL,
          'role': 'member',
          'joinedAt': FieldValue.serverTimestamp(),
        });

        // Increment memberCount
        await roomDoc.reference
            .update({'memberCount': FieldValue.increment(1)});
      }

      return {'roomId': roomId, 'roomName': roomName};
    } catch (e) {
      print('FirebaseRoomService.joinRoom error: $e');
      return null;
    }
  }

  /// Get rooms the current user is a member of.
  Future<List<Map<String, dynamic>>> getUserRooms(List<String> roomIds) async {
    if (roomIds.isEmpty) return [];
    try {
      final results = <Map<String, dynamic>>[];
      for (final id in roomIds) {
        final doc = await _db.collection('rooms').doc(id).get();
        if (doc.exists) {
          results.add({'id': doc.id, ...doc.data()!});
        }
      }
      return results;
    } catch (e) {
      print('FirebaseRoomService.getUserRooms error: $e');
      return [];
    }
  }

  /// Get a single room document snapshot.
  Future<Map<String, dynamic>?> getRoom(String roomId) async {
    try {
      final doc = await _db.collection('rooms').doc(roomId).get();
      if (!doc.exists) return null;
      return {'id': doc.id, ...doc.data()!};
    } catch (e) {
      return null;
    }
  }

  // ─── Files ──────────────────────────────────────────────────────────────────

  /// Lists files in a room (optionally filtered by parentId folder).
  Stream<List<RoomFile>> filesStream(String roomId, {String? parentId}) {
    Query query = _db
        .collection('rooms')
        .doc(roomId)
        .collection('files')
        .orderBy('isFolder', descending: true)
        .orderBy('name');

    if (parentId == null) {
      query = query.where('parentId', isNull: true);
    } else {
      query = query.where('parentId', isEqualTo: parentId);
    }

    return query.snapshots().map((snap) => snap.docs
        .map((d) => RoomFile.fromMap(d.id, d.data() as Map<String, dynamic>))
        .toList());
  }

  /// Adds a shared link (Google Drive, OneDrive, etc.) to the room.
  Future<bool> addLink(String roomId, String name, String url, {String? parentId}) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      await _db.collection('rooms').doc(roomId).collection('files').add({
        'name': name,
        'url': url,
        'isFolder': false,
        'parentId': parentId,
        'addedBy': user.uid,
        'addedByName': user.displayName ?? 'Unknown',
        'createdAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('FirebaseRoomService.addLink error: $e');
      return false;
    }
  }

  /// Creates a virtual folder (document in Firestore, no Storage needed).
  Future<String?> createFolder(String roomId, String folderName,
      {String? parentId}) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final ref =
          await _db.collection('rooms').doc(roomId).collection('files').add({
        'name': folderName,
        'isFolder': true,
        'parentId': parentId,
        'createdBy': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return ref.id;
    } catch (e) {
      print('FirebaseRoomService.createFolder error: $e');
      return null;
    }
  }

  /// Deletes a file/link/folder record from Firestore.
  Future<void> deleteFile(String roomId, RoomFile file) async {
    try {
      await _db
          .collection('rooms')
          .doc(roomId)
          .collection('files')
          .doc(file.id)
          .delete();
    } catch (e) {
      print('FirebaseRoomService.deleteFile error: $e');
    }
  }

  // ─── Members ────────────────────────────────────────────────────────────────

  /// Streams the member list for a room.
  Stream<List<RoomMember>> membersStream(String roomId) {
    return _db
        .collection('rooms')
        .doc(roomId)
        .collection('members')
        .orderBy('role', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) =>
                RoomMember.fromMap(d.id, d.data()))
            .toList());
  }

  /// Removes a member from the room (admin only).
  Future<void> removeMember(String roomId, String memberUid) async {
    try {
      await _db
          .collection('rooms')
          .doc(roomId)
          .collection('members')
          .doc(memberUid)
          .delete();
      await _db
          .collection('rooms')
          .doc(roomId)
          .update({'memberCount': FieldValue.increment(-1)});
    } catch (e) {
      print('FirebaseRoomService.removeMember error: $e');
    }
  }

  /// Deletes the room document from Firestore (admin only).
  /// Note: subcollections (members/files) are NOT auto-deleted on Spark plan
  /// (no Cloud Functions). They become orphaned but won't be visible in-app.
  Future<void> deleteRoom(String roomId) async {
    try {
      await _db.collection('rooms').doc(roomId).delete();
    } catch (e) {
      print('FirebaseRoomService.deleteRoom error: $e');
    }
  }

  /// Checks whether the current user is the creator/admin of a room.
  Future<bool> isAdmin(String roomId) async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final doc = await _db.collection('rooms').doc(roomId).get();
    return doc.data()?['creatorUid'] == user.uid;
  }
}
