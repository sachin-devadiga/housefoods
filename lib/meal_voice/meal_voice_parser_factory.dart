import 'package:flutter/foundation.dart';
import 'meal_voice_command_parser.dart';
import 'meal_voice_gemini_parser.dart';

/// Factory for creating the appropriate command parser.
///
/// Strategy: Try Gemini first, fall back to Regex if unavailable or fails.
/// The controller calls [getParser] to get the current parser.
class MealVoiceParserFactory {
  static GeminiMealVoiceCommandParser? _geminiParser;
  static RegexMealVoiceCommandParser? _regexParser;
  static bool _geminiInitialized = false;

  /// Get the best available parser.
  ///
  /// Returns Gemini parser if available and initialized,
  /// otherwise returns the regex parser.
  static MealVoiceCommandParser getParser() {
    if (_geminiParser != null && _geminiParser!.isAvailable) {
      return _geminiParser!;
    }
    return getRegexParser();
  }

  /// Get the Gemini parser specifically.
  static GeminiMealVoiceCommandParser getGeminiParser() {
    _geminiParser ??= GeminiMealVoiceCommandParser();
    return _geminiParser!;
  }

  /// Get the regex parser.
  static RegexMealVoiceCommandParser getRegexParser() {
    _regexParser ??= RegexMealVoiceCommandParser();
    return _regexParser!;
  }

  /// Initialize the Gemini parser. Returns true if successful.
  static Future<bool> initializeGemini() async {
    if (_geminiInitialized) return _geminiParser?.isAvailable ?? false;

    final parser = getGeminiParser();
    final success = await parser.initialize();
    _geminiInitialized = true;

    if (success) {
      debugPrint('[MEAL Parser] Gemini parser ready');
    } else {
      debugPrint('[MEAL Parser] Gemini unavailable — using regex fallback');
    }

    return success;
  }

  /// Check if Gemini is available.
  static bool get isGeminiAvailable => _geminiParser?.isAvailable ?? false;

  /// Get parser name for debugging.
  static String get currentParserName {
    if (isGeminiAvailable) return 'Gemini';
    return 'Regex';
  }

  /// Reset all parsers (for testing).
  static void reset() {
    _geminiParser = null;
    _regexParser = null;
    _geminiInitialized = false;
  }
}
