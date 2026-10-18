/// Dart mirror of the SDUI spec contract.
///
/// The authoritative definition is `backend/api/sdui/schema.py`; the two must
/// stay in step. `test/sdui_registry_test.dart` asserts every type declared in
/// `SduiNodeType.all` has a builder in the widget registry, and
/// `backend/api/tests_sdui.py` asserts every baked-in default validates against
/// the Python schema — so a drift in either direction fails a test rather than
/// producing a blank screen.
///
/// Every `fromJson` here is deliberately total and defensive: a missing field
/// yields a sane default instead of throwing. The renderer must never crash on
/// data, because the data comes from a database someone can edit by hand.
library;

import 'package:flutter/material.dart';

/// Closed set of icon names an author may use in a spec.
///
/// Mirrors `schema.ICONS` in backend/api/sdui/schema.py. The list is closed so a
/// typo is a validation error rather than a silently blank space, and so the
/// mapping below is exhaustive.
class SduiIcons {
  SduiIcons._();

  static const List<String> valid = [
    'storefront', 'shopping_bag', 'bolt', 'mic', 'repeat',
    'restaurant', 'delivery', 'star', 'favorite', 'schedule',
    'search', 'location', 'wallet', 'gift', 'support',
    'restaurant_menu', 'eco', 'verified', 'local_offer', 'schedule_send',
  ];

  static const Map<String, IconData> _map = {
    'storefront': Icons.storefront_rounded,
    'shopping_bag': Icons.shopping_bag_rounded,
    'bolt': Icons.bolt_rounded,
    'mic': Icons.mic_rounded,
    'repeat': Icons.repeat_rounded,
    'restaurant': Icons.restaurant_rounded,
    'delivery': Icons.delivery_dining_rounded,
    'star': Icons.star_rounded,
    'favorite': Icons.favorite_rounded,
    'schedule': Icons.schedule_rounded,
    'search': Icons.search_rounded,
    'location': Icons.location_on_rounded,
    'wallet': Icons.account_balance_wallet_rounded,
    'gift': Icons.card_giftcard_rounded,
    'support': Icons.support_agent_rounded,
    'restaurant_menu': Icons.restaurant_menu_rounded,
    'eco': Icons.eco_rounded,
    'verified': Icons.verified_rounded,
    'local_offer': Icons.local_offer_rounded,
    'schedule_send': Icons.schedule_send_rounded,
  };

  /// Resolve an icon name. Returns null for unknown names.
  static IconData? resolve(String? name) => _map[name];
}

/// Canonical node types. Mirrors `schema.ALL_TYPES`.
class SduiNodeType {
  static const String column = 'column';
  static const String row = 'row';
  static const String container = 'container';
  static const String section = 'section';
  static const String text = 'text';
  static const String button = 'button';
  static const String bannerCarousel = 'banner_carousel';
  static const String promoBanner = 'promo_banner';
  static const String kitchenCard = 'kitchen_card';
  static const String dishRow = 'dish_row';
  static const String list = 'list';
  static const String grid = 'grid';
  static const String divider = 'divider';
  static const String spacer = 'spacer';

  static const List<String> all = [
    column, row, container, section, text, button,
    bannerCarousel, promoBanner, kitchenCard, dishRow,
    list, grid, divider, spacer,
  ];

  /// Types that hold children.
  static const List<String> containers = [
    column, row, container, section, list, grid,
  ];

  static bool isKnown(String type) => all.contains(type);
}

/// A tappable action attached to a node.
class SduiAction {
  final String type;
  final String value;

  const SduiAction({this.type = 'none', this.value = ''});

  static const SduiAction none = SduiAction();

  static const List<String> validTypes = [
    'open_url', 'open_screen', 'dismiss', 'none',
  ];

  factory SduiAction.fromJson(Map<String, dynamic>? json) {
    if (json == null) return SduiAction.none;
    final type = (json['type'] as String?) ?? 'none';
    // An unrecognised action degrades to a no-op rather than crashing. The
    // backend rejects these at authoring time; this covers hand-edited rows.
    final safeType = validTypes.contains(type) ? type : 'none';
    return SduiAction(type: safeType, value: (json['value'] as String?) ?? '');
  }

  bool get isTappable => type == 'open_url' || type == 'open_screen';

  Map<String, dynamic> toJson() => {'type': type, 'value': value};
}

class SduiPadding {
  final double all, left, right, top, bottom;

  const SduiPadding({
    this.all = 0,
    this.left = 0,
    this.right = 0,
    this.top = 0,
    this.bottom = 0,
  });

  factory SduiPadding.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const SduiPadding();
    double n(String k) {
      final v = json[k];
      if (v is num) return v.toDouble();
      return 0;
    }

    final all = n('all');
    return SduiPadding(
      all: all,
      // Side-specific values fall back to `all`, matching the CSS shorthand.
      left: n('left') == 0 ? all : n('left'),
      right: n('right') == 0 ? all : n('right'),
      top: n('top') == 0 ? all : n('top'),
      bottom: n('bottom') == 0 ? all : n('bottom'),
    );
  }

  EdgeInsets toEdgeInsets() =>
      EdgeInsets.fromLTRB(left, top, right, bottom);

  static const SduiPadding zero = SduiPadding();
}

class SduiBanner {
  final String id;
  final String title;
  final String subtitle;
  final String? imageUrl;
  final SduiAction action;

  const SduiBanner({
    required this.id,
    required this.title,
    this.subtitle = '',
    this.imageUrl,
    this.action = SduiAction.none,
  });

  factory SduiBanner.fromJson(Map<String, dynamic> json) => SduiBanner(
        id: (json['id'] as String?) ?? '',
        title: (json['title'] as String?) ?? '',
        subtitle: (json['subtitle'] as String?) ?? '',
        imageUrl: json['image_url'] as String?,
        action: SduiAction.fromJson(json['action'] as Map<String, dynamic>?),
      );
}

/// One node in the spec tree.
class SduiNode {
  final String type;
  final String? id;
  final List<SduiNode> children;
  final SduiPadding padding;
  final double gap;
  final SduiAction onTap;

  // Container
  final String? backgroundColor;
  final double borderRadius;

  // Layout
  final CrossAxisAlignment crossAxisAlign;

  // Section
  final String? title;
  final String? subtitle;
  final bool collapsible;

  // Text
  final String text;
  final String style;
  final String? color;
  final TextAlign align;
  final int maxLines;

  // Button
  final String label;
  final String variant;
  final bool enabled;
  final SduiAction action;

  // Banners
  final List<SduiBanner> banners;
  final double height;
  final int autoplayIntervalMs;

  // Content cards
  final String? kitchenId;
  final String? dishId;
  final String? name;
  final String? description;
  final String? price;
  final String? imageUrl;
  final bool available;
  final bool showRating;
  final bool showDistance;

  // Grid / misc
  final int columns;
  final String? itemBuilderHint;

  /// Optional leading icon name. Validated against [SduiIcons.valid]; an
  /// unknown name renders nothing rather than throwing.
  final String? icon;

  const SduiNode({
    required this.type,
    this.id,
    this.children = const [],
    this.padding = SduiPadding.zero,
    this.gap = 0,
    this.onTap = SduiAction.none,
    this.backgroundColor,
    this.borderRadius = 0,
    this.crossAxisAlign = CrossAxisAlignment.start,
    this.title,
    this.subtitle,
    this.collapsible = false,
    this.text = '',
    this.style = 'body',
    this.color,
    this.align = TextAlign.left,
    this.maxLines = 0,
    this.label = '',
    this.variant = 'primary',
    this.enabled = true,
    this.action = SduiAction.none,
    this.banners = const [],
    this.height = 0,
    this.autoplayIntervalMs = 0,
    this.kitchenId,
    this.dishId,
    this.name,
    this.description,
    this.price,
    this.imageUrl,
    this.available = true,
    this.showRating = true,
    this.showDistance = true,
    this.columns = 2,
    this.itemBuilderHint,
    this.icon,
  });

  static double _num(dynamic v, [double fallback = 0]) =>
      v is num ? v.toDouble() : fallback;

  static int _int(dynamic v, [int fallback = 0]) =>
      v is num ? v.toInt() : fallback;

  static String _str(dynamic v, [String fallback = '']) =>
      v is String ? v : fallback;

  /// Icon names are a CLOSED set, mirrored from `schema.ICONS`. An unknown name
  /// is dropped here as well as rejected server-side, so a hand-edited or
  /// stale row cannot produce a blank glyph or an exception.
  static String? _iconName(dynamic v) {
    if (v is! String) return null;
    return SduiIcons.valid.contains(v) ? v : null;
  }

  factory SduiNode.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const SduiNode(type: 'spacer');
    }
    final rawChildren = json['children'];
    final children = <SduiNode>[];
    if (rawChildren is List) {
      for (final c in rawChildren) {
        if (c is Map<String, dynamic>) {
          children.add(SduiNode.fromJson(c));
        } else if (c is Map) {
          children.add(SduiNode.fromJson(Map<String, dynamic>.from(c)));
        }
        // Non-map children are skipped rather than fatal: a bad entry should
        // cost one item, not the whole screen.
      }
    }

    final rawBanners = json['banners'];
    final banners = <SduiBanner>[];
    if (rawBanners is List) {
      for (final b in rawBanners) {
        if (b is Map<String, dynamic>) banners.add(SduiBanner.fromJson(b));
      }
    }

    return SduiNode(
      type: _str(json['type'], 'spacer'),
      id: json['id'] as String?,
      children: children,
      padding: SduiPadding.fromJson(json['padding'] as Map<String, dynamic>?),
      gap: _num(json['gap']),
      onTap: SduiAction.fromJson(json['on_tap'] as Map<String, dynamic>?),
      backgroundColor: json['background_color'] as String?,
      borderRadius: _num(json['border_radius']),
      crossAxisAlign: switch (_str(json['cross_axis_align'], 'start')) {
        'center' => CrossAxisAlignment.center,
        'end' => CrossAxisAlignment.end,
        'stretch' => CrossAxisAlignment.stretch,
        _ => CrossAxisAlignment.start,
      },
      title: json['title'] as String?,
      subtitle: json['subtitle'] as String?,
      collapsible: json['collapsible'] == true,
      text: _str(json['text']),
      style: _str(json['style'], 'body'),
      color: json['color'] as String?,
      align: switch (_str(json['align'], 'left')) {
        'center' => TextAlign.center,
        'right' => TextAlign.right,
        'justify' => TextAlign.justify,
        _ => TextAlign.left,
      },
      maxLines: _int(json['max_lines']),
      label: _str(json['label']),
      variant: _str(json['variant'], 'primary'),
      enabled: json['enabled'] != false,
      action: SduiAction.fromJson(json['action'] as Map<String, dynamic>?),
      banners: banners,
      height: _num(json['height']),
      autoplayIntervalMs: _int(json['autoplay_interval_ms']),
      kitchenId: json['kitchen_id']?.toString(),
      dishId: json['dish_id']?.toString(),
      name: json['name'] as String?,
      description: json['description'] as String?,
      price: json['price']?.toString(),
      imageUrl: json['image_url'] as String?,
      available: json['available'] != false,
      showRating: json['show_rating'] != false,
      showDistance: json['show_distance'] != false,
      columns: _int(json['columns'], 2),
      itemBuilderHint: json['itemBuilderHint'] ?? json['item_builder_hint'] as String?,
      icon: _iconName(json['icon']),
    );
  }

  /// Structural checks. The backend already rejects bad specs at authoring
  /// time; this is the second line of defence for rows written by hand or by an
  /// older client.
  List<String> validate() {
    final errors = <String>[];
    if (!SduiNodeType.isKnown(type)) {
      errors.add('unknown node type "$type"');
    }
    if (SduiNodeType.containers.contains(type) &&
        children.isEmpty &&
        type != SduiNodeType.container) {
      // `container` is a valid childless tap-target (nav items, cards).
      errors.add('"$type" requires at least one child');
    }
    for (final a in [onTap, action]) {
      if (!SduiAction.validTypes.contains(a.type)) {
        errors.add('invalid action type "${a.type}"');
      }
    }
    for (final child in children) {
      errors.addAll(child.validate().map((e) => '$type/$e'));
    }
    return errors;
  }

  bool get isValid => validate().isEmpty;
}

/// A whole screen.
class SduiSpec {
  final String key;
  final int version;
  final int schemaVersion;
  final SduiNode root;

  const SduiSpec({
    required this.key,
    this.version = 1,
    this.schemaVersion = 1,
    required this.root,
  });

  factory SduiSpec.fromJson(Map<String, dynamic> json) => SduiSpec(
        key: (json['key'] as String?) ?? '',
        version: (json['version'] as num?)?.toInt() ?? 1,
        schemaVersion: (json['schema_version'] as num?)?.toInt() ?? 1,
        root: SduiNode.fromJson(json['root'] as Map<String, dynamic>?),
      );

  List<String> validate() {
    final errors = root.validate().map((e) => '$key: $e').toList();
    if (key.isEmpty) errors.add('spec has no key');
    return errors;
  }

  bool get isValid => validate().isEmpty;
}

/// Parsing helper that never throws.
class SduiParse {
  /// Returns a spec, or `null` if the payload is not usable.
  static SduiSpec? trySpec(Map<String, dynamic> json) {
    try {
      final spec = SduiSpec.fromJson(json);
      return spec.isValid ? spec : null;
    } catch (_) {
      return null;
    }
  }

  static SduiNode? tryNode(Object? json) {
    if (json is! Map) return null;
    try {
      return SduiNode.fromJson(Map<String, dynamic>.from(json));
    } catch (_) {
      return null;
    }
  }
}