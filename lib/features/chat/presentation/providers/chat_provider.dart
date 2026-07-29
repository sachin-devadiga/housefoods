import 'package:flutter/material.dart';
import '../../domain/models/message_model.dart';
import '../../domain/models/chat_room_model.dart';
import '../../domain/repositories/chat_repository.dart';

class ChatProvider extends ChangeNotifier {
  final ChatRepository _chatRepository;

  ChatProvider(this._chatRepository);

  /// Generates a unique, deterministic chat room ID based on participant UIDs
  String getChatRoomId(String uid1, String uid2) {
    List<String> ids = [uid1, uid2];
    ids.sort(); // Sort alphabetically to ensure consistency
    return ids.join("_");
  }

  /// Streams real-time messages for a specific room
  Stream<List<MessageModel>> getMessages(String chatRoomId) {
    return _chatRepository.getMessages(chatRoomId);
  }

  /// Streams all chat rooms where the user is a participant
  Stream<List<ChatRoomModel>> getChatRooms(String userId) {
    return _chatRepository.getChatRooms(userId);
  }

  /// Sends a new message
  Future<void> sendMessage({
    required String senderId,
    required String receiverId,
    required String text,
  }) async {
    if (text.trim().isEmpty) return;

    final chatRoomId = getChatRoomId(senderId, receiverId);
    final message = MessageModel(
      id: '', 
      senderId: senderId,
      receiverId: receiverId,
      text: text.trim(),
      timestamp: DateTime.now(),
    );

    try {
      await _chatRepository.sendMessage(message, chatRoomId);
    } catch (e) {
      debugPrint("Error sending message: $e");
    }
  }
}
