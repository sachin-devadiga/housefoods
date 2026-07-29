import 'package:dio/dio.dart';
import '../constants/app_constants.dart';
import 'api_service.dart';
import 'token_service.dart';

class AuthService {
  final ApiService _api;
  final TokenService _tokenService;

  AuthService({
    ApiService? apiService,
    TokenService? tokenService,
  })  : _api = apiService ?? ApiService(baseUrl: AppConstants.apiBaseUrl),
        _tokenService = tokenService ?? TokenService();

  Future<Map<String, dynamic>> sendOtp(String email) async {
    final data = await _api.post(
      AppConstants.sendOtpEndpoint,
      body: {'email': email},
    );
    return data;
  }

  Future<Map<String, dynamic>> verifyOtp(
    String email,
    String otp,
  ) async {
    final data = await _api.post(
      AppConstants.verifyOtpEndpoint,
      body: {'email': email, 'otp': otp},
    );
    return data;
  }

  Future<Map<String, dynamic>> setupProfile({
    required String email,
    required String name,
    required String role,
    String? phone,
    String? avatarUrl,
  }) async {
    final data = await _api.post(
      AppConstants.profileSetupEndpoint,
      body: {
        'email': email,
        'name': name,
        'role': role,
        if (phone != null) 'phone': phone,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
      },
    );
    return data;
  }

  Future<void> saveEmail(String email) async {
    await _tokenService.saveEmail(email);
  }

  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    required String email,
    required String uid,
    required String role,
  }) async {
    await _tokenService.saveTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
    await _tokenService.saveUserSession(
      email: email,
      uid: uid,
      role: role,
    );
    _api.setToken(accessToken);
  }

  Future<String?> refreshToken() async {
    final refreshToken = await _tokenService.getRefreshToken();
    if (refreshToken == null) return null;
    try {
      final dio = Dio(BaseOptions(
        baseUrl: AppConstants.apiBaseUrl,
        headers: {'Content-Type': 'application/json'},
      ));
      final response = await dio.post(
        AppConstants.tokenRefreshEndpoint,
        data: {'refresh': refreshToken},
      );
      final newAccess = response.data['access'] as String;
      await _tokenService.updateAccessToken(newAccess);
      _api.setToken(newAccess);
      return newAccess;
    } catch (e) {
      await logout();
      return null;
    }
  }

  Future<Map<String, dynamic>?> getProfile() async {
    try {
      final data = await _api.get('/api/auth/profile/');
      return data;
    } catch (e) {
      return null;
    }
  }

  Future<void> logout() async {
    final refreshToken = await _tokenService.getRefreshToken();
    if (refreshToken != null) {
      try {
        await _api.post('/api/auth/logout/', body: {'refresh_token': refreshToken});
      } catch (_) {}
    }
    _api.clearToken();
    await _tokenService.clearSession();
  }

  Future<bool> isLoggedIn() async {
    return await _tokenService.isLoggedIn();
  }

  Future<Map<String, dynamic>?> tryAutoLogin() async {
    final isLoggedIn = await _tokenService.isLoggedIn();
    if (!isLoggedIn) return null;

    final accessToken = await _tokenService.getAccessToken();
    if (accessToken == null) return null;

    _api.setToken(accessToken);
    final profile = await getProfile();
    if (profile != null && profile['uid'] != null) {
      return profile;
    }

    final newToken = await refreshToken();
    if (newToken != null) {
      final retryProfile = await getProfile();
      if (retryProfile != null && retryProfile['uid'] != null) {
        return retryProfile;
      }
    }

    await logout();
    return null;
  }
}
