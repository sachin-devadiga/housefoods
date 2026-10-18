import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mealin/core/services/api_service.dart';
import 'package:mealin/features/auth/domain/repositories/auth_repository.dart';
import 'package:mealin/features/auth/presentation/providers/auth_provider.dart';
import 'package:mealin/features/customer/data/repositories/order_repository_impl.dart';
import 'package:mealin/features/customer/domain/models/cart_model.dart';
import 'package:mealin/features/customer/presentation/providers/cart_provider.dart';
import 'package:mealin/features/customer/presentation/providers/order_provider.dart';
import 'package:mealin/features/customer/presentation/screens/cart_checkout_screen.dart';

class _RepoStub implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeApi extends ApiService {
  _FakeApi() : super(baseUrl: 'https://example.test');
  @override
  void setToken(String token) {}
  @override
  Future<Map<String, dynamic>> get(String endpoint,
      {Map<String, dynamic>? queryParams}) async =>
      {'count': 0, 'results': <dynamic>[]};
}

Widget _wrap() => MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: AuthProvider(_RepoStub())),
        ChangeNotifierProvider<OrderProvider>.value(
            value: OrderProvider(
                OrderRepositoryImpl(apiService: _FakeApi()),
                apiService: _FakeApi())),
        ChangeNotifierProvider<CartProvider>.value(value: CartProvider()),
      ],
      child: MaterialApp(
        home: CartCheckoutScreen(
          kitchenId: '1',
          kitchenName: "Sachin's kitchen",
          items: [
            CartItemModel(
              id: '1',
              menuItemId: '1',
              menuItemName: 'Dal Rice',
              menuItemImage: '',
              menuItemPrice: 90,
              quantity: 2,
              specialInstructions: '',
              itemTotal: 180,
            )
          ],
          subtotal: 180,
        ),
      ),
    );

/// Regression: with no saved address the checkout still showed an enabled
/// "Pay ₹X" button. Tapping it hit `_placeOrder`, which showed a SnackBar
/// ("Please add a delivery address") and returned — so the primary action of
/// the screen did nothing but scold the customer, and there was no way to add
/// an address from here.
void main() {
  testWidgets('with no address the CTA offers to add one instead of paying',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Add delivery address to continue'), findsOneWidget,
        reason: 'CTA must name the blocker, not offer to pay');
    expect(find.textContaining('Pay ₹'), findsNothing,
        reason: 'must not offer payment with nowhere to deliver');
    expect(find.textContaining('Place Order'), findsNothing);
  });

  testWidgets('cash on delivery is available and selectable',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Cash on Delivery'), findsOneWidget,
        reason: 'COD is the working path and must be offered');
    expect(find.text('Not available right now'), findsOneWidget,
        reason: 'online must be visibly unavailable with a reason');
  });
}