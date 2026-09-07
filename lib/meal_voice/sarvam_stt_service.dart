import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/constants/app_constants.dart';

/// Sarvam AI Speech-to-Text service.
///
/// Sends audio to Sarvam's cloud STT API for transcription.
/// Supports 22 Indian languages with automatic language detection.
class SarvamSTTService {
  bool _isInitialized = false;
  bool _isRecording = false;
  bool get isInitialized => _isInitialized;
  bool get isRecording => _isRecording;

  String _apiKey = '';

  Future<bool> initialize() async {
    _apiKey = AppConstants.sarvamApiKey;
    if (_apiKey.isEmpty) {
      debugPrint('[SarvamSTT] WARNING: No API key configured');
      _isInitialized = false;
      return false;
    }
    _isInitialized = true;
    debugPrint('[SarvamSTT] Initialized with API key');
    return true;
  }

  /// Transcribe audio from a file path.
  Future<String?> transcribeFile(String filePath, {String languageCode = 'auto'}) async {
    if (!_isInitialized) {
      debugPrint('[SarvamSTT] Not initialized');
      return null;
    }

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('[SarvamSTT] Audio file not found: $filePath');
        return null;
      }

      final bytes = await file.readAsBytes();
      return await transcribeBytes(bytes, languageCode: languageCode);
    } catch (e) {
      debugPrint('[SarvamSTT] Transcribe file error: $e');
      return null;
    }
  }

  /// Transcribe raw audio bytes.
  Future<String?> transcribeBytes(List<int> audioBytes, {String languageCode = 'auto'}) async {
    if (!_isInitialized) {
      debugPrint('[SarvamSTT] Not initialized');
      return null;
    }

    try {
      final uri = Uri.parse('${AppConstants.sarvamBaseUrl}/speech-to-text');

      final request = http.MultipartRequest('POST', uri);
      request.headers['api-subscription-key'] = _apiKey;
      request.fields['model'] = AppConstants.sarvamSttModel;
      if (languageCode != 'auto') {
        request.fields['language_code'] = languageCode;
      }

      request.files.add(http.MultipartFile.fromBytes(
        'file',
        audioBytes,
        filename: 'audio.wav',
      ));

      debugPrint('[SarvamSTT] Sending ${audioBytes.length} bytes for transcription...');

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('STT request timed out');
        },
      );

      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final transcript = data['transcript'] as String?;
        final lang = data['language_code'] as String?;
        debugPrint('[SarvamSTT] Transcript: "$transcript" (lang: $lang)');
        return transcript;
      } else {
        debugPrint('[SarvamSTT] API error ${response.statusCode}: ${response.body}');
      }

      return null;
    } catch (e) {
      debugPrint('[SarvamSTT] Transcribe error: $e');
      return null;
    }
  }

  void setRecording(bool recording) {
    _isRecording = recording;
  }

  void dispose() {
    _isInitialized = false;
    _isRecording = false;
  }
}
