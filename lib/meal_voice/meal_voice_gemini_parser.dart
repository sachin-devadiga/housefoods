import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/app_constants.dart';
import '../../core/services/token_service.dart';
import 'meal_voice_command.dart';
import 'meal_voice_command_parser.dart';

/// Gemini-based command parser for MEAL Voice Engine.
///
/// Uses backend proxy to call Google Gemini API.
/// The Gemini API key never leaves the server — same as Sarvam.
///
/// Gemini ONLY interprets speech — it never modifies cart, orders, or prices.
class GeminiMealVoiceCommandParser implements MealVoiceCommandParser {
  String? _authToken;
  bool _isAvailable = false;

  bool get isAvailable => _isAvailable;

  @override
  String get parserName => 'GeminiParser';

  /// The JSON schema prompt that instructs Gemini how to respond.
  static const String _systemPrompt = '''
You are MEAL, a voice assistant for a food ordering app called MEALIN.
Your ONLY job is to understand the user's spoken words and return a structured JSON command.

RULES:
1. You ONLY interpret food orders for restaurants and bakeries.
2. You NEVER invent prices, availability, delivery times, or order IDs.
3. You NEVER modify cart, orders, or payments — you only parse speech.
4. If you cannot confidently understand the command, return "unknown" intent.
5. If the command is ambiguous (e.g., "that thing I ordered"), return "needs_clarification".
6. Extract the restaurant/bakery name ONLY if explicitly mentioned (e.g., "from Palace").
7. Support quantities in any form: "one", "two", "1", "2", "a", "an", "double", "triple".
8. Normalize item names: "biryanis" → "biryani", "burgers" → "burger".
9. For "yes"/"no"/"confirm"/"cancel" responses, return the appropriate confirmation intent.

RESPOND WITH VALID JSON ONLY. No markdown, no explanation, no extra text.

JSON SCHEMA:
{
  "intent": "add" | "remove" | "clear_cart" | "confirm" | "cancel" | "place_order" | "unknown" | "needs_clarification",
  "items": [
    {
      "item_name": "normalized item name",
      "quantity": 1
    }
  ],
  "restaurant": "restaurant name if mentioned, else null",
  "clarification_needed": "question to ask user if needs_clarification, else null"
}

EXAMPLES:

User: "Place the order"
→ {"intent":"place_order","items":[],"restaurant":null,"clarification_needed":null}

User: "Place my order"
→ {"intent":"place_order","items":[],"restaurant":null,"clarification_needed":null}

User: "Checkout"
→ {"intent":"place_order","items":[],"restaurant":null,"clarification_needed":null}

User: "Confirm my order"
→ {"intent":"place_order","items":[],"restaurant":null,"clarification_needed":null}

User: "Add one chicken biryani"
→ {"intent":"add","items":[{"item_name":"chicken biryani","quantity":1}],"restaurant":null,"clarification_needed":null}

User: "Get me two chicken biryanis from Palace and a Coke"
→ {"intent":"add","items":[{"item_name":"chicken biryani","quantity":2},{"item_name":"coke","quantity":1}],"restaurant":"Palace","clarification_needed":null}

User: "I want a chocolate cake from Cake Palace"
→ {"intent":"add","items":[{"item_name":"chocolate cake","quantity":1}],"restaurant":"Cake Palace","clarification_needed":null}

User: "Remove the coke"
→ {"intent":"remove","items":[{"item_name":"coke","quantity":1}],"restaurant":null,"clarification_needed":null}

User: "Clear my cart"
→ {"intent":"clear_cart","items":[],"restaurant":null,"clarification_needed":null}

User: "Yes"
→ {"intent":"confirm","items":[],"restaurant":null,"clarification_needed":null}

User: "No"
→ {"intent":"cancel","items":[],"restaurant":null,"clarification_needed":null}

User: "Cancel that"
→ {"intent":"cancel","items":[],"restaurant":null,"clarification_needed":null}

User: "Get me that thing I ordered yesterday"
→ {"intent":"needs_clarification","items":[],"restaurant":null,"clarification_needed":"Which item would you like to order?"}

User: "Order some food"
→ {"intent":"needs_clarification","items":[],"restaurant":null,"clarification_needed":"What would you like to order?"}

User: "I'm feeling hungry"
→ {"intent":"needs_clarification","items":[],"restaurant":null,"clarification_needed":"What would you like to order?"}

User: "What's good today?"
→ {"intent":"needs_clarification","items":[],"restaurant":null,"clarification_needed":"What type of food are you in the mood for?"}

User: "Surprise me"
→ {"intent":"needs_clarification","items":[],"restaurant":null,"clarification_needed:"What cuisine would you like?"}

User: "Order in Hindi" or "मुझे बिरयानी चाहिए"
→ Parse the language and return appropriate JSON with Hindi item names
''';

  /// Initialize — checks if backend Gemini endpoint is available.
  Future<bool> initialize() async {
    final tokenService = TokenService();
    _authToken = await tokenService.getAccessToken();
    if (_authToken == null || _authToken!.isEmpty) {
      debugPrint('[MEAL Gemini] No auth token — unavailable');
      _isAvailable = false;
      return false;
    }

    // Backend proxy is always available if the server has GEMINI_API_KEY set
    _isAvailable = true;
    debugPrint('[MEAL Gemini] Initialized (backend proxy)');
    return true;
  }

  /// Initialize with user-provided key — now uses backend proxy (key ignored).
  Future<bool> initializeWithKey(String apiKey) async {
    // User key no longer needed — backend has the key
    return initialize();
  }

  /// Refresh auth token.
  Future<void> refreshToken() async {
    final tokenService = TokenService();
    _authToken = await tokenService.getAccessToken();
  }

  @override
  MealVoiceCommand parse(String transcript) {
    return _parseSyncFallback(transcript);
  }

  /// Async parse using Gemini via backend proxy. Falls back to regex on failure.
  Future<MealVoiceCommand> parseAsync(String transcript) async {
    if (!_isAvailable) {
      debugPrint('[MEAL Gemini] Not available, using regex fallback');
      return _parseSyncFallback(transcript);
    }

    await refreshToken();

    if (_authToken == null || _authToken!.isEmpty) {
      debugPrint('[MEAL Gemini] No auth token after refresh');
      return _parseSyncFallback(transcript);
    }

    try {
      final uri = Uri.parse('${AppConstants.apiBaseUrl}/api/auth/voice/gemini/');

      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $_authToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'prompt': transcript,
          'system_prompt': _systemPrompt,
          'model': 'gemini-2.0-flash-lite',
          'temperature': 0.1,
          'max_output_tokens': 512,
        }),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Gemini request timed out'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final text = data['text'] as String?;
        if (text != null && text.isNotEmpty) {
          return _parseGeminiResponse(text, transcript);
        }
      }

      debugPrint('[MEAL Gemini] Backend error ${response.statusCode}: ${response.body}');
      return _parseSyncFallback(transcript);
    } catch (e) {
      debugPrint('[MEAL Gemini] Error: $e');
      return _parseSyncFallback(transcript);
    }
  }

  /// Parse Gemini's JSON response into a MealVoiceCommand.
  MealVoiceCommand _parseGeminiResponse(String responseText, String rawTranscript) {
    try {
      var cleaned = responseText.trim();
      if (cleaned.startsWith('```')) {
        cleaned = cleaned.replaceFirst(RegExp(r'^```\w*\n?'), '');
      }
      if (cleaned.endsWith('```')) {
        cleaned = cleaned.substring(0, cleaned.length - 3);
      }
      cleaned = cleaned.trim();

      final json = jsonDecode(cleaned) as Map<String, dynamic>;

      final intentStr = json['intent'] as String? ?? 'unknown';
      final itemsList = json['items'] as List<dynamic>? ?? [];
      final restaurant = json['restaurant'] as String?;
      final clarification = json['clarification_needed'] as String?;

      final intent = _mapIntent(intentStr);

      final items = itemsList.map((item) {
        final map = item as Map<String, dynamic>;
        return MealVoiceItem(
          itemName: map['item_name'] as String? ?? '',
          quantity: (map['quantity'] as num?)?.toInt() ?? 1,
        );
      }).where((item) => item.itemName.isNotEmpty).toList();

      if (intent == MealVoiceIntent.unknown && clarification != null) {
        return MealVoiceCommand(
          intent: MealVoiceIntent.unknown,
          items: [],
          rawText: rawTranscript,
          clarification: clarification,
        );
      }

      return MealVoiceCommand(
        intent: intent,
        items: items,
        restaurant: restaurant,
        bakery: restaurant,
        rawText: rawTranscript,
      );
    } catch (e) {
      debugPrint('[MEAL Gemini] JSON parse error: $e');
      return _parseSyncFallback(rawTranscript);
    }
  }

  MealVoiceIntent _mapIntent(String intent) {
    switch (intent.toLowerCase()) {
      case 'add':
        return MealVoiceIntent.add;
      case 'remove':
        return MealVoiceIntent.remove;
      case 'clear_cart':
        return MealVoiceIntent.clearCart;
      case 'confirm':
        return MealVoiceIntent.confirm;
      case 'place_order':
        return MealVoiceIntent.placeOrder;
      case 'cancel':
        return MealVoiceIntent.cancel;
      case 'needs_clarification':
        return MealVoiceIntent.unknown;
      default:
        return MealVoiceIntent.unknown;
    }
  }

  MealVoiceCommand _parseSyncFallback(String transcript) {
    return RegexMealVoiceCommandParser().parse(transcript);
  }

  @override
  MealVoiceConfirmation parseConfirmation(String transcript) {
    return ConfirmationConfig.parse(transcript);
  }
}
