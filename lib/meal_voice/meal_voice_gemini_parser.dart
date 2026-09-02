import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../core/constants/app_constants.dart';
import 'meal_voice_command.dart';
import 'meal_voice_command_parser.dart';

/// Gemini-based command parser for MEAL Voice Engine.
///
/// Uses Google Gemini to interpret natural language food orders
/// and return structured [MealVoiceCommand] objects.
///
/// Gemini ONLY interprets speech — it never modifies cart, orders, or prices.
/// The backend remains the source of truth for all product data.
class GeminiMealVoiceCommandParser implements MealVoiceCommandParser {
  GenerativeModel? _model;
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
  "intent": "add" | "remove" | "clear_cart" | "confirm" | "cancel" | "unknown" | "needs_clarification",
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
''';

  /// Initialize the Gemini model.
  Future<bool> initialize() async {
    final apiKey = AppConstants.geminiApiKey;
    if (apiKey.isEmpty) {
      debugPrint('[MEAL Gemini] No API key configured');
      _isAvailable = false;
      return false;
    }

    try {
      _model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: apiKey,
        systemInstruction: Content.system(_systemPrompt),
        generationConfig: GenerationConfig(
          temperature: 0.1, // Low temperature for consistent structured output
          topP: 0.8,
          maxOutputTokens: 512,
        ),
      );
      _isAvailable = true;
      debugPrint('[MEAL Gemini] Initialized');
      return true;
    } catch (e) {
      debugPrint('[MEAL Gemini] Init failed: $e');
      _isAvailable = false;
      return false;
    }
  }

  @override
  MealVoiceCommand parse(String transcript) {
    // parse is synchronous — actual Gemini call is async
    // This is called for interface compliance; use parseAsync for real parsing
    return _parseSyncFallback(transcript);
  }

  /// Async parse using Gemini. Falls back to regex on any failure.
  Future<MealVoiceCommand> parseAsync(String transcript) async {
    if (!_isAvailable || _model == null) {
      debugPrint('[MEAL Gemini] Not available, using regex fallback');
      return _parseSyncFallback(transcript);
    }

    try {
      final response = await _model!.generateContent([
        Content.text(transcript),
      ]);

      final text = response.text;
      if (text == null || text.isEmpty) {
        debugPrint('[MEAL Gemini] Empty response');
        return _parseSyncFallback(transcript);
      }

      return _parseGeminiResponse(text, transcript);
    } catch (e) {
      debugPrint('[MEAL Gemini] Error: $e');
      return _parseSyncFallback(transcript);
    }
  }

  /// Parse Gemini's JSON response into a MealVoiceCommand.
  MealVoiceCommand _parseGeminiResponse(String responseText, String rawTranscript) {
    try {
      // Clean response — remove markdown code fences if present
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

      // Map intent string to enum
      final intent = _mapIntent(intentStr);

      // Parse items
      final items = itemsList.map((item) {
        final map = item as Map<String, dynamic>;
        return MealVoiceItem(
          itemName: map['item_name'] as String? ?? '',
          quantity: (map['quantity'] as num?)?.toInt() ?? 1,
        );
      }).where((item) => item.itemName.isNotEmpty).toList();

      // If needs_clarification, return unknown with clarification message
      if (intent == MealVoiceIntent.unknown && clarification != null) {
        return MealVoiceCommand(
          intent: MealVoiceIntent.unknown,
          items: [],
          rawText: rawTranscript,
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

  /// Map Gemini intent string to MealVoiceIntent enum.
  MealVoiceIntent _mapIntent(String intent) {
    switch (intent.toLowerCase()) {
      case 'add':
        return MealVoiceIntent.add;
      case 'remove':
        return MealVoiceIntent.remove;
      case 'clear_cart':
        return MealVoiceIntent.remove; // Map to remove with empty items
      case 'confirm':
        return MealVoiceIntent.confirm;
      case 'cancel':
        return MealVoiceIntent.cancel;
      case 'needs_clarification':
        return MealVoiceIntent.unknown;
      default:
        return MealVoiceIntent.unknown;
    }
  }

  /// Synchronous fallback using regex parser.
  MealVoiceCommand _parseSyncFallback(String transcript) {
    // Import and use the regex parser as fallback
    return RegexMealVoiceCommandParser().parse(transcript);
  }

  @override
  MealVoiceConfirmation parseConfirmation(String transcript) {
    return ConfirmationConfig.parse(transcript);
  }
}
