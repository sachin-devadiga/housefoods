import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/constants/app_constants.dart';
import '../core/services/token_service.dart';

/// Generates natural conversational responses in the user's language using Gemini.
class MealVoiceResponseGenerator {
  String? _authToken;
  bool _isAvailable = false;

  bool get isAvailable => _isAvailable;

  Future<bool> initialize() async {
    try {
      final tokenService = TokenService();
      _authToken = await tokenService.getAccessToken();
      _isAvailable = _authToken != null && _authToken!.isNotEmpty;
      return _isAvailable;
    } catch (e) {
      debugPrint('[ResponseGenerator] Init failed: $e');
      return false;
    }
  }

  Future<void> _refreshToken() async {
    final tokenService = TokenService();
    _authToken = await tokenService.getAccessToken();
  }

  /// Generate a natural conversational response via Gemini.
  /// [context] describes what happened (e.g., "cart cleared", "item found").
  /// [details] provides specifics (item names, prices, etc.).
  /// [languageCode] is the detected language code (e.g., 'hi-IN', 'kn-IN').
  Future<String> respond({
    required String context,
    String details = '',
    required String languageCode,
  }) async {
    // Always try to get a fresh token (user may have logged in since init)
    await _refreshToken();
    if (_authToken == null || _authToken!.isEmpty) {
      debugPrint('[ResponseGenerator] No auth token — using fallback');
      return _fallbackResponse(context, details);
    }
    _isAvailable = true;

    final langName = _languageName(languageCode);

    final prompt = 'Context: $context\n'
        '${details.isNotEmpty ? "Details: $details\n" : ""}'
        'Generate a SHORT, natural, friendly response (1-2 sentences max) for a food ordering voice assistant. '
        'The user speaks $langName — respond in $langName. '
        'Be warm, helpful, and conversational like a human assistant. '
        'Never mention that you are an AI or a bot. Never say "as an AI". '
        'Do not use markdown or formatting. Just plain text speech.';

    try {
      final uri = Uri.parse('${AppConstants.apiBaseUrl}/api/auth/voice/gemini/');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $_authToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'prompt': prompt,
          'system_prompt': 'You are a friendly, warm food ordering assistant named MEAL. '
              'You speak naturally and casually, like a helpful friend. '
              'Keep responses short (1-2 sentences). '
              'Never identify yourself as AI. Never use markdown.',
          'model': 'gemini-2.5-flash',
          'temperature': 0.7,
          'max_output_tokens': 100,
        }),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final text = data['text'] as String?;
        if (text != null && text.trim().isNotEmpty) {
          debugPrint('[ResponseGenerator] Gemini: "${text.trim()}"');
          return text.trim();
        }
      }
      debugPrint('[ResponseGenerator] Gemini error ${response.statusCode}');
      return _fallbackResponse(context, details);
    } catch (e) {
      debugPrint('[ResponseGenerator] Gemini failed: $e');
      return _fallbackResponse(context, details);
    }
  }

  String _fallbackResponse(String context, String details) {
    // Minimal fallback if Gemini is completely down
    switch (context) {
      case 'greeting': return 'What would you like to order?';
      case 'item_found': return 'I found what you\'re looking for! Shall I add it to your cart?';
      case 'item_not_found': return 'Sorry, I couldn\'t find that. Would you like to try something else?';
      case 'cart_cleared': return 'Your cart is cleared! What would you like to order?';
      case 'cart_conflict': return 'You have items from a different restaurant. Should I clear them first?';
      case 'order_placed': return 'Your order has been placed successfully!';
      case 'pin_required': return 'I\'ll need your PIN to confirm the order.';
      case 'pin_failed': return 'PIN verification failed. Please try again.';
      case 'timeout': return 'I didn\'t catch that. Just say "Hi MEAL" when you\'re ready.';
      case 'unknown': return 'I\'m not sure what you mean. Try saying "Add chicken biryani".';
      case 'error': return 'Something went wrong. Please try again.';
      default: return 'What would you like to do?';
    }
  }

  static String _languageName(String code) {
    switch (code) {
      case 'hi-IN': return 'Hindi';
      case 'kn-IN': return 'Kannada';
      case 'ta-IN': return 'Tamil';
      case 'te-IN': return 'Telugu';
      case 'bn-IN': return 'Bengali';
      case 'mr-IN': return 'Marathi';
      case 'gu-IN': return 'Gujarati';
      case 'ml-IN': return 'Malayalam';
      case 'od-IN': return 'Odia';
      case 'pa-IN': return 'Punjabi';
      case 'en-IN': return 'English';
      default: return 'the same language as the user';
    }
  }
}
