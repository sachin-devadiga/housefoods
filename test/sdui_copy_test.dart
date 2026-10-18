import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:mealin/core/sdui/default_config.dart';
import 'package:mealin/core/sdui/kitchen_details_copy.dart';
import 'package:mealin/core/sdui/login_copy.dart';
import 'package:mealin/core/sdui/sdui_provider.dart';
import 'package:mealin/core/sdui/sdui_service.dart';
import 'package:mealin/core/sdui/sdui_types.dart';

class _Stub extends SduiService {
  _Stub(this.screens);
  final Map<String, SduiSpec> screens;

  @override
  Future<Map<String, SduiSpec>> fetchManifest({String role = 'customer'}) async =>
      screens;
  @override
  Future<Map<String, dynamic>?> fetchBootstrap() async => {
        'schema_version': 1,
        'maintenance': {'enabled': false, 'message': ''},
      };
  @override
  Future<SduiSpec?> fetchScreen(String key) async => screens[key];
  @override
  Future<Map<String, dynamic>?> readBootstrapCache() async => null;
  @override
  Future<SduiSpec?> readScreenCache(String key) async => null;
  @override
  Future<bool> probe() async => true;
}

/// Build a context that can resolve a spec via the real resolver classes.
Future<BuildContext> _contextWith(
  WidgetTester tester,
  Map<String, SduiSpec> screens,
) async {
  final provider = SduiProvider(service: _Stub(screens));
  await provider.bootstrap();
  late BuildContext captured;
  await tester.pumpWidget(
    ChangeNotifierProvider<SduiProvider>.value(
      value: provider,
      child: MaterialApp(
        home: Builder(builder: (c) {
          captured = c;
          return const SizedBox.shrink();
        }),
      ),
    ),
  );
  return captured;
}

void main() {
  group('LoginCopy', () {
    testWidgets('reads title and subtitle from the published spec',
        (tester) async {
      final ctx = await _contextWith(tester, {
        SduiKeys.login: SduiSpec.fromJson({
          'key': SduiKeys.login,
          'root': {
            'type': 'column',
            'children': [
              {'type': 'text', 'text': 'Server title', 'style': 'h1'},
              {'type': 'text', 'text': 'Server subtitle'},
            ],
          },
        }),
      });

      final copy = LoginCopy.resolve(ctx);
      expect(copy.title, 'Server title');
      expect(copy.subtitle, 'Server subtitle');
    });

    testWidgets('blank text does not blank out the native heading',
        (tester) async {
      final ctx = await _contextWith(tester, {
        SduiKeys.login: SduiSpec.fromJson({
          'key': SduiKeys.login,
          'root': {
            'type': 'column',
            'children': [
              {'type': 'text', 'text': '   ', 'style': 'h1'},
            ],
          },
        }),
      });

      // Whitespace-only copy must resolve to null so the caller keeps its own
      // string, rather than rendering an empty title.
      expect(LoginCopy.resolve(ctx).title, isNull);
    });

    test('shipped login spec is valid', () {
      final spec = SduiSpec.fromJson(DefaultConfig.rawJsonFor(SduiKeys.login));
      expect(spec.isValid, isTrue);
    });
  });

  group('KitchenDetailsCopy', () {
    test('shipped spec is valid', () {
      final spec =
          SduiSpec.fromJson(DefaultConfig.rawJsonFor(SduiKeys.kitchenDetails));
      expect(spec.isValid, isTrue);
    });

    test('spec carries both section ids the resolver looks for', () {
      final spec =
          SduiSpec.fromJson(DefaultConfig.rawJsonFor(SduiKeys.kitchenDetails));
      final ids = spec.root.children.map((n) => n.id).toSet();
      expect(ids, contains('section_menu'));
      expect(ids, contains('section_reviews'));
    });

    test('missing headings fall back to the native strings', () {
      // An empty spec must never blank out a section title.
      const copy = KitchenDetailsCopy.empty;
      expect(copy.menu, 'Menu');
      expect(copy.reviews, 'Reviews');
      expect(copy.emptyMessage, 'No dishes in this section yet.');
    });

    test('defaults are distinct per field', () {
      const copy = KitchenDetailsCopy.empty;
      expect(copy.menu, isNot(copy.reviews));
    });
  });

  group('copy resolvers never throw without a provider', () {
    testWidgets('LoginCopy.resolve on a bare context returns empty',
        (tester) async {
      late BuildContext captured;
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (c) {
          captured = c;
          return const SizedBox.shrink();
        }),
      ));
      // No SduiProvider above this context. The resolver must degrade rather
      // than throw, because these run inside build().
      expect(LoginCopy.resolve(captured), const LoginCopy());
    });

    testWidgets('KitchenDetailsCopy.resolve on a bare context returns empty',
        (tester) async {
      late BuildContext captured;
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (c) {
          captured = c;
          return const SizedBox.shrink();
        }),
      ));
      expect(KitchenDetailsCopy.resolve(captured), const KitchenDetailsCopy());
    });
  });
}