/// The configuration that ships INSIDE the app binary.
///
/// This is the first of four independent safety guarantees and the reason SDUI
/// can never brick the app:
///
///   1. `default_config.dart` — this file. Compiled into the AAB, always valid,
///      available with no network and no disk access.
///   2. Cache-first boot — the last-known-good spec is persisted and applied
///      before any network call.
///   3. Validation gate — a remote payload must pass `SduiSpec.validate()`
///      before it may replace the cache.
///   4. Total renderer fallback — an unknown node type renders a placeholder
///      instead of throwing. See `sdui_widget_registry.dart`.
///
/// These mirror `backend/api/sdui/schema.py`'s DEFAULTS on purpose: with an
/// empty database the backend serves its own copy, so a fresh install and a
/// total backend outage both still render something coherent.
library;

import 'sdui_types.dart';

const int kSduiSchemaVersion = 1;

/// Keys the client knows about. Adding a key here plus a registry builder is
/// the only change needed to add a server-driven surface.
class SduiKeys {
  static const String customerHome = 'customer_home';
  static const String banners = 'banners';
  static const String onboarding = 'onboarding';
  static const String login = 'login';
  static const String kitchenDetails = 'kitchen_details';
  static const String customerNav = 'customer_nav';
  static const String chefNav = 'chef_nav';
  static const String deliveryNav = 'delivery_nav';

  static const List<String> all = [
    customerHome, banners, onboarding, login,
    kitchenDetails, customerNav, chefNav, deliveryNav,
  ];
}

/// Parsed default specs, built once at first access.
class DefaultConfig {
  DefaultConfig._();

  static Map<String, SduiSpec>? _cache;

  static Map<String, SduiSpec> specs() {
    return _cache ??= _build();
  }

  static SduiSpec specFor(String key) {
    final s = specs()[key];
    if (s != null) return s;
    // Never return null: an unknown key still has to render *something*.
    // A `spacer` is used rather than an empty `column` because an empty layout
    // type fails this module's own validation (`column` requires children), and
    // a spec that cannot validate would defeat the point of a fallback. A spacer
    // is valid, renders as empty space, and cannot throw.
    return SduiSpec(
      key: key,
      schemaVersion: kSduiSchemaVersion,
      root: const SduiNode(type: SduiNodeType.spacer, height: 0),
    );
  }

  static Map<String, dynamic> rawJsonFor(String key) {
    final raw = _raw()[key];
    return raw ?? const <String, dynamic>{};
  }

  static Map<String, dynamic> _raw() => {
        SduiKeys.customerHome: _home,
        SduiKeys.banners: _banners,
        SduiKeys.onboarding: _onboarding,
        SduiKeys.login: _login,
        SduiKeys.kitchenDetails: _kitchenDetails,
        SduiKeys.customerNav: _customerNav,
        SduiKeys.chefNav: _chefNav,
        SduiKeys.deliveryNav: _deliveryNav,
      };

  static Map<String, SduiSpec> _build() {
    final out = <String, SduiSpec>{};
    for (final entry in _raw().entries) {
      try {
        final spec = SduiSpec.fromJson(entry.value);
        if (spec.isValid) {
          out[entry.key] = spec;
        } else {
          // A broken default would ship to every device; fail loudly in debug
          // and fall back to an empty root in release.
          out[entry.key] = SduiSpec(key: entry.key, root: const SduiNode(type: SduiNodeType.spacer));
          assert(
            false,
            'Default SDUI spec "${entry.key}" is invalid: ${spec.validate()}',
          );
        }
      } catch (e) {
        out[entry.key] = SduiSpec(key: entry.key, root: const SduiNode(type: SduiNodeType.spacer));
        assert(false, 'Default SDUI spec "${entry.key}" failed to parse: $e');
      }
    }
    return out;
  }
}

// ---------------------------------------------------------------------------
// Raw JSON. Kept as literals rather than SduiNode constructors so the shape is
// auditable at a glance and matches the backend byte for byte.
// ---------------------------------------------------------------------------

Map<String, dynamic> _wrap(String key, Map<String, dynamic> root) => {
      'key': key,
      'version': 1,
      'schema_version': kSduiSchemaVersion,
      'root': root,
    };

final Map<String, dynamic> _home = _wrap(SduiKeys.customerHome, {
  'type': 'column',
  'gap': 16,
  'padding': {'all': 16},
  'children': [
    {
      'type': 'banner_carousel',
      'id': 'home_promos',
      'height': 160,
      'banners': [
        {
          'id': 'welcome',
          'title': 'Home-cooked, delivered',
          'subtitle': 'Fresh meals from kitchens near you',
        },
      ],
    },
    {
      'type': 'section',
      'id': 'kitchens_near_you',
      'title': 'Kitchens near you',
      'children': [
        {
          'type': 'text',
          'text': 'Browse home kitchens and their daily menus.',
          'style': 'body',
        },
      ],
    },
  ],
});

// `banners` deliberately ships as a zero-height spacer: "no opinion".
//
// This key was originally seeded with a promo_banner, which meant every install
// — and every empty backend, since the fallback chain serves the seeded row —
// rendered a hardcoded promo on the home feed before an admin had done anything.
// A surface that does not exist yet must default to invisible; admins opt in by
// publishing a real spec. See `specIsRenderable` in sdui_screen_view.dart.
final Map<String, dynamic> _banners = _wrap(SduiKeys.banners, {
  'type': 'spacer',
  'height': 0,
});

// Onboarding is a full SDUI surface: each slide is a `section` with an icon, a
// title and a body, so the entire first-run copy is editable without a Play
// release.
//
// The native OnboardingScreen stays the fallback (see `SduiScreenView`), so a
// bad spec here cannot stop anyone reaching the login screen.
final Map<String, dynamic> _onboarding = _wrap(SduiKeys.onboarding, {
  'type': 'list',
  'children': [
    {
      'type': 'section',
      'id': 'slide_discover',
      'title': 'Discover home kitchens near you',
      'subtitle':
          'Real home cooks in your neighbourhood. Every meal is made in an actual home kitchen, not a restaurant.',
      'children': [
        {'type': 'text', 'text': '', 'icon': 'storefront'},
      ],
    },
    {
      'type': 'section',
      'id': 'slide_order',
      'title': 'Easy ordering',
      'subtitle':
          'Order your favourite meals anytime. Add to cart, checkout, and get fast delivery to your doorstep.',
      'children': [
        {'type': 'text', 'text': '', 'icon': 'shopping_bag'},
      ],
    },
    {
      'type': 'section',
      'id': 'slide_delivery',
      'title': 'Fresh food, fast delivery',
      'subtitle':
          'Get hot, fresh food delivered in minutes. Track your order in real-time.',
      'children': [
        {'type': 'text', 'text': '', 'icon': 'bolt'},
      ],
    },
    {
      'type': 'section',
      'id': 'slide_voice',
      'title': 'Just say "Hi MEAL"',
      'subtitle':
          'Order hands-free with our voice assistant. Speak your order and it does the rest.',
      'children': [
        {'type': 'text', 'text': '', 'icon': 'mic'},
      ],
    },
    {
      'type': 'section',
      'id': 'slide_plans',
      'title': 'Meal plans that fit your week',
      'subtitle':
          'Subscribe to a home cook and get fresh meals on a schedule. Skip or cancel any time.',
      'children': [
        {'type': 'text', 'text': '', 'icon': 'repeat'},
      ],
    },
  ],
});

final Map<String, dynamic> _login = _wrap(SduiKeys.login, {
  'type': 'column',
  'gap': 16,
  'padding': {'all': 24},
  'children': [
    {'type': 'text', 'text': 'Welcome to MealIn', 'style': 'h1'},
    {
      'type': 'text',
      'text': 'Enter your email and we will send a one-time code.',
      'style': 'body',
    },
    {
      'type': 'button',
      'label': 'Send OTP',
      'variant': 'primary',
      'action': {'type': 'none'},
    },
  ],
});

// Section ids map to native sections in KitchenDetailsCopy. The dish list is
// NOT described here — it is live provider data, and the server may only
// reword headings and the empty state.
final Map<String, dynamic> _kitchenDetails = _wrap(SduiKeys.kitchenDetails, {
  'type': 'column',
  'gap': 12,
  'padding': {'all': 16},
  'children': [
    {
      'type': 'text',
      'text': 'No dishes in this section yet.',
      'style': 'body',
    },
    {
      'type': 'section',
      'id': 'section_menu',
      'title': 'Menu',
      'children': [
        {'type': 'text', 'text': 'Dishes prepared today', 'style': 'caption'},
      ],
    },
    {
      'type': 'section',
      'id': 'section_reviews',
      'title': 'Reviews',
      'children': [
        {
          'type': 'text',
          'text': 'What other customers said',
          'style': 'caption',
        },
      ],
    },
  ],
});

Map<String, dynamic> _nav(String key, List<String> ids) => _wrap(key, {
      'type': 'list',
      'children': [
        for (final id in ids)
          {
            'type': 'container',
            'id': id,
            'on_tap': {'type': 'open_screen', 'value': id},
          }
      ],
    });

final Map<String, dynamic> _customerNav =
    _nav(SduiKeys.customerNav, ['nav_home', 'nav_orders', 'nav_search', 'nav_subscriptions', 'nav_profile']);
final Map<String, dynamic> _chefNav = _nav(SduiKeys.chefNav, ['chef_dashboard']);
final Map<String, dynamic> _deliveryNav = _nav(SduiKeys.deliveryNav, ['rider_dashboard']);