/// Model to represent a Room the user has joined/created.
/// Stored locally in SQLite (just the IDs and name for quick listing).
class RoomModel {
  final String roomId;      // Firestore document ID
  final String roomName;
  final bool isCreator;
  final String? joinCode;

  const RoomModel({
    required this.roomId,
    required this.roomName,
    this.isCreator = false,
    this.joinCode,
  });

  Map<String, dynamic> toMap() => {
        'folderId': roomId,  // keep legacy column name for existing DB
        'roomName': roomName,
        'isCreator': isCreator ? 1 : 0,
      };

  factory RoomModel.fromMap(Map<String, dynamic> map) => RoomModel(
        roomId: map['folderId'] as String,
        roomName: map['roomName'] as String,
        isCreator: (map['isCreator'] as int) == 1,
      );
}
