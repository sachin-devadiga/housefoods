import 'package:flutter/foundation.dart';

import '../sdui/sdui_provider.dart';

/// Thin read-only view over [SduiProvider] for existing call sites.
///
/// This class used to hold hardcoded placeholders — `isMaintenanceMode` was
/// literally `false` and `minAppVersion` was `'1.0.0'`, both baked into the
/// binary, so neither could ever be changed without a Play Store release.
/// `SplashScreen` still calls the same getters, so rather than churn every call
/// site this delegates to the live provider.
///
/// Kept as a class (not an extension) so existing construction in widgets
/// continues to compile. It holds no state of its own.
class RemoteConfigService {
  SduiProvider? _provider;

  /// Attach the provider. Until this happens the getters return safe defaults,
  /// which preserves the old behaviour rather than throwing during startup.
  void bind(SduiProvider provider) => _provider = provider;

  SduiProvider? get provider => _provider;

  /// Load config. Delegates to the provider, which is already usable before
  /// this resolves — that is the whole point of the cache-first design.
  Future<void> initialize() async {
    final p = _provider;
    if (p == null) {
      debugPrint('[RemoteConfigService] initialize() with no provider bound');
      return;
    }
    await p.bootstrap();
  }

  /// Safe when nothing is bound yet: returns `false` rather than throwing so a
  /// missing provider can never take down startup.
  bool get isMaintenanceMode => _provider?.maintenanceMode ?? false;

  String get maintenanceMessage =>
      _provider?.maintenanceMessage ??
      "We're performing a scheduled upgrade. Please check back in a few minutes.";

  String get minAppVersion => _provider?.minAppVersion ?? '1.0.0';

  bool get forceUpdate => _provider?.forceUpdate ?? false;

  /// Spec lookup for converted screens. Never null.
  String specForKey(String key) => _provider?.specFor(key).key ?? key;
}