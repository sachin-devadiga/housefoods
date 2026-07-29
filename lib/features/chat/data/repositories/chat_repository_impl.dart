import 'dart:async';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/api_service.dart';
import '../../domain/models/message_model.dart';
import '../../domain/models/chat_room_model.dart';
import '../../domain/repositories/chat_repository.dart';

class ChatRepositoryImpl implements ChatRepository {
  final ApiService _api;

  ChatRepositoryImpl({ApiService? apiService})
      : _api = apiService ?? ApiService(baseUrl: AppConstants.apiBaseUrl);

  @override
  Future<void> sendMessage(MessageModel message, String chatRoomId) async {
    await _api.post(AppConstants.chatSendEndpoint, body: {
      'receiver': message.receiverId,
      'message': message.text,
      'message_type': 'text',
    });
  }

  @override
  Stream<List<MessageModel>> getMessages(String chatRoomId) {
    return Stream.periodic(const Duration(seconds: 3), (_) => null).asyncMap((_) async {
      try {
        final data = await _api.get(AppConstants.chatMessagesEndpoint, queryParams: {
          'other_uid': chatRoomId,
        });
        final list = (data['data'] as List?) ?? [];
        return list.map((e) => MessageModel.fromMap(e as Map<String, dynamic>, e['id'].toString())).toList();
      } catch (e) {
        return <MessageModel>[];
      }
    });
  }

  @override
  Stream<List<ChatRoomModel>> getChatRooms(String userId) {
    return Stream.periodic(const Duration(seconds: 5), (_) => null).asyncMap((_) async {
      try {
        final data = await _api.get(AppConstants.chatContactsEndpoint);
        final list = (data['data'] as List?) ?? [];
        return list.map((e) {
          final map = e as Map<String, dynamic>;
          return ChatRoomModel(
            id: map['uid'] ?? '',
            participants: [map['uid'] ?? ''],
            lastMessage: '',
            lastTimestamp: DateTime.now(),
            otherUserName: map['name'] ?? 'User',
            otherUserImage: map['avatar_url'],
          );
        }).toList();
      } catch (e) {
        return <ChatRoomModel>[];
      }
    });
  }
}
