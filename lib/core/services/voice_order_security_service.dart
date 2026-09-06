import 'package:flutter/foundation.dart';
import 'api_service.dart';

class VoiceOrderSecurityService {
  final ApiService _api;

  VoiceOrderSecurityService({required ApiService api}) : _api = api;

  Future<void> setToken(String? token) async {
    if (token != null) {
      _api.setToken(token);
    } else {
      _api.clearToken();
    }
  }

  Future<bool> isPinConfigured() async {
    try {
      final response = await _api.get('/api/auth/voice-pin/status/');
      return response['pin_configured'] == true;
    } catch (e) {
      debugPrint('[VoiceSecurity] Status check error: $e');
      return false;
    }
  }

  Future<void> setupPin(String pin) async {
    try {
      await _api.post(
        '/api/auth/voice-pin/setup/',
        body: {'pin': pin},
      );
    } catch (e) {
      debugPrint('[VoiceSecurity] Setup error: $e');
      rethrow;
    }
  }

  Future<VoiceAuthorizationResult> verifyPin(String pin) async {
    try {
      final response = await _api.post(
        '/api/auth/voice-pin/verify/',
        body: {'pin': pin},
      );

      return VoiceAuthorizationResult(
        authorized: response['authorized'] == true,
        authorizationToken: response['authorization_token'] as String?,
        expiresIn: response['expires_in'] as int? ?? 120,
        error: null,
      );
    } catch (e) {
      debugPrint('[VoiceSecurity] Verify error: $e');
      final message = e.toString().contains('locked')
          ? 'Account locked. Try again later.'
          : e.toString().contains('Invalid')
              ? 'Invalid PIN'
              : 'Verification failed';
      return VoiceAuthorizationResult(
        authorized: false,
        authorizationToken: null,
        expiresIn: 0,
        error: message,
      );
    }
  }

  Future<void> resetPin(String newPin) async {
    try {
      await _api.post(
        '/api/auth/voice-pin/reset/',
        body: {'pin': newPin},
      );
    } catch (e) {
      debugPrint('[VoiceSecurity] Reset error: $e');
      rethrow;
    }
  }

  Future<void> consumeAuthorization(String token) async {
    try {
      await _api.post(
        '/api/auth/voice-pin/consume/',
        body: {'authorization_token': token},
      );
    } catch (e) {
      debugPrint('[VoiceSecurity] Consume error: $e');
    }
  }
}

class VoiceAuthorizationResult {
  final bool authorized;
  final String? authorizationToken;
  final int expiresIn;
  final String? error;

  const VoiceAuthorizationResult({
    required this.authorized,
    this.authorizationToken,
    required this.expiresIn,
    this.error,
  });
}
