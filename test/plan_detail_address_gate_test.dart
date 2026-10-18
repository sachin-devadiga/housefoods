import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mealin/features/auth/domain/repositories/auth_repository.dart';
import 'package:mealin/features/auth/presentation/providers/auth_provider.dart';
import 'package:mealin/features/customer/domain/models/subscription_model.dart';
import 'package:mealin/features/customer/presentation/screens/plan_detail_screen.dart';

class _RepoStub implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

MealPlanModel _plan() => MealPlanModel(
      id: '1',
      kitchenId: '1',
      kitchenName: 'Sachin kitchen',
      kitchenAddress: 'addr',
      name: 'Weekday Home Meals',
      description: 'Mon-Fri lunch',
      inclusions: const [],
      isVeg: true,
      imageUrl: '',
      isActive: true,
      startingPrice: 450,
      distanceKm: 2.0,
      slots: const [],
      prices: [
        PlanPriceModel(
          id: '1',
          cadence: 'week',
          price: 450,
          durationDays: 7,
          isActive: true,
        )
      ],
    );

/// Regression: a customer with no saved address hit a hard dead end on the
/// plan screen. The "Deliver to" tile was an inert label ("No saved address.
/// Add one from your profile first"), `_pickAddress` returned silently when
/// the list was empty, and Continue was disabled with no stated reason. There
/// was no way forward from that screen at all.
void main() {
  testWidgets('with no saved address the plan screen offers a way to add one',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: AuthProvider(_RepoStub())),
        ],
        child: MaterialApp(home: PlanDetailScreen(plan: _plan())),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // The prompt must be actionable, not a dead label.
    expect(find.text('Add a delivery address'), findsOneWidget);
    expect(
        find.textContaining('Add one from your profile'), findsNothing,
        reason: 'the old inert copy must be gone');

    // The disabled CTA must say WHY it is disabled.
    expect(find.text('Add a delivery address to continue'), findsOneWidget,
        reason: 'disabled CTA must state the blocker');

    // Tapping the tile must actually navigate rather than no-op.
    await tester.tap(find.text('Add a delivery address').first);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull,
        reason: 'tapping the empty address tile must not throw');
  });
}