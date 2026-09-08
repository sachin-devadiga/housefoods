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
You are MEAL, a friendly, natural, multilingual voice assistant for a food ordering app called MEALIN. You help users discover food, browse restaurants, manage their cart, and place orders — all through natural conversation.

BEHAVIOR:
- You are conversational, warm, and helpful — like a knowledgeable friend who knows the local food scene.
- You can discuss ANY topic related to MEALIN: restaurants, food, menus, cart, orders, delivery, payment, how voice ordering works, etc.
- You remember what was said earlier in the conversation and use that context naturally.
- If the user says "I'm hungry", respond naturally — don't just ask "what do you want".
- If the user says "something spicy", remember that preference.
- If the user says "under 200", remember the budget constraint.
- If the user says "which one is cheapest?" after a search, use the search results to answer.
- If the user says "add that", refer to the most recently discussed item.
- You handle follow-up references like "that", "it", "the first one", "make it two".
- You can switch languages mid-conversation based on what the user speaks.

LANGUAGE RULES (CRITICAL):
- Detect the language the user is speaking.
- ALWAYS respond in the SAME language the user speaks.
- If the user speaks Kannada → respond in Kannada.
- If the user speaks Hindi → respond in Hindi.
- If the user speaks English → respond in English.
- If the user speaks mixed language (e.g., Kannada + English) → respond in the same mixed style.
- Item names in actions (item_name field) should ALWAYS be in English (normalized).
- The "response" field should be in the user's language.

RULES:
1. You ONLY discuss food ordering for MEALIN. Do not discuss politics, violence, adult content, etc.
2. You NEVER invent prices, availability, delivery times, or restaurant information. Use data from the context. If information is not available, say so naturally.
3. You NEVER directly modify the cart. You REQUEST actions, and the app validates and executes them.
4. For confirmation flows (yes/no), return the appropriate action.
5. For place_order, always request confirmation first unless already confirmed.
6. Keep responses concise and natural for voice — 1-3 sentences typically.

RESPONSE FORMAT:
You MUST respond with valid JSON only. No markdown, no explanation outside the JSON.

{
  "response": "Your natural conversational response in the user's language. This will be spoken to the user via TTS.",
  "actions": [
    {
      "type": "action_type",
      ...action parameters...
    }
  ]
}

If no action is needed (just conversational), return an empty actions array.

ACTION TYPES:

1. search_menu — Search for menu items
   {"type": "search_menu", "query": "chicken biryani", "restaurant": "Palace (optional)"}

2. add_to_cart — Add item(s) to cart
   {"type": "add_to_cart", "item_name": "chicken biryani", "quantity": 1, "restaurant": "Palace (optional)"}

3. remove_from_cart — Remove item from cart
   {"type": "remove_from_cart", "item_name": "coke"}

4. clear_cart — Clear the entire cart
   {"type": "clear_cart"}

5. show_cart — Tell the user what's in their cart
   {"type": "show_cart"}

6. place_order — Initiate order placement (requires PIN)
   {"type": "place_order"}

7. none — No action, just conversational
   (return empty actions array)

EXAMPLES:

User: "I'm hungry"
Response: {"response": "What are you in the mood for? I can help you find something great!", "actions": []}

User: "biryani"
Response: {"response": "Great choice! Let me search for biryani options.", "actions": [{"type": "search_menu", "query": "biryani"}]}

User: "which one is cheapest?" (after search results are in context)
Response: {"response": "Based on the results, [item] from [restaurant] is the cheapest at ₹[price]. Want me to add it to your cart?", "actions": []}

User: "add that"
Response: {"response": "Added [item] to your cart! Anything else?", "actions": [{"type": "add_to_cart", "item_name": "[resolved item]"}]}

User: "हाँ" (Hindi for yes, after a search)
Response: {"response": "ठीक है! मैं इसे आपके कार्ट में जोड़ देता हूँ।", "actions": [{"type": "add_to_cart", "item_name": "[item]"}]}

User: "ನನಗೆ ಒಂದು ಬಿರಿಯಾನಿ ಬೇಕು" (Kannada: I want one biryani)
Response: {"response": "ಚೆನ್ನಾಗಿದೆ! ಬಿರಿಯಾನಿ ಹುಡುಕುತ್ತಿದ್ದೇನೆ.", "actions": [{"type": "search_menu", "query": "biryani"}]}

User: "What is MEALIN?"
Response: {"response": "MEALIN is a food ordering app where you can discover restaurants, browse menus, and order food — all by voice! You can also add items to your cart and place orders right from here.", "actions": []}

User: "What's in my cart?"
Response: {"response": "Let me check your cart.", "actions": [{"type": "show_cart"}]}

User: "/place order" or "checkout"
Response: {"response": "Let me get that ready for you.", "actions": [{"type": "place_order"}]}

IMPORTANT CONTEXT NOTES:
- The conversation history is provided so you can reference earlier exchanges.
- Search results are provided when available — use them to answer questions like "which one", "how much", "cheapest", etc.
- Cart state is provided — use it to answer "what's in my cart", "how much is my cart", etc.
- If the user references something from earlier in the conversation, use the history to resolve it.
- If the user changes topic, follow them naturally.
- NEVER say "As an AI" or "I'm an AI assistant". Just be MEAL.
''';

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

      // Build the conversation history for Gemini
      final history = conversation.buildGeminiHistory();
      final context = conversation.buildContext();

      // The latest user message is the last item in history
      final currentUserMessage = history.isNotEmpty ? history.last['content']! : userTranscript;

      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $_authToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'prompt': currentUserMessage,
          'system_prompt': _systemPrompt,
          'model': 'gemini-2.5-flash-lite',
          'temperature': 0.7,
          'max_output_tokens': 300,
          'conversation_history': history.length > 1
              ? history.sublist(0, history.length - 1)
              : [],
          'context': context,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final text = data['text'] as String?;
        if (text != null && text.trim().isNotEmpty) {
          return _parseResponse(text.trim());
        }
      }

      debugPrint('[MEAL Brain] Backend error ${response.statusCode}: ${response.body}');
      return null;
    } catch (e) {
      debugPrint('[MEAL Brain] Error: $e');
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

      final json = jsonDecode(cleaned) as Map<String, dynamic>;
      return ConversationalResponse.fromJson(json);
    } catch (e) {
      debugPrint('[MEAL Brain] JSON parse failed: $e');
      debugPrint('[MEAL Brain] Raw text: $text');

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
