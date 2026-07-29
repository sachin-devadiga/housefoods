import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/auth_service.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthProvider extends ChangeNotifier {
  final AuthRepository _authRepository;
  final AuthService _authService;

  AuthProvider(this._authRepository, {AuthService? authService})
      : _authService = authService ??
            AuthService(
              apiService: ApiService(baseUrl: AppConstants.apiBaseUrl),
            );

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Map<String, dynamic>? _userProfile;
  Map<String, dynamic>? get userProfile => _userProfile;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  Future<void> sendOtp({
    required String email,
    required Function() onSuccess,
    required Function(String) onError,
  }) async {
    _setLoading(true);
    await _authRepository.sendOtp(
      email: email,
      onSuccess: () {
        _setLoading(false);
        onSuccess();
      },
      onError: (error) {
        _setLoading(false);
        onError(error);
      },
    );
  }

  Future<void> verifyOtp({
    required String email,
    required String otp,
    required Function(bool profileExists) onSuccess,
    required Function(String) onError,
  }) async {
    _setLoading(true);
    try {
      final data = await _authService.verifyOtp(email, otp);
      final profileExists = data['profile_exists'] == true;
      if (profileExists) {
        await _authService.saveSession(
          accessToken: data['access_token'],
          refreshToken: data['refresh_token'],
          email: data['email'],
          uid: data['user']['uid'],
          role: data['user']['role'],
        );
        _userProfile = data['user'];
      } else {
        await _authService.saveEmail(email);
      }
      _setLoading(false);
      onSuccess(profileExists);
    } on ApiException catch (e) {
      _setLoading(false);
      onError(e.message);
    } catch (e) {
      _setLoading(false);
      onError('Something went wrong');
    }
  }

  Future<void> setupProfile({
    required String email,
    required String name,
    required String role,
    String? phone,
    String? avatarUrl,
    required Function() onSuccess,
    required Function(String) onError,
  }) async {
    _setLoading(true);
    try {
      final data = await _authService.setupProfile(
        email: email,
        name: name,
        role: role,
        phone: phone,
        avatarUrl: avatarUrl,
      );
      await _authService.saveSession(
        accessToken: data['access_token'],
        refreshToken: data['refresh_token'],
        email: email,
        uid: data['user']['uid'],
        role: data['user']['role'],
      );
      _userProfile = data['user'];
      _setLoading(false);
      onSuccess();
    } on ApiException catch (e) {
      _setLoading(false);
      onError(e.message);
    } catch (e) {
      _setLoading(false);
      onError('Something went wrong');
    }
  }

  Future<Map<String, dynamic>?> tryAutoLogin() async {
    _setLoading(true);
    try {
      final profile = await _authService.tryAutoLogin();
      if (profile != null) {
        _userProfile = profile;
      }
      _setLoading(false);
      return profile;
    } catch (e) {
      _setLoading(false);
      return null;
    }
  }

  Future<void> deleteAccount({
    required Function() onSuccess,
    required Function(String) onError,
  }) async {
    _setLoading(true);
    try {
      await _authService.logout();
      _setLoading(false);
      onSuccess();
    } catch (e) {
      _setLoading(false);
      onError(e.toString());
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    _userProfile = null;
    notifyListeners();
  }
}
