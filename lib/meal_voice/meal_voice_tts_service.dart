import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// TTS service for MEAL Voice Engine.
///
/// FIX #15: Replaced broken Completer-based wait with proper TTS completion handler.
/// FIX #16: Added _isSpeaking guard to prevent overlap.
class MealVoiceTtsService {
  final FlutterTts _tts = FlutterTts();
  bool _isInitialized = false;
  bool _isSpeaking = false;
  Completer<void>? _speakCompleter;

  bool get isInitialized => _isInitialized;
  bool get isSpeaking => _isSpeaking;

  Future<bool> initialize() async {
    try {
      await _tts.setLanguage('en-IN');
      await _tts.setSpeechRate(0.45);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);

      _tts.setStartHandler(() {
        _isSpeaking = true;
      });

      _tts.setCompletionHandler(() {
        _isSpeaking = false;
        if (_speakCompleter != null && !_speakCompleter!.isCompleted) {
          _speakCompleter!.complete();
        }
      });

      _tts.setErrorHandler((msg) {
        debugPrint('[MEAL TTS] Error: $msg');
        _isSpeaking = false;
        if (_speakCompleter != null && !_speakCompleter!.isCompleted) {
          _speakCompleter!.complete();
        }
      });

      _isInitialized = true;
      debugPrint('[MEAL TTS] Initialized');
      return true;
    } catch (e) {
      debugPrint('[MEAL TTS] Init failed: $e');
      return false;
    }
  }

  /// Speak text and wait for completion.
  Future<void> speak(String text) async {
    if (!_isInitialized || text.isEmpty) return;

    // Stop any current speech first
    if (_isSpeaking) {
      await stop();
      await Future.delayed(const Duration(milliseconds: 100));
    }

    try {
      _speakCompleter = Completer<void>();
      await _tts.speak(text);

      // Wait for completion callback with timeout
      await _speakCompleter!.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('[MEAL TTS] Speech timeout');
          _isSpeaking = false;
        },
      );
    } catch (e) {
      debugPrint('[MEAL TTS] Speak error: $e');
      _isSpeaking = false;
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
      _isSpeaking = false;
      if (_speakCompleter != null && !_speakCompleter!.isCompleted) {
        _speakCompleter!.complete();
      }
    } catch (e) {
      debugPrint('[MEAL TTS] Stop error: $e');
    }
  }

  void dispose() {
    _tts.stop();
    _isInitialized = false;
    _isSpeaking = false;
  }
}
