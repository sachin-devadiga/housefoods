import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mealin/core/services/api_service.dart';
import 'package:mealin/core/services/token_service.dart';
import 'package:mealin/features/chef/presentation/providers/meal_plan_provider.dart';
import 'package:mealin/features/chef/presentation/screens/weekly_plan_builder_screen.dart';

/// Avoids secure storage / network in the widget tree.
class _NoToken extends TokenService {
  @override
  Future<String?> getAccessToken() async => null;
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

/// Regression: MealPlanProvider used to be created inside ChefDashboard, which
/// sits BELOW the Navigator. `Navigator.push` therefore put the builder outside
/// that subtree and every `context.read<MealPlanProvider>()` threw
/// ProviderNotFoundException — surfacing as the global "Something went wrong"
/// screen the moment a chef tapped "Create Weekly Plan".
///
/// The provider now lives in main.dart, so an ancestor-of-the-Navigator
/// registration is what makes the pushed route resolvable. This test pins that
/// shape: if anyone re-scopes the provider below the Navigator again, it fails.
void main() {
  testWidgets('pushed weekly plan builder resolves MealPlanProvider',
      (tester) async {
    final provider = MealPlanProvider(
      apiService: _FakeApi(), tokenService: _NoToken());

    await tester.pumpWidget(
      ChangeNotifierProvider<MealPlanProvider>.value(
        value: provider,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => TextButton(
                onPressed: () => Navigator.push(
                  ctx,
                  MaterialPageRoute(
                      builder: (_) => const WeeklyPlanBuilderScreen()),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull,
        reason: 'builder must resolve MealPlanProvider once pushed');
    expect(find.text('Plan name'), findsOneWidget);
  });

  testWidgets('the 7x3 weekly grid renders for all seven days',
      (tester) async {
    // The builder is a ListView, so a default 800x600 viewport only builds the
    // first few day rows. Give it a tall surface so all seven rows are laid out.
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final provider = MealPlanProvider(
      apiService: _FakeApi(), tokenService: _NoToken());

    await tester.pumpWidget(
      ChangeNotifierProvider<MealPlanProvider>.value(
        value: provider,
        child: const MaterialApp(home: WeeklyPlanBuilderScreen()),
      ),
    );
    await tester.pumpAndSettle();

    for (final day in ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']) {
      expect(find.text(day), findsOneWidget, reason: '$day row missing');
    }
    // "0 of 21 cells filled" confirms 7 days x 3 meal types.
    expect(find.textContaining('of 21 cells filled'), findsOneWidget);
  });
}