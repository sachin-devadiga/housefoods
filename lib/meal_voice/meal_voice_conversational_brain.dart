import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/constants/app_constants.dart';
import '../core/services/token_service.dart';
import 'meal_voice_conversation.dart';

/// Conversational Gemini brain for the MEAL voice assistant.
///
/// Sends the user's transcript along with full conversation context
/// (history, cart, search results) to Gemini via the backend proxy.
/// Gemini returns a natural response + optional actions.
class MealVoiceConversationalBrain {
  String? _authToken;

  Future<void> refreshToken() async {
    final tokenService = TokenService();
    _authToken = await tokenService.getAccessToken();
  }

  /// The system prompt that defines MEAL's conversational behavior.
  static const String _systemPrompt = '''
You are MEAL, the voice assistant for MEALIN food ordering app. You ONLY help with food ordering on MEALIN.

STRICT SCOPE — You ONLY handle these topics:
- Searching and browsing restaurants and menus
- Food recommendations and descriptions
- Adding/removing items from cart
- Cart contents and totals
- Placing and tracking orders
- Delivery status and estimated times
- Payment and wallet
- Account/profile related to ordering
- How to use MEALIN features
- Past orders and order history
- Coupons and discounts

If the user asks about ANYTHING outside this scope (politics, general knowledge, math, weather, jokes, coding, etc.), respond with:
{"response": "I'm MEAL, your food ordering assistant. I can help you find restaurants, browse menus, and place orders on MEALIN. What would you like to eat?", "actions": []}

Never discuss topics outside MEALIN food ordering. Redirect every off-topic question back to food ordering.

BEHAVIOR:
- Be conversational, warm, helpful — like a knowledgeable friend who knows the local food scene.
- Remember earlier context, follow-ups like "that", "it", "the first one", "make it two".
- Handle preferences: "spicy", "under 200", "vegetarian". Switch languages naturally.
- Keep responses concise for voice — 1-3 sentences.

LANGUAGE RULES:
- Detect user's language. Respond in THE SAME language.
- Mixed language input → respond in same mixed style.
- Action item_name fields: ALWAYS English. Response text: user's language.

RULES:
- NEVER invent prices, availability, delivery times. Use context data only.
- NEVER directly modify cart — REQUEST actions, app validates/executes.
- For place_order, always request confirmation first.
- Never say "As an AI" — just be MEAL.

RESPONSE FORMAT (JSON only, no markdown):
{"response": "Your reply in user's language", "actions": [{"type": "action_type", ...}]}

ACTION TYPES:
- search_menu: {"type": "search_menu", "query": "...", "restaurant": "optional"}
- add_to_cart: {"type": "add_to_cart", "item_name": "...", "quantity": 1, "restaurant": "optional"}
- remove_from_cart: {"type": "remove_from_cart", "item_name": "..."}
- clear_cart: {"type": "clear_cart"}
- show_cart: {"type": "show_cart"}
- place_order: {"type": "place_order"}
- none/empty: just conversational, empty actions array

CONTEXT: History, search results, cart state provided in context. Use them for follow-ups.
''';

  /// Models approved by the server-side proxy.
  static const List<String> _models = [
    'gemini-2.5-flash-lite',
  ];

  /// Send a conversational turn to Gemini and get response + actions.
  Future<ConversationalResponse?> chat({
    required String userTranscript,
    required MealVoiceConversation conversation,
  }) async {
    await refreshToken();
    if (_authToken == null || _authToken!.isEmpty) {
      debugPrint('[MEAL Brain] No auth token');
      return null;
    }

    try {
      final uri = Uri.parse('${AppConstants.apiBaseUrl}/api/auth/voice/gemini/');
      debugPrint('[MEAL Brain] URL: $uri');

      // Build the conversation history for Gemini
      final history = conversation.buildGeminiHistory();
      final context = conversation.buildContext();

      // The latest user message is the last item in history
      final currentUserMessage = history.isNotEmpty ? (history.last['content'] ?? userTranscript) : userTranscript;
      debugPrint('[MEAL Brain] Prompt (${currentUserMessage.length} chars): ${currentUserMessage.substring(0, currentUserMessage.length > 80 ? 80 : currentUserMessage.length)}...');

      // Try models in order — fallback if one returns 502
      for (final model in _models) {
        debugPrint('[MEAL Brain] Trying model: $model');

        final requestPayload = jsonEncode({
          'prompt': currentUserMessage,
          'system_prompt': _systemPrompt,
          'model': model,
          'temperature': 0.7,
          'max_output_tokens': 300,
          'conversation_history': history.length > 1
              ? history.sublist(0, history.length - 1)
              : [],
          'context': context,
        });
        debugPrint('[MEAL Brain] Payload: ${requestPayload.length} bytes, history: ${history.length} turns');

        final response = await http.post(
          uri,
          headers: {
            'Authorization': 'Bearer $_authToken',
            'Content-Type': 'application/json',
          },
        body: requestPayload,
      ).timeout(const Duration(seconds: 20));

        debugPrint('[MEAL Brain] $model → HTTP ${response.statusCode} (${response.body.length} bytes)');

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final text = data['text'] as String?;
          if (text != null && text.trim().isNotEmpty) {
            debugPrint('[MEAL Brain] $model SUCCESS: ${text.substring(0, text.length > 100 ? 100 : text.length)}...');
            return _parseResponse(text.trim());
          }
          debugPrint('[MEAL Brain] $model returned empty text');
        } else {
          debugPrint('[MEAL Brain] $model FAILED: ${(response.body.length > 300 ? response.body.substring(0, 300) : response.body)}');
          // If 502 (model unavailable), try the next approved model.
          if (response.statusCode != 502) {
            return null;
          }
        }
      }

      debugPrint('[MEAL Brain] All models failed');
      return null;
    } catch (e) {
      debugPrint('[MEAL Brain] Exception: $e');
      return null;
    }
  }

  /// Robustly parse Gemini's JSON response, handling common issues.
  ConversationalResponse? _parseResponse(String text) {
    try {
      // Strip markdown code fences if present
      var cleaned = text.trim();
      if (cleaned.startsWith('```json')) {
        cleaned = cleaned.substring(7);
      } else if (cleaned.startsWith('```')) {
        cleaned = cleaned.substring(3);
      }
      if (cleaned.endsWith('```')) {
        cleaned = cleaned.substring(0, cleaned.length - 3);
      }
      cleaned = cleaned.trim();

      debugPrint('[MEAL Brain] Parsing JSON (${cleaned.length} chars): ${cleaned.substring(0, cleaned.length > 150 ? 150 : cleaned.length)}...');
      final json = jsonDecode(cleaned) as Map<String, dynamic>;
      final result = ConversationalResponse.fromJson(json);
      debugPrint('[MEAL Brain] Parsed OK: response=${result.response.length} chars, actions=${result.actions.length}');
      return result;
    } catch (e) {
      debugPrint('[MEAL Brain] JSON parse FAILED: $e');
      debugPrint('[MEAL Brain] Raw text (${text.length} chars): ${text.substring(0, text.length > 200 ? 200 : text.length)}...');

      // Fallback: try to extract response field only
      try {
        final responseMatch = RegExp(r'"response"\s*:\s*"([^"]*)"').firstMatch(text);
        if (responseMatch != null) {
          return ConversationalResponse(
            response: responseMatch.group(1)!,
            actions: [],
          );
        }
      } catch (_) {}

      // Last resort: use the raw text as the response
      if (text.isNotEmpty && !text.contains('{')) {
        return ConversationalResponse(response: text, actions: []);
      }
      return null;
    }
  }
}
