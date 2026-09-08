import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../core/constants/app_constants.dart';
import '../core/services/token_service.dart';

/// Text-to-Speech service via MEALIN backend proxy.
///
/// Sends text to MEALIN backend which proxies to Sarvam AI.
/// The Sarvam API key never leaves the server.
class SarvamTTSService {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isInitialized = false;
  bool _isSpeaking = false;
  Completer<void>? _speakCompleter;
  String? _authToken;
  bool _listenerRegistered = false;

  bool get isInitialized => _isInitialized;
  bool get isSpeaking => _isSpeaking;

  static const Map<String, String> speakers = {
    'shruti': 'Shruti (Female, Hindi)',
    'shubh': 'Shubh (Male, Hindi)',
    'aditya': 'Aditya (Male, Hindi)',
    'tanya': 'Tanya (Female, Hindi)',
    'kavya': 'Kavya (Female, Hindi)',
  };

  Future<bool> initialize() async {
    final tokenService = TokenService();
    _authToken = await tokenService.getAccessToken();
    if (_authToken == null || _authToken!.isEmpty) {
      debugPrint('[SarvamTTS] WARNING: No auth token — TTS unavailable until logged in');
      _isInitialized = false;
      return false;
    }

    if (!_listenerRegistered) {
      _audioPlayer.onPlayerComplete.listen((_) {
        _isSpeaking = false;
        if (_speakCompleter != null && !_speakCompleter!.isCompleted) {
          _speakCompleter!.complete();
        }
      });
      _listenerRegistered = true;
    }

    _isInitialized = true;
    debugPrint('[SarvamTTS] Initialized (backend proxy)');
    return true;
  }

  /// Refresh auth token (call after login/token refresh).
  Future<void> refreshToken() async {
    final tokenService = TokenService();
    _authToken = await tokenService.getAccessToken();
  }

  /// Convert text to speech and play it.
  /// Returns true if audio was played, false on any failure.
  Future<bool> speak(String text, {
    String languageCode = 'hi-IN',
    String speaker = 'shruti',
  }) async {
    if (!_isInitialized || text.isEmpty) {
      debugPrint('[SarvamTTS] speak() skipped: initialized=$_isInitialized, empty=${text.isEmpty}');
      return false;
    }

    await refreshToken();

    if (_authToken == null || _authToken!.isEmpty) {
      debugPrint('[SarvamTTS] No auth token after refresh');
      return false;
    }

    if (_isSpeaking) {
      await stop();
      await Future.delayed(const Duration(milliseconds: 100));
    }

    try {
      debugPrint('[SarvamTTS] Synthesizing: "${text.substring(0, text.length.clamp(0, 50))}..." (lang=$languageCode, speaker=$speaker)');
      final audioBytes = await _synthesize(text, languageCode: languageCode, speaker: speaker);
      if (audioBytes == null || audioBytes.isEmpty) {
        debugPrint('[SarvamTTS] Synthesis returned null/empty — FAIL');
        return false;
      }
      debugPrint('[SarvamTTS] Got ${audioBytes.length} bytes of audio');

      final tempDir = await getTemporaryDirectory();
      final audioFile = File('${tempDir.path}/sarvam_tts_${DateTime.now().millisecondsSinceEpoch}.wav');
      await audioFile.writeAsBytes(audioBytes);

      _speakCompleter = Completer<void>();
      _isSpeaking = true;

      debugPrint('[SarvamTTS] Playing audio file...');
      await _audioPlayer.play(DeviceFileSource(audioFile.path));

      await _speakCompleter!.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('[SarvamTTS] Speech playback timeout (30s)');
          _isSpeaking = false;
          if (_speakCompleter != null && !_speakCompleter!.isCompleted) {
            _speakCompleter!.complete();
          }
        },
      );

      if (await audioFile.exists()) {
        await audioFile.delete();
      }

      debugPrint('[SarvamTTS] speak() completed successfully');
      return true;
    } catch (e) {
      debugPrint('[SarvamTTS] speak() FAILED: $e');
      _isSpeaking = false;
      return false;
    }
  }

  Future<List<int>?> _synthesize(String text, {
    String languageCode = 'hi-IN',
    String speaker = 'shruti',
  }) async {
    try {
      final uri = Uri.parse('${AppConstants.apiBaseUrl}/api/auth/voice/tts/');
      debugPrint('[SarvamTTS] POST $uri');

      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $_authToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'text': text,
          'language_code': languageCode,
          'model': 'bulbul:v3',
          'speaker': speaker,
        }),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('TTS request timed out');
        },
      );

      debugPrint('[SarvamTTS] Backend response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final audios = data['audios'] as List?;
        if (audios != null && audios.isNotEmpty) {
          final base64Audio = audios[0] as String;
          return base64Decode(base64Audio);
        }
        debugPrint('[SarvamTTS] Response has no audios: ${response.body.substring(0, response.body.length.clamp(0, 200))}');
      } else {
        debugPrint('[SarvamTTS] Backend error ${response.statusCode}: ${response.body.substring(0, response.body.length.clamp(0, 200))}');
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
