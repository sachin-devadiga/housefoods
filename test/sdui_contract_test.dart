import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mealin/core/sdui/default_config.dart';
import 'package:mealin/core/sdui/sdui_provider.dart';
import 'package:mealin/core/sdui/sdui_service.dart';
import 'package:mealin/core/sdui/sdui_types.dart';
import 'package:mealin/core/sdui/sdui_widget_registry.dart';

/// Cross-language contract test.
///
/// The fixtures in `test/fixtures/` are **captured verbatim from the running
/// Django server**, not hand-written. They are the only check that the Dart
/// parser and the Python schema actually agree — every other test uses
/// hand-built objects that both sides would happily accept.
///
/// Regenerate with `scripts/capture_sdui_fixtures.sh`.
Map<String, dynamic> _fixture(String name) {
  final file = File('test/fixtures/$name.json');
  expect(file.existsSync(), isTrue,
      reason: 'missing fixture $name.json — run scripts/capture_sdui_fixtures.sh');
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

class _FixtureService extends SduiService {
  _FixtureService(this.name);
  final String name;

  @override
  Future<Map<String, dynamic>?> fetchBootstrap() async => _fixture(name);

  @override
  Future<SduiSpec?> fetchScreen(String key) async {
    final data = _fixture(name);
    return SduiParse.trySpec(data);
  }

  @override
  Future<Map<String, SduiSpec>> fetchManifest({String role = 'customer'}) async {
    final data = _fixture(name);
    final raw = data['screens'];
    if (raw is! Map) return const {};
    final out = <String, SduiSpec>{};
    for (final e in raw.entries) {
      final body = e.value;
      if (body is Map) {
        final spec = SduiParse.trySpec({
          'key': e.key,
          'version': (body['version'] as num?)?.toInt() ?? 1,
          'schema_version': 1,
          'root': body['root'],
        });
        if (spec != null) out[e.key] = spec;
      }
    }
    return out;
  }

  @override
  Future<Map<String, dynamic>?> readBootstrapCache() async => null;
  @override
  Future<SduiSpec?> readScreenCache(String key) async => null;
  @override
  Future<bool> probe() async => true;
}

void main() {
  group('real server bootstrap parses', () {
    test('fields land where the provider expects them', () {
      final data = _fixture('sdui_bootstrap');
      expect(data['schema_version'], isA<int>());
      expect(data['maintenance'], isA<Map>());
      expect(data['maintenance']['enabled'], isA<bool>());
      expect(data['min_app_version'], isA<String>());
      expect(data['force_update'], isA<bool>());
      expect(data['feature_flags'], isA<Map>());
    });

    testWidgets('provider applies a real bootstrap without throwing',
        (tester) async {
      final provider = SduiProvider(service: _FixtureService('sdui_bootstrap'));
      await provider.bootstrap();
      expect(provider.isReady, isTrue);
      expect(provider.schemaVersion, 1);
      // The fixture carries a fully-enabled flag with a customer role list.
      expect(provider.featureFlags.containsKey('new_cart'), isTrue);
      expect(provider.errors, isEmpty);
    });

    test('feature flag from the server evaluates correctly', () async {
      final provider = SduiProvider(service: _FixtureService('sdui_bootstrap'));
      await provider.bootstrap();
      final flag = provider.featureFlags['new_cart'];
      expect(flag, isNotNull);
      expect(flag['enabled'], true);
      expect(flag['rollout_pct'], 100);
    });
  });

  group('real server screen spec renders', () {
    test('parses and validates against the Dart schema', () {
      final data = _fixture('sdui_screen_customer_home');
      final spec = SduiSpec.fromJson(data);
      expect(spec.key, 'customer_home');
      expect(spec.schemaVersion, 1);
      expect(spec.isValid, isTrue,
          reason: 'server sent a spec Dart rejects: ${spec.validate()}');
    });

    test('every node in the server spec has a builder', () {
      final spec = SduiSpec.fromJson(_fixture('sdui_screen_customer_home'));
      final missing = <String>[];
      void walk(SduiNode node) {
        if (!SduiWidgetRegistry.builders.containsKey(node.type)) {
          missing.add(node.type);
        }
        for (final c in node.children) {
          walk(c);
        }
      }

      walk(spec.root);
      expect(missing, isEmpty,
          reason: 'server emits types with no Dart builder: $missing');
    });

    testWidgets('server spec renders without error or placeholder',
        (tester) async {
      final spec = SduiSpec.fromJson(_fixture('sdui_screen_customer_home'));
      late BuildContext ctx;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(builder: (c) {
            ctx = c;
            return const SizedBox.shrink();
          }),
        ),
      ));

      final widget = SduiWidgetRegistry.renderSpec(ctx, spec);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: widget)),
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(SduiPlaceholder), findsNothing,
          reason: 'a real server spec fell back to a placeholder');
    });

    test('real spec round-trips through the cache encoding', () {
      // The provider persists specs by re-encoding nodes; if that encoding loses
      // or corrupts a field, the cached copy diverges from the live one.
      final spec = SduiSpec.fromJson(_fixture('sdui_screen_customer_home'));
      final reencoded = _reencode(spec);
      final parsed = SduiParse.trySpec(reencoded);
      expect(parsed, isNotNull);
      expect(parsed!.key, spec.key);
      expect(parsed.root.type, spec.root.type);
      expect(parsed.root.children.length, spec.root.children.length);
      expect(parsed.isValid, isTrue);
    });
  });

  group('real server manifest parses', () {
    test('maps screens to specs', () {
      final service = _FixtureService('sdui_manifest');
      final data = _fixture('sdui_manifest');
      expect(data['screens'], isA<Map>());
      // Whatever the manifest contains must be renderable.
      final raw = data['screens'] as Map;
      for (final entry in raw.entries) {
        final body = entry.value;
        if (body is Map) {
          final spec = SduiParse.trySpec({
            'key': entry.key,
            'version': (body['version'] as num?)?.toInt() ?? 1,
            'schema_version': 1,
            'root': body['root'],
          });
          expect(spec, isNotNull,
              reason: 'manifest entry ${entry.key} failed to parse');
          expect(spec!.isValid, isTrue,
              reason: 'manifest entry ${entry.key} invalid: ${spec.validate()}');
        }
      }
      expect(service, isNotNull);
    });
  });

  group('client defaults stay in step with the server', () {
    test('every server key has a client default', () {
      // A new server key with no baked default is still safe (spacer fallback),
      // but it is worth knowing about.
      for (final key in SduiKeys.all) {
        expect(DefaultConfig.specs().containsKey(key), isTrue,
            reason: 'no baked default for "$key"');
      }
    });
  });
}

/// Mirrors HttpSduiService's node re-encoding without needing a live service.
Map<String, dynamic> _reencode(SduiSpec spec) {
  Map<String, dynamic> node(SduiNode n) {
    final out = <String, dynamic>{'type': n.type};
    if (n.id != null) out['id'] = n.id;
    if (n.title != null) out['title'] = n.title;
    if (n.text.isNotEmpty) out['text'] = n.text;
    if (n.gap != 0) out['gap'] = n.gap;
    if (n.height != 0) out['height'] = n.height;
    if (n.style != 'body') out['style'] = n.style;
    if (n.padding.all != 0) out['padding'] = {'all': n.padding.all};
    if (n.onTap.type != 'none') out['on_tap'] = n.onTap.toJson();
    if (n.banners.isNotEmpty) {
      out['banners'] = [
        for (final b in n.banners)
          {'id': b.id, 'title': b.title}
      ];
    }
    if (n.children.isNotEmpty) {
      out['children'] = [for (final c in n.children) node(c)];
    }
    return out;
  }

  return {
    'key': spec.key,
    'version': spec.version,
    'schema_version': spec.schemaVersion,
    'root': node(spec.root),
  };
}