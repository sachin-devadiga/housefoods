import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/api_service.dart';

class RewardProvider extends ChangeNotifier {
  final ApiService _api;

  RewardProvider({ApiService? apiService})
      : _api = apiService ?? ApiService(baseUrl: AppConstants.apiBaseUrl);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _hasError = false;
  bool get hasError => _hasError;

  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> get transactions => _transactions;

  Future<void> fetchWalletHistory() async {
    _isLoading = true;
    _hasError = false;
    notifyListeners();
    try {
      final data = await _api.get(AppConstants.walletEndpoint);
      _transactions = ((data['transactions'] as List?) ?? []).cast<Map<String, dynamic>>();
    } catch (e) {
      _hasError = true;
      debugPrint("Error fetching wallet history: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> applyReferralCode({
    required String code,
    required String userId,
    required Function onSuccess,
    required Function(String) onError,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _api.post(AppConstants.referralsEndpoint, body: {
        'code': code.toUpperCase(),
        'user_id': userId,
      });
      onSuccess();
    } catch (e) {
      onError(e.toString());
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
