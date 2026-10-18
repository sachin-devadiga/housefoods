import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/role_config.dart';
import 'default_config.dart';
import 'sdui_screen_view.dart';
import 'sdui_log.dart';
import 'sdui_service.dart';
import 'sdui_types.dart';

/// Owns the app's live SDUI configuration.
///
/// Construction alone puts the app in a renderable state: [specFor] works
/// immediately and returns baked defaults. Nothing here ever returns null for a
/// known key, and no method can leave the provider without a usable spec. That
/// is what lets `SplashScreen` call [bootstrap] without awaiting it before the
/// first frame.
///
/// Sequence, and why it is this order:
///
///   1. constructor  -> defaults only        (instant, cannot fail)
///   2. cache       -> last-known-good      (instant, cannot fail)
///   3. network     -> validate, then swap  (best effort, bounded)
class SduiProvider extends ChangeNotifier {
  SduiProvider({SduiService? service})
      : _service = service ?? HttpSduiService() {
    _adoptDefaults();
    SduiLog.add(SduiLogKind.boot, 'initialised with baked-in defaults');
  }

  final SduiService _service;

  Map<String, SduiSpec> _specs = const {};
  int _schemaVersion = kSduiSchemaVersion;
  bool _maintenanceMode = false;
  String _maintenanceMessage = '';
  String _minAppVersion = '1.0.0';
  bool _forceUpdate = false;
  Map<String, dynamic> _featureFlags = const {};
  Map<String, dynamic> _navigation = const {};
  Map<String, dynamic> _appConfig = const {};

  bool _ready = false;
  bool _fetching = false;
  DateTime? _lastSuccessAt;
  final List<String> _errors = [];

  /// True once the first network attempt has finished (success or not).
  /// [isReady] stays false while running on cached/defaults, which is the
  /// "we have not heard from the server yet" state.
  bool get isReady => _ready;
  bool get isFetching => _fetching;
  bool get maintenanceMode => _maintenanceMode;
  String get maintenanceMessage => _maintenanceMessage;
  String get minAppVersion => _minAppVersion;
  bool get forceUpdate => _forceUpdate;
  int get schemaVersion => _schemaVersion;
  Map<String, dynamic> get featureFlags => _featureFlags;
  Map<String, dynamic> get navigation => _navigation;
  Map<String, dynamic> get appConfig => _appConfig;
  List<String> get errors => List.unmodifiable(_errors);
  DateTime? get lastSuccessAt => _lastSuccessAt;

  /// Age of the cached config, for diagnostics.
  Duration? get configAge =>
      _lastSuccessAt == null ? null : DateTime.now().difference(_lastSuccessAt!);

  Map<String, SduiSpec> get specs => Map.unmodifiable(_specs);

  void _adoptDefaults() {
    _specs = Map<String, SduiSpec>.from(DefaultConfig.specs());
  }

  /// The spec for [key]. Never null.
  SduiSpec specFor(String key) => _specs[key] ?? DefaultConfig.specFor(key);

  bool hasSpec(String key) => _specs.containsKey(key);

  /// Whether [key] holds a spec that expresses an actual opinion.
  ///
  /// A spec that renders nothing (zero-height spacer, or a layout type with no
  /// children) is reported as not renderable, so a placeholder default can
  /// never silently blank out a working native surface. See
  /// `sdui_screen_view.dart`.
  bool isRenderable(String key) => specIsRenderable(specFor(key));

  /// Feature flag evaluation, mirroring the backend's fields.
  ///
  /// [rolloutSeed] must be stable per device (see [deviceSeed]) — using a fresh
  /// `Random()` per call would make a user flicker in and out of a partial
  /// rollout on every rebuild.
  bool isEnabled(String key, {required int? rolloutSeed}) {
    final raw = _featureFlags[key];
    if (raw is! Map) return false;
    if (raw['kill_switch'] == true) return false;
    if (raw['enabled'] != true) return false;

    final roles = raw['allowed_roles'];
    if (roles is List && roles.isNotEmpty) {
      final role = RoleConfig.roleName.isEmpty
          ? 'customer'
          : RoleConfig.roleName;
      if (!roles.contains(role)) return false;
    }

    final pct = (raw['rollout_pct'] as num?)?.toInt() ?? 100;
    if (pct >= 100) return true;
    if (pct <= 0) return false;
    if (rolloutSeed == null) return false;
    return (rolloutSeed % 100) < pct;
  }

  /// Load cache, then refresh from the network.
  ///
  /// Safe to call without awaiting: the app is already renderable.
  Future<void> bootstrap() async {
    if (_fetching) return;
    _fetching = true;
    _errors.clear();
    // Deferred, not immediate. bootstrap() is reached from
    // SplashScreen.initState via RemoteConfigService.initialize, so the first
    // await has not happened yet and notifyListeners() here would fire *during*
    // build -- provider throws "setState() or markNeedsBuild() called during
    // build" and startup dies. scheduleMicrotask runs after the current
    // synchronous frame (the whole build phase) unwinds, which is what we want.
    //
    // Every later notify in this method sits after an await and is already safe.
    scheduleMicrotask(notifyListeners);

    try {
      // 2. Cache — never fails, never blocks.
      await _loadCache();

      // 3. Network — bounded, best effort.
      await _refresh();
    } catch (e) {
      // Belt and braces: nothing above should throw, but if it does the app is
      // still on defaults and must not crash.
      _record('bootstrap failed: $e');
      SduiLog.add(SduiLogKind.fetchFail, 'bootstrap threw: $e');
    } finally {
      _fetching = false;
      _ready = true;
      notifyListeners();
    }
  }

  Future<void> _loadCache() async {
    final cachedBootstrap = await _service.readBootstrapCache();
    if (cachedBootstrap != null) {
      _applyBootstrap(cachedBootstrap);
      SduiLog.add(SduiLogKind.cacheHit, 'applied cached bootstrap');
    }

    for (final key in SduiKeys.all) {
      final cached = await _service.readScreenCache(key);
      if (cached != null) {
        _specs[key] = cached;
      }
    }
    notifyListeners();
  }

  Future<void> _refresh() async {
    final bootstrap = await _service.fetchBootstrap();
    if (bootstrap == null) {
      _record('bootstrap fetch failed; keeping cached config');
    } else {
      final before = _schemaVersion;
      _applyBootstrap(bootstrap);
      if (_schemaVersion != before) {
        SduiLog.add(
          SduiLogKind.versionChange,
          'schema $before -> $_schemaVersion',
        );
      }
      _lastSuccessAt = DateTime.now();
    }

    // Screens: fetch the manifest (one call) rather than N calls.
    final role = RoleConfig.roleName.isEmpty ? 'customer' : RoleConfig.roleName;
    final manifest = await _service.fetchManifest(role: role);
    if (manifest.isNotEmpty) {
      _specs = {..._specs, ...manifest};
      _lastSuccessAt ??= DateTime.now();
    } else if (_specs.isEmpty) {
      _adoptDefaults();
    }

    notifyListeners();
  }

  void _applyBootstrap(Map<String, dynamic> data) {
    _schemaVersion = (data['schema_version'] as num?)?.toInt() ?? kSduiSchemaVersion;

    final maintenance = data['maintenance'];
    if (maintenance is Map) {
      _maintenanceMode = maintenance['enabled'] == true;
      _maintenanceMessage = (maintenance['message'] as String?) ?? '';
    }
    final min = (data['min_app_version'] as String?)?.trim();
    if (min != null && min.isNotEmpty) _minAppVersion = min;
    _forceUpdate = data['force_update'] == true;

    final flags = data['feature_flags'];
    if (flags is Map) _featureFlags = Map<String, dynamic>.from(flags);
    final nav = data['navigation'];
    if (nav is Map) _navigation = Map<String, dynamic>.from(nav);
    final config = data['config'];
    if (config is Map) _appConfig = Map<String, dynamic>.from(config);
  }

  /// Convenience: pull one screen on demand (e.g. when navigating into a
  /// converted screen). Never throws; returns null if it could not be fetched.
  Future<SduiSpec?> refreshScreen(String key) async {
    final spec = await _service.fetchScreen(key);
    if (spec != null) {
      _specs = {..._specs, key: spec};
      _lastSuccessAt ??= DateTime.now();
      notifyListeners();
    }
    return spec;
  }

  void _record(String message) {
    if (_errors.length > 20) _errors.removeAt(0);
    _errors.add(message);
  }

  // -------------------------------------------------------------- diagnostics

  /// Flat snapshot for the diagnostics screen.
  Map<String, dynamic> diagnostics() => {
        'ready': _ready,
        'fetching': _fetching,
        'schema_version': _schemaVersion,
        'spec_count': _specs.length,
        'screens': {
          for (final entry in _specs.entries)
            entry.key: {
              'version': entry.value.version,
              'valid': entry.value.isValid,
              'node_type': entry.value.root.type,
              'children': entry.value.root.children.length,
            }
        },
        'feature_flags': _featureFlags.keys.toList(),
        'navigation_roles': _navigation.keys.toList(),
        'maintenance': _maintenanceMode,
        'force_update': _forceUpdate,
        'min_app_version': _minAppVersion,
        'config_age_seconds': configAge?.inSeconds,
        'errors': _errors,
        'log': SduiLog.lines(),
      };

  /// Forget cached config and fall back to defaults. The panic button when a
  /// pushed layout turns out to be bad on real hardware.
  Future<void> resetToDefaults() async {
    _adoptDefaults();
    _featureFlags = const {};
    _navigation = const {};
    _appConfig = const {};
    _maintenanceMode = false;
    _maintenanceMessage = '';
    _errors.clear();
    SduiLog.add(SduiLogKind.defaultConfig, 'reset to baked defaults');
    notifyListeners();
  }
}

/// Per-device stable seed for partial rollouts.
///
/// Derived from a value that does not change between launches, so a user stays
/// inside or outside a 10% rollout instead of flipping on every start.
int? deviceSeed(SharedPreferencesLike prefs) => prefs.readInt('sdui.seed');

/// Minimal abstraction so tests can supply a seed without touching platform
/// channels.
abstract class SharedPreferencesLike {
  int? readInt(String key);
}