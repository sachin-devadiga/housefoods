abstract class AuthRepository {
  Future<void> sendOtp({
    required String email,
    required Function(String? otpCode) onSuccess,
    required Function(String) onError,
  });

  Future<void> verifyOtp({
    required String email,
    required String otp,
    required Function() onSuccess,
    required Function(String) onError,
  });

  Future<void> signOut();
}
