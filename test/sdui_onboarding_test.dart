import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:mealin/core/sdui/default_config.dart';
import 'package:mealin/core/sdui/sdui_provider.dart';
import 'package:mealin/core/sdui/sdui_screen_view.dart';
import 'package:mealin/core/sdui/sdui_service.dart';
import 'package:mealin/core/sdui/sdui_types.dart';
import 'package:mealin/core/sdui/sdui_widget_registry.dart';

/// Serves a caller-supplied spec set, so a test can simulate a published
/// onboarding layout without a backend.
class _Stub extends SduiService {
  _Stub(this.screens);
  final Map<String, SduiSpec> screens;

  @override
  Future<Map<String, SduiSpec>> fetchManifest({String role = 'customer'}) async =>
      screens;
  @override
  Future<Map<String, dynamic>?> fetchBootstrap() async =>
      {'schema_version': 1, 'maintenance': {'enabled': false, 'message': ''}};
  @override
  Future<SduiSpec?> fetchScreen(String key) async => screens[key];
  @override
  Future<Map<String, dynamic>?> readBootstrapCache() async => null;
  @override
  Future<SduiSpec?> readScreenCache(String key) async => null;
  @override
  Future<bool> probe() async => true;
}

Future<SduiProvider> _pump(WidgetTester tester, Widget child, SduiProvider p) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<SduiProvider>.value(
      value: p,
      child: MaterialApp(home: Scaffold(body: child)),
    ),
  );
  await tester.pump();
  return p;
}

void main() {
  group('icon contract', () {
    test('every valid icon name resolves to an IconData', () {
      for (final name in SduiIcons.valid) {
        expect(SduiIcons.resolve(name), isNotNull,
            reason: 'icon "$name" has no mapping');
      }
    });

    test('no mapping exists for an undeclared icon name', () {
      // Guards drift between SduiIcons.valid and its internal map.
      expect(SduiIcons.resolve('definitely_not_an_icon'), isNull);
    });

    test('unknown icon name in a spec is dropped, not fatal', () {
      final node = SduiNode.fromJson({
        'type': 'text',
        'text': 'hello',
        'icon': 'nonexistent_icon',
      });
      expect(node.icon, isNull);
      expect(node.isValid, isTrue, reason: 'unknown icon must not fail the spec');
    });

    test('valid icon name survives parsing', () {
      final node = SduiNode.fromJson({
        'type': 'text',
        'text': 'hello',
        'icon': 'storefront',
      });
      expect(node.icon, 'storefront');
    });

    testWidgets('text with an icon renders the glyph', (tester) async {
      final provider = SduiProvider(service: _Stub(const {}));
      await provider.bootstrap();
      await _pump(
        tester,
        const SduiWidgetHost(text: 'Home kitchens', icon: 'storefront'),
        provider,
      );
      expect(find.text('Home kitchens'), findsOneWidget);
      expect(find.byIcon(Icons.storefront_rounded), findsOneWidget);
    });

    testWidgets('text without an icon renders no glyph', (tester) async {
      final provider = SduiProvider(service: _Stub(const {}));
      await provider.bootstrap();
      await _pump(tester, const SduiWidgetHost(text: 'Plain'), provider);
      expect(find.text('Plain'), findsOneWidget);
      expect(find.byType(Icon), findsNothing);
    });
  });

  group('onboarding spec', () {
    late SduiSpec spec;

    setUp(() {
      spec = SduiSpec.fromJson(DefaultConfig.rawJsonFor(SduiKeys.onboarding));
    });

    test('parses as a list of sections', () {
      expect(spec.root.type, SduiNodeType.list);
      expect(spec.root.children, isNotEmpty);
    });

    test('every slide has an id, title, subtitle and icon', () {
      for (final slide in spec.root.children) {
        expect(slide.type, SduiNodeType.section);
        expect(slide.id, isNotNull);
        expect(slide.title, isNotNull);
        expect(slide.title, isNotEmpty);
        expect(slide.subtitle, isNotEmpty);
        expect(slide.children, isNotEmpty);
        expect(SduiIcons.resolve(slide.children.first.icon), isNotNull,
            reason: 'slide ${slide.id} has an unresolvable icon');
      }
    });

    test('slide ids are unique — the PageView needs stable identity', () {
      final ids = spec.root.children.map((s) => s.id).toSet();
      expect(ids.length, spec.root.children.length);
    });

    test('onboarding copy says home kitchens, never restaurants', () {
      // Brand guard. The Play listing and the app both position Mealin as
      // home cooks instead of restaurants, so the first-run copy must agree.
      for (final slide in spec.root.children) {
        final blob = '${slide.title} ${slide.subtitle}'.toLowerCase();
        expect(blob.contains('restaurant') && !blob.contains('home kitchen'),
            isFalse,
            reason: 'slide ${slide.id} contradicts the home-kitchen position');
      }
    });

    test('the shipped onboarding spec is renderable', () {
      expect(specIsRenderable(spec), isTrue);
    });
  });

  group('onboarding surface falls back safely', () {
    testWidgets('no published spec -> native slides still render',
        (tester) async {
      final provider = SduiProvider(
        service: _Stub({
          SduiKeys.onboarding: SduiSpec.fromJson({
            'key': SduiKeys.onboarding,
            'root': {'type': 'list', 'children': []},
          }),
        }),
      );
      await provider.bootstrap();
      // An empty list is "no opinion", so the screen must fall back rather than
      // render an empty carousel.
      expect(provider.isRenderable(SduiKeys.onboarding), isFalse);

      await _pump(
        tester,
        SduiScreenView(
          specKey: SduiKeys.onboarding,
          fallback: const Text('NATIVE ONBOARDING'),
        ),
        provider,
      );
      expect(find.text('NATIVE ONBOARDING'), findsOneWidget);
    });

    testWidgets('published spec replaces the native fallback', (tester) async {
      final provider = SduiProvider(
        service: _Stub({
          SduiKeys.onboarding: SduiSpec.fromJson({
            'key': SduiKeys.onboarding,
            'root': {
              'type': 'list',
              'children': [
                {
                  'type': 'section',
                  'id': 's1',
                  'title': 'SERVER COPY',
                  'subtitle': 'from the backend',
                  'children': [
                    {'type': 'text', 'text': '', 'icon': 'bolt'},
                  ],
                },
              ],
            },
          }),
        }),
      );
      await provider.bootstrap();

      await _pump(
        tester,
        SduiScreenView(
          specKey: SduiKeys.onboarding,
          fallback: const Text('NATIVE ONBOARDING'),
        ),
        provider,
      );
      expect(find.text('SERVER COPY'), findsOneWidget);
      expect(find.text('NATIVE ONBOARDING'), findsNothing);
    });
  });
}

/// Renders a `text` node directly, so the icon tests can isolate one builder
/// rather than standing up a whole screen.
class SduiWidgetHost extends StatelessWidget {
  const SduiWidgetHost({super.key, required this.text, this.icon});

  final String text;
  final String? icon;

  @override
  Widget build(BuildContext context) {
    return SduiWidgetRegistry.build(
      context,
      SduiNode.fromJson({
        'type': 'text',
        'text': text,
        if (icon != null) 'icon': icon,
      }),
      const SduiRenderContext(),
    );
  }
}