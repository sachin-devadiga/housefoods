import '../models/message_model.dart';
import '../models/chat_room_model.dart';

abstract class ChatRepository {
  Future<void> sendMessage(MessageModel message, String chatRoomId);
  Stream<List<MessageModel>> getMessages(String chatRoomId);
  Stream<List<ChatRoomModel>> getChatRooms(String userId);
}
