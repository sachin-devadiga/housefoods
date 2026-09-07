import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User-configurable settings for the MEAL Voice Engine.
///
/// Stores: language, speaker, AI provider, API key.
/// Persisted to SharedPreferences.
class MealVoiceSettings extends ChangeNotifier {
  // Sarvam supported languages
  static const Map<String, String> sarvamLanguages = {
    'auto': 'Auto Detect',
    'hi-IN': 'Hindi',
    'bn-IN': 'Bengali',
    'gu-IN': 'Gujarati',
    'kn-IN': 'Kannada',
    'ml-IN': 'Malayalam',
    'mr-IN': 'Marathi',
    'od-IN': 'Odia',
    'pa-IN': 'Punjabi',
    'ta-IN': 'Tamil',
    'te-IN': 'Telugu',
    'en-IN': 'English',
  };

  // Sarvam TTS speakers
  static const Map<String, String> sarvamSpeakers = {
    'shruti': 'Shruti (Female)',
    'shubh': 'Shubh (Male)',
    'aditya': 'Aditya (Male)',
    'tanya': 'Tanya (Female)',
    'kavya': 'Kavya (Female)',
  };

  // AI providers for conversation
  static const Map<String, String> aiProviders = {
    'none': 'None (Regex only)',
    'gemini': 'Google Gemini',
    'openai': 'OpenAI',
  };

  // Current settings
  String _languageCode = 'auto';
  String _speaker = 'shruti';
  String _aiProvider = 'none';
  String _apiKey = '';
  bool _voiceEnabled = true;

  // Getters
  String get languageCode => _languageCode;
  String get speaker => _speaker;
  String get aiProvider => _aiProvider;
  String get apiKey => _apiKey;
  bool get voiceEnabled => _voiceEnabled;

  String get languageName => sarvamLanguages[_languageCode] ?? 'Auto Detect';
  String get speakerName => sarvamSpeakers[_speaker] ?? 'Shruti (Female)';
  String get aiProviderName => aiProviders[_aiProvider] ?? 'None';

  /// Load settings from SharedPreferences.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _languageCode = prefs.getString('meal_voice_language') ?? 'auto';
    _speaker = prefs.getString('meal_voice_speaker') ?? 'shruti';
    _aiProvider = prefs.getString('meal_voice_ai_provider') ?? 'none';
    _apiKey = prefs.getString('meal_voice_api_key') ?? '';
    _voiceEnabled = prefs.getBool('meal_voice_enabled') ?? true;
    notifyListeners();
  }

  /// Save all settings to SharedPreferences.
  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('meal_voice_language', _languageCode);
    await prefs.setString('meal_voice_speaker', _speaker);
    await prefs.setString('meal_voice_ai_provider', _aiProvider);
    await prefs.setString('meal_voice_api_key', _apiKey);
    await prefs.setBool('meal_voice_enabled', _voiceEnabled);
  }

  /// Set the voice language for STT/TTS.
  Future<void> setLanguage(String code) async {
    if (_languageCode == code) return;
    _languageCode = code;
    notifyListeners();
    await _save();
  }

  /// Set the TTS speaker voice.
  Future<void> setSpeaker(String speaker) async {
    if (_speaker == speaker) return;
    _speaker = speaker;
    notifyListeners();
    await _save();
  }

  /// Set the AI provider for command parsing.
  Future<void> setAiProvider(String provider) async {
    if (_aiProvider == provider) return;
    _aiProvider = provider;
    notifyListeners();
    await _save();
  }

  /// Set the API key for the AI provider.
  Future<void> setApiKey(String key) async {
    _apiKey = key.trim();
    notifyListeners();
    await _save();
  }

  /// Enable/disable voice assistant.
  Future<void> setVoiceEnabled(bool enabled) async {
    if (_voiceEnabled == enabled) return;
    _voiceEnabled = enabled;
    notifyListeners();
    await _save();
  }

  /// Check if a valid AI key is configured.
  bool get hasAiKey => _aiProvider != 'none' && _apiKey.isNotEmpty;

  /// Get the effective Gemini API key (user-provided or compile-time).
  String? get geminiApiKey {
    if (_aiProvider == 'gemini' && _apiKey.isNotEmpty) return _apiKey;
    return null;
  }

  /// Get the effective OpenAI API key.
  String? get openAiApiKey {
    if (_aiProvider == 'openai' && _apiKey.isNotEmpty) return _apiKey;
    return null;
  }

  /// Get the Sarvam language code for STT (returns null for 'auto').
  String? get sttLanguageCode => _languageCode == 'auto' ? null : _languageCode;

  /// Get the Sarvam language code for TTS.
  String get ttsLanguageCode => _languageCode == 'auto' ? 'hi-IN' : _languageCode;
}
