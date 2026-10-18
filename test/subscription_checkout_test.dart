import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mealin/core/services/api_service.dart';
import 'package:mealin/features/auth/domain/models/address_model.dart';
import 'package:mealin/features/auth/domain/repositories/auth_repository.dart';
import 'package:mealin/features/auth/presentation/providers/auth_provider.dart';
import 'package:mealin/features/customer/domain/models/subscription_model.dart';
import 'package:mealin/features/customer/presentation/providers/subscription_provider.dart';
import 'package:mealin/features/customer/presentation/screens/subscription_checkout_screen.dart';

class _RepoStub implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _QuoteApi extends ApiService {
  _QuoteApi() : super(baseUrl: 'https://example.test');
  @override
  void setToken(String token) {}

  /// Records the address id each quote was requested for, so the re-quote on
  /// address change can be asserted rather than assumed.
  final List<String> quotedAddressIds = [];

  @override
  Future<Map<String, dynamic>> get(String endpoint,
      {Map<String, dynamic>? queryParams}) async =>
      {'count': 0, 'results': <dynamic>[]};

  @override
  Future<Map<String, dynamic>> post(String endpoint,
      {Map<String, dynamic>? queryParams, Map<String, dynamic>? body}) async {
    if (endpoint.contains('quote')) {
      quotedAddressIds.add('${body?['address']}');
      // Delivery fee is derived from distance, so a different address must
      // produce a different total. This is what proves the re-quote matters.
      final addrId = '${body?['address']}';
      final km = addrId == '2' ? 9.0 : 2.0;
      return {
        'plan_price': 450.0,
        'cadence': 'week',
        'duration_days': 7,
        'meals_per_period': 6,
        'delivery_fee_per_km': 10.0,
        'distance_km': km,
        'delivery_fee_total': km * 10.0,
        'period_total': 450.0 + km * 10.0,
        'currency': 'INR',
      };
    }
    return <String, dynamic>{};
  }
}

AddressModel _addr(String id, String line) => AddressModel(
      id: id,
      label: id == '1' ? 'Home' : 'Work',
      fullAddress: line,
      houseNo: '',
      landmark: '',
      latitude: 13.17,
      longitude: 77.56,
    );

MealPlanModel _plan() => MealPlanModel(
      id: '1',
      kitchenId: '1',
      kitchenName: 'Sachin kitchen',
      kitchenAddress: 'addr',
      name: 'Weekday Home Meals',
      description: 'd',
      inclusions: const [],
      isVeg: true,
      imageUrl: '',
      isActive: true,
      startingPrice: 450,
      distanceKm: 2.0,
      slots: const [],
      prices: const [],
    );

PlanPriceModel _price() => PlanPriceModel(
      id: '1',
      cadence: 'week',
      price: 450,
      durationDays: 7,
      isActive: true,
    );

Widget _wrap(Widget child) => MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: AuthProvider(_RepoStub())),
        ChangeNotifierProvider<SubscriptionProvider>.value(
            value: SubscriptionProvider(apiService: _QuoteApi())),
      ],
      child: MaterialApp(home: child),
    );

/// Regression: subscription checkout rendered only the AppBar — the address
/// arrived as a final field from the plan screen and was displayed read-only,
/// and there was no payment section at all. The customer could not see or
/// change where the meals go, nor how they are paying, on the last screen
/// before money moves.
void main() {
  testWidgets('subscription checkout shows address and payment method',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(SubscriptionCheckoutScreen(
      plan: _plan(),
      price: _price(),
      address: _addr('1', '12 MG Road'),
      startDate: DateTime.now().add(const Duration(days: 3)),
    )));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Deliver to'), findsOneWidget,
        reason: 'delivery address must be stated on checkout');
    expect(find.text('Payment Method'), findsOneWidget,
        reason: 'payment method must be stated on checkout');
    // With no saved addresses in this harness the affordance is "Add"; the
    // point is that some address control exists at all.
    expect(find.text('Add'), findsOneWidget,
        reason: 'customer must be able to change the address at checkout');
    expect(find.text('Starts on'), findsOneWidget);
    expect(find.text('Bill details'), findsOneWidget);
  });

  testWidgets('the quote is requested for the selected address',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final api = _QuoteApi();
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: AuthProvider(_RepoStub())),
        ChangeNotifierProvider<SubscriptionProvider>.value(
            value: SubscriptionProvider(apiService: api)),
      ],
      child: MaterialApp(
        home: SubscriptionCheckoutScreen(
          plan: _plan(),
          price: _price(),
          address: _addr('1', '12 MG Road'),
          startDate: DateTime.now().add(const Duration(days: 3)),
        ),
      ),
    ));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(api.quotedAddressIds, contains('1'),
        reason: 'the quote must be priced against the chosen address');
    // Distance-based fee for the near address.
    expect(find.textContaining('470.00'), findsWidgets);
  });
}