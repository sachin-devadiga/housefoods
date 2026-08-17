class MessageModel {
  final String id;
  final String senderId;
  final String receiverId;
  final String text;
  final DateTime timestamp;

  MessageModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.text,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'receiverId': receiverId,
      'text': text,
      'timestamp': timestamp,
    };
  }

  factory MessageModel.fromMap(Map<String, dynamic> map, String docId) {
    return MessageModel(
      id: docId,
      senderId: map['sender_details']?['uid'] ?? map['sender'].toString(),
      receiverId: map['receiver_details']?['uid'] ?? map['receiver'].toString(),
      text: map['message'] ?? map['text'] ?? '',
      timestamp: DateTime.tryParse(map['created_at']?.toString() ?? map['timestamp']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}
