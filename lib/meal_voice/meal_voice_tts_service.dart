import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// TTS (Text-to-Speech) service for MEAL Voice Engine.
///
/// Handles speech synthesis for voice responses.
/// Separated from controller to allow independent testing and replacement.
class MealVoiceTtsService {
  final FlutterTts _tts = FlutterTts();
  bool _isInitialized = false;
  bool _isSpeaking = false;

  bool get isInitialized => _isInitialized;
  bool get isSpeaking => _isSpeaking;

  /// Initialize TTS engine with appropriate settings.
  Future<bool> initialize() async {
    try {
      await _tts.setLanguage('en-IN');
      await _tts.setSpeechRate(0.45); // Slightly slower for clarity
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);

      _tts.setStartHandler(() {
        _isSpeaking = true;
      });

      _tts.setCompletionHandler(() {
        _isSpeaking = false;
      });

      _tts.setErrorHandler((msg) {
        debugPrint('[MEAL TTS] Error: $msg');
        _isSpeaking = false;
      });

      _isInitialized = true;
      debugPrint('[MEAL TTS] Initialized');
      return true;
    } catch (e) {
      debugPrint('[MEAL TTS] Init failed: $e');
      return false;
    }
  }

  /// Speak the given text. Returns a future that completes when speech finishes.
  Future<void> speak(String text) async {
    if (!_isInitialized) {
      debugPrint('[MEAL TTS] Not initialized, cannot speak');
      return;
    }

    if (text.isEmpty) return;

    try {
      await _tts.speak(text);
      // Wait for completion
      await _waitForCompletion();
    } catch (e) {
      debugPrint('[MEAL TTS] Speak error: $e');
      _isSpeaking = false;
    }
  }

  /// Speak and wait for completion.
  Future<void> speakAndWait(String text) async {
    await speak(text);
  }

  /// Stop current speech.
  Future<void> stop() async {
    try {
      await _tts.stop();
      _isSpeaking = false;
    } catch (e) {
      debugPrint('[MEAL TTS] Stop error: $e');
    }
  }

  /// Wait for current speech to complete.
  Future<void> _waitForCompletion() async {
    final completer = Completer<void>();
    int maxWait = 30000; // 30 second max
    int elapsed = 0;

    while (_isSpeaking && elapsed < maxWait) {
      await Future.delayed(const Duration(milliseconds: 100));
      elapsed += 100;
    }

    if (!completer.isCompleted) {
      completer.complete();
    }

    return completer.future;
  }

  /// Dispose resources.
  void dispose() {
    _tts.stop();
    _isInitialized = false;
  }
}
