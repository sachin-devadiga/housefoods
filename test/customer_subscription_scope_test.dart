import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mealin/core/services/api_service.dart';
import 'package:mealin/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:mealin/features/auth/presentation/providers/auth_provider.dart';
import 'package:mealin/features/customer/presentation/providers/subscription_provider.dart';
import 'package:mealin/features/customer/presentation/screens/plans_browse_screen.dart';
import 'package:mealin/features/customer/presentation/screens/tabs/subscriptions_tab.dart';

class _FakeApi extends ApiService {
  _FakeApi() : super(baseUrl: 'https://example.test');
  @override
  void setToken(String token) {}
  @override
  Future<Map<String, dynamic>> get(String endpoint,
      {Map<String, dynamic>? queryParams}) async =>
      {'count': 0, 'results': <dynamic>[]};
}

/// Regression for the second instance of the same scoping bug as the chef
/// weekly-plan crash: `SubscriptionsTab` used to construct its own
/// `SubscriptionProvider` and expose it only to its own subtree. Home then
/// pushed `PlansBrowseScreen` directly, which sits outside that subtree, so
/// `context.read<SubscriptionProvider>()` threw `ProviderNotFoundException`.
///
/// The provider now lives in main.dart, above the Navigator. These tests pin
/// that shape so re-scoping it below the Navigator fails loudly.
void main() {
  testWidgets('pushed plans browse resolves SubscriptionProvider',
      (tester) async {
    final provider = SubscriptionProvider(apiService: _FakeApi());

    await tester.pumpWidget(
      ChangeNotifierProvider<SubscriptionProvider>.value(
        value: provider,
        child: ChangeNotifierProvider<AuthProvider>.value(
          value: AuthProvider(AuthRepositoryImpl()),
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => TextButton(
                  onPressed: () => Navigator.push(
                    ctx,
                    MaterialPageRoute(
                        builder: (_) => const PlansBrowseScreen()),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pump();

    expect(tester.takeException(), isNull,
        reason: 'PlansBrowseScreen must resolve SubscriptionProvider');
  });

  testWidgets('SubscriptionsTab uses the ancestor provider, not its own',
      (tester) async {
    final provider = SubscriptionProvider(apiService: _FakeApi());

    await tester.pumpWidget(
      ChangeNotifierProvider<SubscriptionProvider>.value(
        value: provider,
        child: const MaterialApp(home: SubscriptionsTab()),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    // The tab renders the shared instance's state ("No active meal plans")
    // rather than owning a second, empty provider of its own.
    expect(find.text('No active meal plans'), findsOneWidget);
  });
}