import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/constants/app_constants.dart';
import '../core/services/token_service.dart';

/// Speech-to-Text service via MEALIN backend proxy.
///
/// Sends audio to MEALIN backend which proxies to Sarvam AI.
/// The Sarvam API key never leaves the server.
class SarvamSTTResult {
  final String transcript;
  final String? languageCode;
  SarvamSTTResult(this.transcript, this.languageCode);
}

class SarvamSTTService {
  bool _isInitialized = false;
  bool _isRecording = false;
  bool get isInitialized => _isInitialized;
  bool get isRecording => _isRecording;

  String? _authToken;

  /// Last error message — checked by controller for debug logging.
  String? _lastError;
  String? get lastError => _lastError;

  Future<bool> initialize() async {
    final tokenService = TokenService();
    _authToken = await tokenService.getAccessToken();
    if (_authToken == null || _authToken!.isEmpty) {
      _lastError = 'No auth token — user not logged in';
      debugPrint('[SarvamSTT] WARNING: $_lastError');
      _isInitialized = false;
      return false;
    }
    _lastError = null;
    _isInitialized = true;
    debugPrint('[SarvamSTT] Initialized (backend proxy)');
    return true;
  }

  /// Refresh auth token (call after login/token refresh).
  Future<void> refreshToken() async {
    final tokenService = TokenService();
    _authToken = await tokenService.getAccessToken();
  }

  /// Transcribe audio from a file path, returning transcript and detected language.
  Future<SarvamSTTResult?> transcribeFile(String filePath, {String languageCode = 'auto'}) async {
    if (!_isInitialized) {
      _lastError = 'Not initialized (no auth token)';
      debugPrint('[SarvamSTT] Not initialized');
      return null;
    }

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        _lastError = 'Audio file not found: $filePath';
        debugPrint('[SarvamSTT] $_lastError');
        return null;
      }

      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        _lastError = 'Audio file is empty (0 bytes)';
        debugPrint('[SarvamSTT] $_lastError');
        return null;
      }
      return await transcribeBytes(bytes, languageCode: languageCode);    } catch (e) {
      _lastError = 'File read error: $e';
      debugPrint('[SarvamSTT] $_lastError');
      return null;
    }
  }

  /// Transcribe raw audio bytes, returning transcript and detected language.
  Future<SarvamSTTResult?> transcribeBytes(List<int> audioBytes, {String languageCode = 'auto'}) async {
    if (!_isInitialized) {
      _lastError = 'Not initialized';
      debugPrint('[SarvamSTT] Not initialized');
      return null;
    }

    // Refresh token in case it was updated since initialization
    await refreshToken();

    if (_authToken == null || _authToken!.isEmpty) {
      _lastError = 'No auth token after refresh';
      debugPrint('[SarvamSTT] $_lastError');
      return null;
    }

    try {
      final uri = Uri.parse('${AppConstants.apiBaseUrl}/api/auth/voice/stt/');

      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $_authToken';
      request.fields['model'] = 'saaras:v4';
      if (languageCode != 'auto') {
        request.fields['language_code'] = languageCode;
      }

      request.files.add(http.MultipartFile.fromBytes(
        'file',
        audioBytes,
        filename: 'audio.wav',
      ));

      debugPrint('[SarvamSTT] Sending ${audioBytes.length} bytes to backend proxy...');

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('STT request timed out (30s)');
        },
      );

      final response = await http.Response.fromStream(streamedResponse);
      debugPrint('[SarvamSTT] Backend response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final transcript = data['transcript'] as String?;
        final lang = data['language_code'] as String?;
        debugPrint('[SarvamSTT] Transcript: "$transcript" (lang: $lang)');
        _lastError = null;
        if (transcript != null && transcript.isNotEmpty) {
          return SarvamSTTResult(transcript, lang);
        }
        return null;
      } else {
        final body = response.body.length > 300
            ? response.body.substring(0, 300)
            : response.body;
        _lastError = 'Backend ${response.statusCode}: $body';
        debugPrint('[SarvamSTT] $_lastError');
      }

      return null;
    } on TimeoutException catch (e) {
      _lastError = 'Timeout: $e';
      debugPrint('[SarvamSTT] $_lastError');
      return null;
    } on SocketException catch (e) {
      _lastError = 'Network error: $e';
      debugPrint('[SarvamSTT] $_lastError');
      return null;
    } catch (e) {
      _lastError = 'Error: $e';
      debugPrint('[SarvamSTT] $_lastError');
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
