class ChatRoomModel {
  final String id;
  final List<String> participants;
  final String lastMessage;
  final DateTime lastTimestamp;
  // Other participant's details (fetched dynamically or stored in room)
  final String otherUserName;
  final String? otherUserImage;

  ChatRoomModel({
    required this.id,
    required this.participants,
    required this.lastMessage,
    required this.lastTimestamp,
    required this.otherUserName,
    this.otherUserImage,
  });

  factory ChatRoomModel.fromMap(Map<String, dynamic> map, String docId, String currentUserId) {
    // Basic logic to determine 'other' user info
    // In production, you might store participant names in the room doc to avoid extra fetches
    return ChatRoomModel(
      id: docId,
      participants: List<String>.from(map['participants'] ?? []),
      lastMessage: map['lastMessage'] ?? '',
      lastTimestamp: map['lastTimestamp'] as DateTime? ?? DateTime.now(),
      otherUserName: map['otherUserName'] ?? 'User', // Fallback
      otherUserImage: map['otherUserImage'],
    );
  }
}
