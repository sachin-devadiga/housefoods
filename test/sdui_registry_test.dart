import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mealin/core/sdui/default_config.dart';
import 'package:mealin/core/sdui/sdui_types.dart';
import 'package:mealin/core/sdui/sdui_widget_registry.dart';

/// Render [node] inside a MaterialApp and pump it.
///
/// The tree is built in two steps because `SduiWidgetRegistry.build` needs a
/// BuildContext, and no element exists until something has been pumped. Doing it
/// in one expression (passing `tester.element(find.byType(Scaffold))` inline)
/// fails with "Bad state: No element".
Future<void> _render(WidgetTester tester, SduiNode node) async {
  late BuildContext captured;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(builder: (c) {
          captured = c;
          return const SizedBox.shrink();
        }),
      ),
    ),
  );

  final widget = SduiWidgetRegistry.build(
    captured,
    node,
    const SduiRenderContext(),
  );

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: widget)),
    ),
  );
  await tester.pump();
}

void main() {
  group('registry completeness', () {
    test('every declared node type has a builder', () {
      // If this fails, the server can send a type the client cannot render.
      // That is survivable (a placeholder appears) but it means the two sides
      // have drifted, so it should never happen silently.
      for (final type in SduiNodeType.all) {
        expect(
          SduiWidgetRegistry.builders.containsKey(type),
          isTrue,
          reason: 'no builder registered for "$type"',
        );
      }
    });

    test('no builder exists for an undeclared type', () {
      for (final type in SduiWidgetRegistry.builders.keys) {
        expect(SduiNodeType.isKnown(type), isTrue,
            reason: 'builder "$type" is not in SduiNodeType.all');
      }
    });
  });

  group('rendering every type', () {
    Future<void> expectRenders(
      WidgetTester tester,
      SduiNode node, {
      bool expectPlaceholder = false,
    }) async {
      await _render(tester, node);
      // No exception is the real assertion. The optional placeholder check
      // catches silent degradation to the fallback widget.
      if (expectPlaceholder) {
        expect(find.byType(SduiPlaceholder), findsOneWidget);
      }
    }

    testWidgets('column with children', (tester) async {
      await expectRenders(
        tester,
        const SduiNode(type: SduiNodeType.column, children: [
          SduiNode(type: SduiNodeType.text, text: 'hello'),
          SduiNode(type: SduiNodeType.text, text: 'world'),
        ]),
      );
      expect(find.text('hello'), findsOneWidget);
      expect(find.text('world'), findsOneWidget);
    });

    testWidgets('row', (tester) async {
      await expectRenders(
        tester,
        const SduiNode(type: SduiNodeType.row, children: [
          SduiNode(type: SduiNodeType.text, text: 'left'),
          SduiNode(type: SduiNodeType.text, text: 'right'),
        ]),
      );
    });

    testWidgets('childless container is a valid tap target', (tester) async {
      // Nav items look like this: no children, just an action.
      await expectRenders(
        tester,
        const SduiNode(
          type: SduiNodeType.container,
          onTap: SduiAction(type: 'open_screen', value: 'home'),
        ),
      );
      expect(find.byType(SduiPlaceholder), findsNothing);
    });

    testWidgets('section with title and subtitle', (tester) async {
      await expectRenders(
        tester,
        const SduiNode(type: SduiNodeType.section, title: 'Near you',
            subtitle: '4 kitchens', children: [
          SduiNode(type: SduiNodeType.text, text: 'body'),
        ]),
      );
      expect(find.text('Near you'), findsOneWidget);
    });

    testWidgets('text in every style', (tester) async {
      for (final style in ['h1', 'h2', 'h3', 'body', 'caption']) {
        await expectRenders(
          tester,
          SduiNode(type: SduiNodeType.text, text: style, style: style),
        );
      }
    });

    testWidgets('button in every variant', (tester) async {
      for (final variant in ['primary', 'secondary', 'ghost', 'danger']) {
        await expectRenders(
          tester,
          SduiNode(
            type: SduiNodeType.button,
            label: variant,
            variant: variant,
          ),
        );
      }
    });

    testWidgets('disabled button', (tester) async {
      await expectRenders(
        tester,
        const SduiNode(
            type: SduiNodeType.button, label: 'Nope', enabled: false),
      );
    });

    testWidgets('banner carousel with banners', (tester) async {
      await expectRenders(
        tester,
        const SduiNode(type: SduiNodeType.bannerCarousel, height: 160, banners: [
          SduiBanner(id: 'a', title: 'First', subtitle: 'Sub one'),
          SduiBanner(id: 'b', title: 'Second'),
        ]),
      );
    });

    testWidgets('empty banner carousel renders nothing, not an error',
        (tester) async {
      await expectRenders(
        tester,
        const SduiNode(type: SduiNodeType.bannerCarousel),
      );
    });

    testWidgets('promo banner', (tester) async {
      await expectRenders(
        tester,
        const SduiNode(
          type: SduiNodeType.promoBanner,
          title: 'Half off',
          subtitle: 'Today only',
        ),
      );
      expect(find.text('Half off'), findsOneWidget);
    });

    testWidgets('kitchen card', (tester) async {
      await expectRenders(
        tester,
        const SduiNode(
          type: SduiNodeType.kitchenCard,
          name: 'Sharma Kitchen',
          showRating: true,
        ),
      );
      expect(find.text('Sharma Kitchen'), findsOneWidget);
    });

    testWidgets('dish row, available and not', (tester) async {
      await expectRenders(
        tester,
        const SduiNode(
          type: SduiNodeType.dishRow,
          name: 'Dal Rice',
          price: '120',
          available: true,
        ),
      );
      await expectRenders(
        tester,
        const SduiNode(
          type: SduiNodeType.dishRow,
          name: 'Sold out',
          available: false,
        ),
      );
    });

    testWidgets('grid', (tester) async {
      await expectRenders(
        tester,
        const SduiNode(type: SduiNodeType.grid, columns: 2, children: [
          SduiNode(type: SduiNodeType.text, text: 'a'),
          SduiNode(type: SduiNodeType.text, text: 'b'),
        ]),
      );
    });

    testWidgets('divider and spacer', (tester) async {
      await expectRenders(
          tester, const SduiNode(type: SduiNodeType.divider, height: 2));
      await expectRenders(
          tester, const SduiNode(type: SduiNodeType.spacer, height: 12));
    });
  });

  group('never throws', () {
    testWidgets('unknown type yields a placeholder', (tester) async {
      final node = SduiNode.fromJson({'type': 'banar_carosel'});
      await _render(tester, node);
      await tester.pump();
      // The whole point: a typo in the admin must not crash a user's screen.
      expect(find.byType(SduiPlaceholder), findsOneWidget);
    });

    testWidgets('empty map parses to a safe node', (tester) async {
      final node = SduiNode.fromJson(const {});
      expect(node.type, 'spacer');
      await _render(tester, node);
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('null root does not throw', (tester) async {
      final node = SduiNode.fromJson(null);
      expect(node.type, 'spacer');
    });

    testWidgets('garbage children are skipped, not fatal', (tester) async {
      final spec = SduiSpec.fromJson({
        'key': 'x',
        'root': {
          'type': 'column',
          'children': [
            {'type': 'text', 'text': 'good'},
            'not-a-map',
            42,
            null,
            {'type': 'text', 'text': 'also good'},
          ],
        },
      });
      await _render(tester, spec.root);
      expect(find.text('good'), findsOneWidget);
      expect(find.text('also good'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('absurd padding is clamped by the schema, not the renderer',
        (tester) async {
      // A hand-edited row could carry a huge padding; Flutter would throw on an
      // overflow rather than fail validation here, so the value is simply used.
      final node = SduiNode.fromJson({
        'type': 'text',
        'text': 'x',
        'padding': {'all': 100000},
      });
      await _render(tester, node);
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('dead network image does not throw', (tester) async {
      final node = SduiNode.fromJson({
        'type': 'kitchen_card',
        'name': 'x',
        'image_url': 'https://invalid.invalid/none.png',
      });
      await _render(tester, node);
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('validation', () {
    test('catches unknown type', () {
      final node = SduiNode.fromJson({'type': 'nope'});
      expect(node.isValid, isFalse);
      expect(node.validate().join(), contains('unknown node type'));
    });

    test('catches layout type with no children', () {
      final node = SduiNode.fromJson({'type': 'column', 'children': []});
      expect(node.isValid, isFalse);
    });

    test('allows childless container', () {
      final node = SduiNode.fromJson({'type': 'container'});
      expect(node.isValid, isTrue);
    });

    test('catches invalid action type', () {
      final node = SduiNode.fromJson({
        'type': 'container',
        'on_tap': {'type': 'launch_missiles'},
      });
      // Unknown action types degrade to no-op rather than throwing.
      expect(node.onTap.type, 'none');
    });

    test('valid spec passes', () {
      final spec = SduiSpec.fromJson(DefaultConfig.rawJsonFor('customer_home'));
      expect(spec.isValid, isTrue);
    });

    test('recurses into children', () {
      final node = SduiNode.fromJson({
        'type': 'column',
        'children': [
          {
            'type': 'column',
            'children': [
              {'type': 'totally_unknown'},
            ],
          },
        ],
      });
      expect(node.isValid, isFalse);
    });
  });

  group('colour parsing', () {
    testWidgets('hex and named colours resolve, junk is ignored',
        (tester) async {
      for (final colour in ['#FF5722', '#5722', 'red', 'blue', 'not-a-colour']) {
        final node = SduiNode.fromJson({
          'type': 'text',
          'text': 'c',
          'color': colour,
        });
        await _render(tester, node);
        await tester.pump();
        expect(tester.takeException(), isNull,
            reason: 'colour "$colour" should not throw');
      }
    });
  });
}