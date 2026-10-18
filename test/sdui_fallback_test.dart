import 'package:flutter_test/flutter_test.dart';

import 'package:mealin/core/sdui/default_config.dart';
import 'package:mealin/core/sdui/sdui_provider.dart';
import 'package:mealin/core/sdui/sdui_service.dart';
import 'package:mealin/core/sdui/sdui_types.dart';
import 'package:mealin/core/sdui/sdui_widget_registry.dart';

/// A service that never returns anything, standing in for an unreachable or
/// broken backend. Used to prove the app is still renderable.
class _DeadService extends SduiService {
  @override
  Future<SduiSpec?> fetchScreen(String key) async => null;
  @override
  Future<Map<String, dynamic>?> fetchBootstrap() async => null;
  @override
  Future<Map<String, SduiSpec>> fetchManifest({String role = 'customer'}) async =>
      const {};
  @override
  Future<bool> probe() async => false;
  @override
  Future<SduiSpec?> readScreenCache(String key) async => null;
  @override
  Future<Map<String, dynamic>?> readBootstrapCache() async => null;
}

/// A service that throws, standing in for a 500 or a timeout.
class _ThrowingService extends _DeadService {
  @override
  Future<Map<String, dynamic>?> fetchBootstrap() async =>
      throw Exception('network down');
}

/// A service that hands back garbage, standing in for a hand-edited row.
class _GarbageService extends SduiService {
  @override
  Future<Map<String, dynamic>?> fetchBootstrap() async => {
        'schema_version': 1,
        'not_a_real_field': true,
      };
  @override
  Future<SduiSpec?> fetchScreen(String key) async => SduiSpec(
        key: key,
        root: const SduiNode(type: SduiNodeType.column, children: []),
      );
  @override
  Future<Map<String, SduiSpec>> fetchManifest({String role = 'customer'}) async =>
      const {};
  @override
  Future<bool> probe() async => true;
  @override
  Future<SduiSpec?> readScreenCache(String key) async => null;
  @override
  Future<Map<String, dynamic>?> readBootstrapCache() async => null;
}

void main() {
  group('SduiProvider fallback contract', () {
    test('is renderable before bootstrap is ever called', () {
      final provider = SduiProvider(service: _DeadService());
      // No bootstrap, no network, no disk: the app can already resolve a spec.
      expect(provider.isReady, isFalse);
      expect(provider.specFor(SduiKeys.customerHome).key,
          SduiKeys.customerHome);
      expect(provider.maintenanceMode, isFalse);
    });

    test('never returns null for a known key', () {
      final provider = SduiProvider(service: _DeadService());
      for (final key in SduiKeys.all) {
        expect(provider.specFor(key), isNotNull);
        expect(provider.specFor(key).key, key);
      }
    });

    test('returns a safe empty spec for an unknown key', () {
      final provider = SduiProvider(service: _DeadService());
      final spec = provider.specFor('some_key_we_never_heard_of');
      expect(spec.key, 'some_key_we_never_heard_of');
      expect(spec.isValid, isTrue);
    });

    test('survives a completely unreachable backend', () async {
      final provider = SduiProvider(service: _DeadService());
      await provider.bootstrap();
      expect(provider.isReady, isTrue);
      expect(provider.errors, isNotEmpty);
      // Still usable: this is the guarantee that matters.
      expect(provider.specFor(SduiKeys.customerHome).isValid, isTrue);
      expect(provider.maintenanceMode, isFalse);
    });

    test('survives a backend that throws', () async {
      final provider = SduiProvider(service: _ThrowingService());
      await provider.bootstrap();
      expect(provider.isReady, isTrue);
      expect(provider.specFor(SduiKeys.login).isValid, isTrue);
    });

    test('survives a malformed bootstrap payload', () async {
      final provider = SduiProvider(service: _GarbageService());
      await provider.bootstrap();
      expect(provider.isReady, isTrue);
      expect(provider.maintenanceMode, isFalse);
    });

    test('resetToDefaults clears flags and flags the state', () async {
      final provider = SduiProvider(service: _DeadService());
      await provider.bootstrap();
      await provider.resetToDefaults();
      expect(provider.errors, isEmpty);
      expect(provider.featureFlags, isEmpty);
      expect(provider.specFor(SduiKeys.banners).isValid, isTrue);
    });
  });

  group('baked-in defaults', () {
    test('every default key has a valid spec', () {
      final specs = DefaultConfig.specs();
      expect(specs.keys.toSet(), SduiKeys.all.toSet());
      for (final entry in specs.entries) {
        expect(
          entry.value.isValid,
          isTrue,
          reason: 'default "${entry.key}" invalid: ${entry.value.validate()}',
        );
      }
    });

    test('defaults use only types the registry can render', () {
      for (final spec in DefaultConfig.specs().values) {
        for (final node in _flatten(spec.root)) {
          expect(
            SduiWidgetRegistry.builders.containsKey(node.type),
            isTrue,
            reason: 'default uses "${node.type}" with no builder',
          );
        }
      }
    });

    test('shipped defaults match the backend fallback shapes', () {
      // Mirrors backend/api/sdui/schema.py DEFAULTS. If these drift, an empty
      // database and a fresh install render differently.
      final home = DefaultConfig.specFor(SduiKeys.customerHome);
      expect(home.root.type, SduiNodeType.column);
      expect(home.root.children.map((c) => c.type), contains(SduiNodeType.bannerCarousel));
      expect(home.root.children.map((c) => c.type), contains(SduiNodeType.section));
    });
  });

  group('feature flag evaluation', () {
    test('kill switch overrides an enabled flag', () async {
      final p = await _providerWithFlags({
        'x': {'enabled': true, 'rollout_pct': 100, 'kill_switch': true},
      });
      expect(p.isEnabled('x', rolloutSeed: 1), isFalse);
    });

    test('disabled flag is off', () async {
      final p = await _providerWithFlags({
        'x': {'enabled': false, 'rollout_pct': 100},
      });
      expect(p.isEnabled('x', rolloutSeed: 1), isFalse);
    });

    test('unknown flag is off, not a crash', () async {
      final p = await _providerWithFlags(const {});
      expect(p.isEnabled('nope', rolloutSeed: 1), isFalse);
    });

    test('full rollout is on, zero rollout is off', () async {
      final on = await _providerWithFlags({
        'x': {'enabled': true, 'rollout_pct': 100},
      });
      final off = await _providerWithFlags({
        'x': {'enabled': true, 'rollout_pct': 0},
      });
      expect(on.isEnabled('x', rolloutSeed: 42), isTrue);
      expect(off.isEnabled('x', rolloutSeed: 42), isFalse);
    });

    test('partial rollout is stable for a given seed', () async {
      final p = await _providerWithFlags({
        'x': {'enabled': true, 'rollout_pct': 50},
      });
      // Same seed must always give the same answer, or users flicker in and out.
      final first = p.isEnabled('x', rolloutSeed: 7);
      for (var i = 0; i < 20; i++) {
        expect(p.isEnabled('x', rolloutSeed: 7), first);
      }
    });

    test('role restriction is enforced', () async {
      final p = await _providerWithFlags({
        'x': {
          'enabled': true,
          'rollout_pct': 100,
          'allowed_roles': ['chef'],
        },
      });
      // The test build has no APP_ROLE, so it resolves as 'customer'.
      expect(p.isEnabled('x', rolloutSeed: 1), isFalse);
    });
  });

  group('diagnostics', () {
    test('exposes a snapshot without throwing', () {
      final provider = SduiProvider(service: _DeadService());
      final diag = provider.diagnostics();
      expect(diag['ready'], isFalse);
      expect(diag['spec_count'], SduiKeys.all.length);
      expect(diag['screens'], isA<Map>());
      expect(diag['log'], isA<List>());
    });
  });
}

/// Walk a node tree.
List<SduiNode> _flatten(SduiNode node) {
  final out = <SduiNode>[node];
  for (final child in node.children) {
    out.addAll(_flatten(child));
  }
  return out;
}

/// Build a provider carrying a specific feature_flags map, without HTTP.
///
/// Awaited: `bootstrap()` is async, so returning before it settles races the
/// assertions against an unpopulated flag map.
Future<SduiProvider> _providerWithFlags(Map<String, dynamic> flags) async {
  final provider = SduiProvider(service: _FlagService(flags));
  await provider.bootstrap();
  return provider;
}

class _FlagService extends SduiService {
  _FlagService(this.flags);
  final Map<String, dynamic> flags;

  @override
  Future<Map<String, dynamic>?> fetchBootstrap() async => {
        'schema_version': 1,
        'maintenance': {'enabled': false, 'message': ''},
        'feature_flags': flags,
      };

  @override
  Future<Map<String, SduiSpec>> fetchManifest({String role = 'customer'}) async =>
      const {};
  @override
  Future<SduiSpec?> fetchScreen(String key) async => null;
  @override
  Future<bool> probe() async => true;
  @override
  Future<SduiSpec?> readScreenCache(String key) async => null;
  @override
  Future<Map<String, dynamic>?> readBootstrapCache() async => null;
}