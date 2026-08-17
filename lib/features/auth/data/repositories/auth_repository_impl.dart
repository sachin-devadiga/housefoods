import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/auth_service.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthService _authService;

  AuthRepositoryImpl({AuthService? authService})
      : _authService = authService ??
            AuthService(
              apiService: ApiService(baseUrl: AppConstants.apiBaseUrl),
            );

  @override
  Future<void> sendOtp({
    required String email,
    required Function(String? otpCode) onSuccess,
    required Function(String) onError,
  }) async {
    try {
      final data = await _authService.sendOtp(email);
      onSuccess(data['otp_code'] as String?);
    } on ApiException catch (e) {
      onError(e.message);
    } catch (e) {
      onError('Something went wrong');
    }
  }

  @override
  Future<void> verifyOtp({
    required String email,
    required String otp,
    required Function() onSuccess,
    required Function(String) onError,
  }) async {
    try {
      final data = await _authService.verifyOtp(email, otp);
      if (data['profile_exists'] == true) {
        await _authService.saveSession(
          accessToken: data['access_token'],
          refreshToken: data['refresh_token'],
          email: data['email'],
          uid: data['user']['uid'],
          role: data['user']['role'],
        );
      }
      onSuccess();
    } on ApiException catch (e) {
      onError(e.message);
    } catch (e) {
      onError('Something went wrong');
    }
  }

  @override
  Future<void> signOut() async {
    await _authService.logout();
  }
}
