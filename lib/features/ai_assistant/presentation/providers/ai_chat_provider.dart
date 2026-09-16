import 'package:flutter/foundation.dart';
import '../../../../core/services/api_service.dart';
import '../../data/repositories/ai_chat_repository.dart';
import '../../domain/models/ai_chat_models.dart';

class AiChatProvider extends ChangeNotifier {
  final AiChatRepository _repository;

  List<AiChatMessage> _messages = [];
  bool _isLoading = false;
  String? _error;

  AiChatProvider(this._repository);

  List<AiChatMessage> get messages => _messages;
  bool get isLoading => _isLoading;
  String? get error => _error;

  String? _lastUserMessage;

  String? get lastUserMessage => _lastUserMessage;

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    _lastUserMessage = text.trim();

    final userMessage = AiChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: 'user',
      text: text.trim(),
      timestamp: DateTime.now(),
    );

    _messages = [..._messages, userMessage];
    _error = null;
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _repository.sendMessage(
        message: text.trim(),
        conversationHistory: _messages,
      );

      final assistantMessage = AiChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        role: 'assistant',
        text: response.responseText,
        toolCalls: response.toolCalls,
        toolResults: response.toolResults,
        timestamp: DateTime.now(),
      );

      _messages = [..._messages, assistantMessage];
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Something went wrong. Please try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearConversation() {
    _messages = [];
    _error = null;
    _isLoading = false;
    _lastUserMessage = null;
    notifyListeners();
  }

  Future<void> retryLastMessage() async {
    if (_lastUserMessage == null || _lastUserMessage!.isEmpty) return;
    if (_isLoading) return;

    if (_messages.isNotEmpty && _messages.last.role == 'assistant') {
      _messages = _messages.sublist(0, _messages.length - 1);
      notifyListeners();
    }

    await sendMessage(_lastUserMessage!);
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
