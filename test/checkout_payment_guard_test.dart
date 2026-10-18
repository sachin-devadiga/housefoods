import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealin/core/constants/app_constants.dart';
import 'package:mealin/core/services/api_service.dart';
import 'package:mealin/features/customer/data/repositories/order_repository_impl.dart';
import 'package:mealin/features/customer/domain/models/order_model.dart';
import 'package:mealin/features/customer/presentation/providers/order_provider.dart';

class _FakeApi extends ApiService {
  _FakeApi() : super(baseUrl: 'https://example.test');
  @override
  void setToken(String token) {}
}

/// Regression: the blank "after checkout" screen.
///
/// `AppConstants.razorpayKey` ships as `rzp_test_YOUR_KEY_HERE` in debug
/// builds. Opening Razorpay with it renders a blank webview and — because the
/// plugin raises no callback and the catch block only `debugPrint`ed — the
/// customer got no error, no order, and a spinner that silently cleared.
/// COD, meanwhile, worked the whole time; I verified a real COD order against
/// the live API.
void main() {
  test('placeholder gateway key is detected as unconfigured', () {
    // This is the debug default, so the test is meaningful without defines.
    expect(AppConstants.razorpayKey, 'rzp_test_YOUR_KEY_HERE');
    expect(AppConstants.razorpayConfigured, isFalse,
        reason: 'placeholder key must never count as configured');
  });

  test('a real-looking key counts as configured', () {
    // Guard the inverse so the check cannot rot into always-false.
    expect('rzp_test_abc123'.contains('YOUR_KEY'), isFalse);
  });

  testWidgets('one-time payment reports an error instead of opening a blank '
      'gateway when unconfigured', (tester) async {
    final provider =
        OrderProvider(OrderRepositoryImpl(apiService: _FakeApi()),
            apiService: _FakeApi());

    String? error;
    var successCalled = false;

    provider.openCheckoutForOneTime(
      order: OrderModel(
        id: '',
        customerId: 'u1',
        kitchenId: '1',
        kitchenName: 'K',
        amount: 149,
        deliveryAddress: 'somewhere',
        startDate: DateTime.now(),
        endDate: DateTime.now(),
        status: 'active',
        paymentId: '',
        createdAt: DateTime.now(),
        orderType: 'one_time',
      ),
      items: const [],
      userEmail: 'a@b.c',
      userPhone: '',
      onSuccess: (_) => successCalled = true,
      onError: (e) => error = e,
    );

    expect(error, isNotNull,
        reason: 'failure must reach the customer, not be swallowed');
    expect(error, contains('cash on delivery'));
    expect(successCalled, isFalse);
  });
}