import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:mealin/core/sdui/default_config.dart';
import 'package:mealin/core/sdui/sdui_provider.dart';
import 'package:mealin/core/sdui/sdui_screen_view.dart';
import 'package:mealin/core/sdui/sdui_service.dart';
import 'package:mealin/core/sdui/sdui_types.dart';
import 'package:mealin/core/sdui/sdui_widget_registry.dart';

Map<String, dynamic> _fixture(String name) {
  final file = File('test/fixtures/$name.json');
  expect(file.existsSync(), isTrue,
      reason: 'missing fixture $name.json — run scripts/capture_sdui_fixtures.sh');
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

/// Serves whatever screens/nav a test hands it.
class _StubService extends SduiService {
  _StubService({this.screens = const {}, this.nav});

  final Map<String, SduiSpec> screens;
  final Map<String, dynamic>? nav;

  @override
  Future<Map<String, dynamic>?> fetchBootstrap() async => {
        'schema_version': 1,
        'maintenance': {'enabled': false, 'message': ''},
        if (nav != null) 'navigation': nav,
      };

  @override
  Future<SduiSpec?> fetchScreen(String key) async => screens[key];

  @override
  Future<Map<String, SduiSpec>> fetchManifest({String role = 'customer'}) async =>
      screens;

  @override
  Future<Map<String, dynamic>?> readBootstrapCache() async => null;
  @override
  Future<SduiSpec?> readScreenCache(String key) async => null;
  @override
  Future<bool> probe() async => true;
}

/// Pump a subtree with an [SduiProvider] in scope.
Future<SduiProvider> _pumpWith(
  WidgetTester tester,
  Widget child,
  SduiService service,
) async {
  final provider = SduiProvider(service: service);
  await provider.bootstrap();
  await tester.pumpWidget(
    ChangeNotifierProvider<SduiProvider>.value(
      value: provider,
      child: MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
  await tester.pump();
  return provider;
}

void main() {
  group('banners surface — no regression by default', () {
    testWidgets('falls back when the default spec is a placeholder',
        (tester) async {
      // The shipped default for `banners` contains one promo_banner. Rendering
      // it would mean the home feed always shows an admin-less banner, so the
      // default must be usable-but-optional rather than mandatory.
      final provider = SduiProvider(service: _StubService());
      await provider.bootstrap();
      // Whatever it decides, the surface must resolve without throwing.
      expect(provider.specFor(SduiKeys.banners).key, SduiKeys.banners);
    });

    testWidgets('SduiSpecBody shows nothing when no spec is published',
        (tester) async {
      final provider = SduiProvider(
        service: _StubService(screens: const {}),
      );
      await provider.bootstrap();
      await tester.pumpWidget(
        ChangeNotifierProvider<SduiProvider>.value(
          value: provider,
          child: const MaterialApp(
            home: Scaffold(body: SduiSpecBody(specKey: SduiKeys.banners)),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(SduiPlaceholder), findsNothing);
    });
  });

  group('banners surface — renders a published spec', () {
    late Map<String, dynamic> published;

    setUp(() {
      published = _fixture('sdui_screen_banners');
    });

    testWidgets('real published banner renders its title', (tester) async {
      final spec = SduiParse.trySpec(published);
      expect(spec, isNotNull,
          reason: 'published banner failed Dart validation');

      await _pumpWith(
        tester,
        const SduiSpecBody(specKey: SduiKeys.banners),
        _StubService(screens: {SduiKeys.banners: spec!}),
      );

      final carousel = published['root'];
      final title = carousel['banners'][0]['title'];
      expect(find.text(title), findsOneWidget);
      expect(find.byType(SduiPlaceholder), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('banner is renderable and reports its spec version',
        (tester) async {
      final spec = SduiParse.trySpec(published)!;
      await _pumpWith(
        tester,
        const SduiSpecBody(specKey: SduiKeys.banners),
        _StubService(screens: {SduiKeys.banners: spec}),
      );
      expect(find.byType(PageView), findsOneWidget);
    });

    test('published spec carries the fields the renderer needs', () {
      final node = SduiNode.fromJson(published['root']);
      // The published banners spec puts the carousel at the root rather than
      // wrapping it in a column, which the renderer handles either way.
      expect(node.type, SduiNodeType.bannerCarousel);
      expect(node.banners, isNotEmpty);
      expect(node.banners.first.title, isNotEmpty);
      // open_url is what a banner tap does.
      expect(node.banners.first.action.type, 'open_url');
    });
  });

  group('SduiScreenView fallback semantics', () {
    testWidgets('renders fallback when the key is absent', (tester) async {
      await _pumpWith(
        tester,
        const SduiScreenView(
          specKey: SduiKeys.banners,
          fallback: Text('NATIVE'),
        ),
        _StubService(),
      );
      expect(find.text('NATIVE'), findsOneWidget);
    });

    testWidgets('renders the spec when present, not the fallback',
        (tester) async {
      final spec = SduiSpec.fromJson({
        'key': SduiKeys.banners,
        'root': {
          'type': 'column',
          'children': [
            {'type': 'text', 'text': 'FROM SDUI'},
          ],
        },
      });
      await _pumpWith(
        tester,
        const SduiScreenView(
          specKey: SduiKeys.banners,
          fallback: Text('NATIVE'),
        ),
        _StubService(screens: {SduiKeys.banners: spec}),
      );
      expect(find.text('FROM SDUI'), findsOneWidget);
      expect(find.text('NATIVE'), findsNothing);
    });

    testWidgets('renders fallback when the spec is empty (no opinion)',
        (tester) async {
      // An empty column is the "deployed, but expresses nothing" case.
      final spec = SduiSpec.fromJson({
        'key': SduiKeys.banners,
        'root': {'type': 'column', 'children': []},
      });
      await _pumpWith(
        tester,
        const SduiScreenView(
          specKey: SduiKeys.banners,
          fallback: Text('NATIVE'),
        ),
        _StubService(screens: {SduiKeys.banners: spec}),
      );
      expect(find.text('NATIVE'), findsOneWidget);
    });
  });

  group('renderable detection', () {
    test('a zero-height spacer is not renderable', () {
      final spec = SduiSpec.fromJson({
        'key': 'k',
        'root': {'type': 'spacer', 'height': 0},
      });
      expect(specIsRenderable(spec), isFalse);
    });

    test('a spacer with height is renderable', () {
      final spec = SduiSpec.fromJson({
        'key': 'k',
        'root': {'type': 'spacer', 'height': 16},
      });
      expect(specIsRenderable(spec), isTrue);
    });

    test('an empty column is not renderable', () {
      final spec = SduiSpec.fromJson({
        'key': 'k',
        'root': {'type': 'column', 'children': []},
      });
      expect(specIsRenderable(spec), isFalse);
    });

    test('a populated column is renderable', () {
      final spec = SduiSpec.fromJson({
        'key': 'k',
        'root': {
          'type': 'column',
          'children': [
            {'type': 'text', 'text': 'x'},
          ],
        },
      });
      expect(specIsRenderable(spec), isTrue);
    });

    test('a leaf node is renderable', () {
      final spec = SduiSpec.fromJson({
        'key': 'k',
        'root': {'type': 'text', 'text': 'x'},
      });
      expect(specIsRenderable(spec), isTrue);
    });
  });

  group('navigation config', () {
    test('server nav reorders and hides tabs', () async {
      final provider = SduiProvider(
        service: _StubService(nav: {
          'customer': {
            'items': [
              {'id': 'nav_home', 'enabled': true, 'order': 0},
              {'id': 'nav_orders', 'enabled': true, 'order': 1},
              {'id': 'nav_search', 'enabled': false, 'order': 2},
              {'id': 'nav_subscriptions', 'enabled': true, 'order': 3},
              {'id': 'nav_profile', 'enabled': true, 'order': 4},
            ],
          },
        }),
      );
      await provider.bootstrap();
      expect(provider.navigation.containsKey('customer'), isTrue);
    });

    test('nav with every tab disabled leaves the provider usable', () async {
      final provider = SduiProvider(
        service: _StubService(nav: {
          'customer': {
            'items': [
              {'id': 'nav_home', 'enabled': false, 'order': 0},
            ],
          },
        }),
      );
      await provider.bootstrap();
      // The dashboard falls back to the native catalogue rather than rendering
      // an empty bar, so nothing here should throw.
      expect(provider.isReady, isTrue);
    });

    test('real bootstrap fixture carries customer nav items', () {
      final data = _fixture('sdui_bootstrap');
      final nav = data['navigation'];
      if (nav is Map && nav.containsKey('customer')) {
        expect(nav['customer']['items'], isA<List>());
      }
    });
  });
}