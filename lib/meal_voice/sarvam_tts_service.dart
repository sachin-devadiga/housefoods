import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../core/constants/app_constants.dart';

/// Sarvam AI Text-to-Speech service.
///
/// Converts text to natural-sounding Indian voices using Sarvam's
/// Bulbul v3 TTS model.
class SarvamTTSService {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isInitialized = false;
  bool _isSpeaking = false;
  Completer<void>? _speakCompleter;
  String _apiKey = '';

  bool get isInitialized => _isInitialized;
  bool get isSpeaking => _isSpeaking;

  static const Map<String, String> speakers = {
    'meera': 'Meera (Female, Hindi)',
    'shubh': 'Shubh (Male, Hindi)',
    'aditya': 'Aditya (Male, Hindi)',
  };

  Future<bool> initialize() async {
    _apiKey = AppConstants.sarvamApiKey;
    if (_apiKey.isEmpty) {
      debugPrint('[SarvamTTS] WARNING: No API key configured');
      _isInitialized = false;
      return false;
    }

    _audioPlayer.onPlayerComplete.listen((_) {
      _isSpeaking = false;
      if (_speakCompleter != null && !_speakCompleter!.isCompleted) {
        _speakCompleter!.complete();
      }
    });

    _isInitialized = true;
    debugPrint('[SarvamTTS] Initialized');
    return true;
  }

  /// Convert text to speech and play it.
  Future<void> speak(String text, {
    String languageCode = 'hi-IN',
    String speaker = 'meera',
  }) async {
    if (!_isInitialized || text.isEmpty) return;

    if (_isSpeaking) {
      await stop();
      await Future.delayed(const Duration(milliseconds: 100));
    }

    try {
      final audioBytes = await _synthesize(text, languageCode: languageCode, speaker: speaker);
      if (audioBytes == null) {
        debugPrint('[SarvamTTS] Synthesis failed');
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final audioFile = File('${tempDir.path}/sarvam_tts_${DateTime.now().millisecondsSinceEpoch}.wav');
      await audioFile.writeAsBytes(audioBytes);

      _speakCompleter = Completer<void>();
      _isSpeaking = true;

      await _audioPlayer.play(DeviceFileSource(audioFile.path));

      await _speakCompleter!.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('[SarvamTTS] Speech timeout');
          _isSpeaking = false;
        },
      );

      // ignore: avoid_slow_async_io
      if (await audioFile.exists()) {
        await audioFile.delete();
      }
    } catch (e) {
      debugPrint('[SarvamTTS] Speak error: $e');
      _isSpeaking = false;
    }
  }

  Future<List<int>?> _synthesize(String text, {
    String languageCode = 'hi-IN',
    String speaker = 'meera',
  }) async {
    try {
      final uri = Uri.parse('${AppConstants.sarvamBaseUrl}/text-to-speech');

      final response = await http.post(
        uri,
        headers: {
          'api-subscription-key': _apiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'text': text,
          'language_code': languageCode,
          'model': AppConstants.sarvamTtsModel,
          'speaker': speaker,
        }),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('TTS request timed out');
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final audios = data['audios'] as List?;
        if (audios != null && audios.isNotEmpty) {
          final base64Audio = audios[0] as String;
          return base64Decode(base64Audio);
        }
      } else {
        debugPrint('[SarvamTTS] API error ${response.statusCode}: ${response.body}');
      }

      return null;
    } catch (e) {
      debugPrint('[SarvamTTS] Synthesize error: $e');
      return null;
    }
  }

  Future<void> stop() async {
    try {
      await _audioPlayer.stop();
      _isSpeaking = false;
      if (_speakCompleter != null && !_speakCompleter!.isCompleted) {
        _speakCompleter!.complete();
      }
    } catch (e) {
      debugPrint('[SarvamTTS] Stop error: $e');
    }
  }

  static String detectLanguage(String text) {
    if (text.contains(RegExp(r'[\u0900-\u097F]'))) {
      return 'hi-IN';
    }
    final lowerText = text.toLowerCase();
    if (lowerText.contains(RegExp(r'\b(hai|kya|karo|karna|bolo|suno|nahi|haan|acha|theek)\b'))) {
      return 'hi-IN';
    }
    return 'en-IN';
  }

  void dispose() {
    _audioPlayer.dispose();
    _isInitialized = false;
    _isSpeaking = false;
  }
}
