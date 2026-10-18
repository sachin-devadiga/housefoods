import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mealin/main.dart';

/// Boots the REAL app tree from main.dart — the same MultiProvider stack,
/// MaterialApp config and SplashScreen the APK uses.
///
/// This exists because every regression reported so far was invisible to unit
/// tests: providers scoped below the Navigator (the chef weekly-plan builder,
/// the customer subscription screens) and screens that build fine in isolation
/// but crash when the app's real provider graph is assembled. Pumping
/// `MealinApp` is the closest thing to "does it load" that can be checked
/// without a device attached.
///
/// Platform channels are stubbed because FlutterSecureStorage has no Android
/// host in the test VM; without the stub the first provider constructor throws
/// and the test would prove nothing.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const secureStore =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(secureStore, (call) async {
    switch (call.method) {
      case 'containsKey':
        return false;
      case 'readAll':
        return <String, String>{};
      default:
        return null; // 'read' -> logged out
    }
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('the app boots: MealinApp builds its first frame', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // `MealinApp.build` installs its own ErrorWidget.builder, which the test
    // framework forbids from still being set when the test ends. The default
    // is captured here and restored before the test returns; the app's builder
    // is live during the pump, so a build failure still throws here.
    final defaultBuilder = ErrorWidget.builder;

    await tester.pumpWidget(const MealinApp());
    await tester.pump();

    // First frame must already be a real MaterialApp.
    expect(find.byType(MaterialApp), findsOneWidget,
        reason: 'app must produce a first frame');

    // Let the splash timer and the SDUI bootstrap (which outlives the first
    // frame) settle before tearing down, otherwise the harness reports the
    // still-running bootstrap as a failure.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }

    final exception = tester.takeException();
    expect(exception, isNull,
        reason: 'app must build without throwing on the first frame');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 5));
    ErrorWidget.builder = defaultBuilder;
  });

  testWidgets('the app survives several frames past boot', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final defaultBuilder = ErrorWidget.builder;

    await tester.pumpWidget(const MealinApp());
    // Let the splash run its async work and any timer-driven navigation land.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }

    final exception = tester.takeException();
    ErrorWidget.builder = defaultBuilder;

    expect(exception, isNull,
        reason: 'no exception may surface once the app settles');
    expect(find.byType(MaterialApp), findsOneWidget);

    // NOTE: we deliberately do NOT assert that the splash hands off to the
    // login screen. Splash calls `PackageInfo.fromPlatform()` after its 2s
    // delay, which has no platform host under the test VM, so the hand-off
    // cannot complete here. Asserting it would either fail spuriously or force
    // the test to mock away the very thing it is meant to exercise.
    // What IS proven: the full provider graph from main.dart assembles, the
    // first frame builds, and nothing throws while the app settles.
  });
}