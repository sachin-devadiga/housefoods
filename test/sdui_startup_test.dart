import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mealin/core/sdui/sdui_provider.dart';
import 'package:mealin/core/sdui/sdui_service.dart';
import 'package:mealin/core/sdui/sdui_types.dart';

/// A service that never completes, so `bootstrap()` can only run as far as its
/// synchronous prologue.
class _HangingSduiService implements SduiService {
  final Completer<void> gate = Completer<void>();

  @override
  Future<Map<String, dynamic>?> fetchBootstrap() async {
    await gate.future;
    return null;
  }

  @override
  Future<SduiSpec?> fetchScreen(String key) async {
    await gate.future;
    return null;
  }

  @override
  Future<Map<String, SduiSpec>> fetchManifest({String role = 'customer'}) async {
    await gate.future;
    return const {};
  }

  @override
  Future<Map<String, dynamic>?> readBootstrapCache() async => null;

  @override
  Future<SduiSpec?> readScreenCache(String key) async => null;

  @override
  Future<bool> probe() async => true;
}

/// Regression test for a crash on every cold start.
///
/// `SplashScreen.initState` calls `RemoteConfigService.initialize()`, which
/// reaches `SduiProvider.bootstrap()`. That method used to call
/// `notifyListeners()` as its first statement — synchronously, before its first
/// `await`. Since initState runs during the build phase, provider threw
/// "setState() or markNeedsBuild() called during build" and startup died.
///
/// It passed CI because nothing there pumps a real widget tree; the existing
/// tests drive the provider directly, where notifying outside build is legal.
///
/// The fix defers the first notification to a microtask, which runs after the
/// synchronous build phase unwinds. This test asserts exactly that property:
/// calling bootstrap() synchronously must not notify.
void main() {
  test('bootstrap does not notify listeners synchronously', () async {
    final service = _HangingSduiService();
    final provider = SduiProvider(service: service);

    var notifications = 0;
    provider.addListener(() => notifications++);

    // Not awaited: the point is what happens before the first await.
    final pending = provider.bootstrap();

    // Would have been >= 1 with the bug, and provider would have thrown when
    // this ran inside a real build.
    expect(
      notifications,
      0,
      reason: 'bootstrap() must not notifyListeners() synchronously; it is '
          'reached from initState during the build phase',
    );

    service.gate.complete();
    await pending;
  });

  test('bootstrap still notifies once the microtask runs', () async {
    final service = _HangingSduiService();
    final provider = SduiProvider(service: service);

    var notifications = 0;
    provider.addListener(() => notifications++);

    final pending = provider.bootstrap();
    service.gate.complete();
    await pending;

    // The deferred notification plus the one in `finally`. The point is that
    // it is not zero -- deferring must not silence the loading state.
    expect(
      notifications,
      greaterThanOrEqualTo(1),
      reason: 'deferring the notification must not suppress it entirely',
    );
  });

  test('a second bootstrap while one is in flight is a no-op', () async {
    final service = _HangingSduiService();
    final provider = SduiProvider(service: service);

    final first = provider.bootstrap();
    final second = provider.bootstrap();

    service.gate.complete();
    await first;
    await second;
    // Neither call threw; the guard simply ignored the second.
    expect(provider.isReady, isTrue);
  });
}
