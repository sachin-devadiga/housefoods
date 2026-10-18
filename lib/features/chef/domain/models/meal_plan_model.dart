/// Chef-side models for a kitchen's subscription meal plans.
///
/// Field names mirror `MealPlanSerializer` (camelCase out, snake_case
/// accepted on write). The one contract that must not drift is the slot item
/// snapshot: `backend/api/management/commands/generate_subscriptions.py::_item_rows`
/// reads `menu_item` off every row and *silently drops* rows without it, which
/// produces subscription orders with no dishes. The literal key is written in
/// exactly one place — [MealPlanSlot.snapshotItems] — so it cannot drift.
library;

/// One dish line inside a slot's frozen snapshot.
///
/// name/price are snapshotted on purpose: editing a menu item later must not
/// retroactively change what an existing subscriber signed up for.
class MealPlanItem {
  final String menuItemId;
  final String name;
  final String price;
  final int qty;

  const MealPlanItem({
    required this.menuItemId,
    required this.name,
    required this.price,
    this.qty = 1,
  });

  /// Accepts every spelling the backend tolerates, so a slot round-tripped
  /// through the API still rebuilds. See `_item_rows` for the accepted keys.
  factory MealPlanItem.fromMap(Map<String, dynamic> map) {
    final rawId = map['menu_item'] ??
        map['menu_item_id'] ??
        map['menuItem'] ??
        map['menuItemId'];
    return MealPlanItem(
      menuItemId: rawId?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      price: map['price']?.toString() ?? '0',
      qty: _toInt(map['qty'] ?? map['quantity']) ?? 1,
    );
  }

  double get lineTotal {
    final unit = double.tryParse(price) ?? 0;
    return unit * qty;
  }

  String get summary => qty > 1 ? '$name ×$qty' : name;

  MealPlanItem copyWith({String? name, String? price, int? qty}) {
    return MealPlanItem(
      menuItemId: menuItemId,
      name: name ?? this.name,
      price: price ?? this.price,
      qty: qty ?? this.qty,
    );
  }

  Map<String, dynamic> toSnapshotJson() => snapshotEntry(this);
}

/// Builds one snapshot row.
///
/// This is the single source of truth for the snapshot contract. `menu_item`
/// is a literal key on purpose — the backend drops any row without it, and a
/// dropped row means a subscription order that reaches the kitchen with no
/// dishes to cook.
Map<String, dynamic> snapshotEntry(MealPlanItem item) {
  assert(item.menuItemId.isNotEmpty,
      'meal plan snapshot rows need a menu_item id; empty id produces '
      'subscription orders with no dishes');
  return {
    'menu_item': item.menuItemId,
    'name': item.name,
    'price': item.price,
    'qty': item.qty,
  };
}

int? _toInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '');
}

/// One cell of the 7×3 weekly template, e.g. Monday dinner.
class MealPlanSlot {
  final String id;
  final int dayOfWeek; // 0 = Monday .. 6 = Sunday (PlanSlot.DAY_CHOICES)
  final String mealType; // breakfast | lunch | dinner
  final String dayName;
  final String title;
  final List<MealPlanItem> items;
  final bool isActive;

  const MealPlanSlot({
    required this.dayOfWeek,
    required this.mealType,
    this.id = '',
    this.dayName = '',
    this.title = '',
    this.items = const [],
    this.isActive = true,
  });

  factory MealPlanSlot.fromMap(Map<String, dynamic> map) {
    final rawItems = (map['items'] as List?) ?? const [];
    return MealPlanSlot(
      id: map['id']?.toString() ?? '',
      dayOfWeek: _toInt(map['dayOfWeek'] ?? map['day_of_week']) ?? 0,
      mealType: map['mealType']?.toString() ?? map['meal_type']?.toString() ?? '',
      dayName: map['dayName']?.toString() ?? map['day_name']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map(MealPlanItem.fromMap)
          .toList(),
      isActive: map['isActive'] as bool? ?? map['is_active'] as bool? ?? true,
    );
  }

  /// Mirrors `PlanSlot.slot_total` on the backend: sum of price × qty.
  double get slotTotal {
    var total = 0.0;
    for (final item in items) {
      total += item.lineTotal;
    }
    return total;
  }

  bool get isEmpty => items.isEmpty;

  /// Cell subtitle, e.g. "Dal Rice ×2".
  String get summary {
    if (items.isEmpty) return '';
    return items.map((i) => i.summary).join(', ');
  }

  MealPlanSlot copyWith({
    String? title,
    List<MealPlanItem>? items,
    bool? isActive,
  }) {
    return MealPlanSlot(
      id: id,
      dayOfWeek: dayOfWeek,
      mealType: mealType,
      dayName: dayName,
      title: title ?? this.title,
      items: items ?? this.items,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toWriteJson() => {
        'day_of_week': dayOfWeek,
        'meal_type': mealType,
        'title': title,
        'items': items.map(snapshotEntry).toList(),
        'is_active': isActive,
      };
}

/// One billable cadence for a plan. Duration is derived server-side, never sent.
class PlanPrice {
  final String id;
  final String cadence; // week | month | year
  final String price;
  final int durationDays;
  final bool isActive;

  const PlanPrice({
    required this.cadence,
    required this.price,
    this.id = '',
    this.durationDays = 0,
    this.isActive = true,
  });

  /// `PlanPrice.DURATION_DAYS` on the backend, mirrored for the price hint.
  static const Map<String, int> cadenceDays = {
    'week': 7,
    'month': 30,
    'year': 365,
  };

  static const List<String> cadences = ['week', 'month', 'year'];

  factory PlanPrice.fromMap(Map<String, dynamic> map) {
    final cadence = map['cadence']?.toString() ?? '';
    return PlanPrice(
      id: map['id']?.toString() ?? '',
      cadence: cadence,
      price: map['price']?.toString() ?? '0',
      durationDays: _toInt(map['durationDays'] ?? map['duration_days']) ??
          cadenceDays[cadence] ??
          30,
      isActive: map['isActive'] as bool? ?? map['is_active'] as bool? ?? true,
    );
  }

  int get days => durationDays > 0 ? durationDays : cadenceDays[cadence] ?? 30;

  PlanPrice copyWith({String? price, bool? isActive}) => PlanPrice(
        id: id,
        cadence: cadence,
        price: price ?? this.price,
        durationDays: durationDays,
        isActive: isActive ?? this.isActive,
      );

  Map<String, dynamic> toWriteJson() => {
        'cadence': cadence,
        'price': price,
        'is_active': isActive,
      };
}

class MealPlan {
  final String id;
  final String kitchenId;
  final String kitchenName;
  final String name;
  final String description;
  final List<String> inclusions;
  final bool isVeg;
  final String imageUrl;
  final bool isActive;
  final String startingPrice;
  final List<PlanPrice> prices;
  final List<MealPlanSlot> slots;

  const MealPlan({
    required this.name,
    this.id = '',
    this.kitchenId = '',
    this.kitchenName = '',
    this.description = '',
    this.inclusions = const [],
    this.isVeg = true,
    this.imageUrl = '',
    this.isActive = true,
    this.startingPrice = '',
    this.prices = const [],
    this.slots = const [],
  });

  factory MealPlan.fromMap(Map<String, dynamic> map) {
    final prices = (map['prices'] as List?) ?? const [];
    final slots = (map['slots'] as List?) ?? const [];
    return MealPlan(
      id: map['id']?.toString() ?? '',
      kitchenId: map['kitchen']?.toString() ?? map['kitchenId']?.toString() ?? '',
      kitchenName: map['kitchenName']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      inclusions: ((map['inclusions'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      isVeg: map['isVeg'] as bool? ?? map['is_veg'] as bool? ?? true,
      imageUrl: map['imageUrl']?.toString() ?? map['image_url']?.toString() ?? '',
      isActive: map['isActive'] as bool? ?? map['is_active'] as bool? ?? true,
      startingPrice:
          map['startingPrice']?.toString() ?? map['starting_price']?.toString() ?? '',
      prices: prices
          .whereType<Map<String, dynamic>>()
          .map(PlanPrice.fromMap)
          .toList(),
      slots: slots
          .whereType<Map<String, dynamic>>()
          .map(MealPlanSlot.fromMap)
          .toList(),
    );
  }

  /// Total value of the weekly template, for the chef's own sanity check.
  double get weeklySlotTotal {
    var total = 0.0;
    for (final slot in slots) {
      total += slot.slotTotal;
    }
    return total;
  }

  int get activeSlotCount => slots.where((s) => s.isActive && !s.isEmpty).length;

  MealPlanSlot? slotAt(int dayOfWeek, String mealType) {
    for (final slot in slots) {
      if (slot.dayOfWeek == dayOfWeek && slot.mealType == mealType) return slot;
    }
    return null;
  }

  PlanPrice? priceFor(String cadence) {
    for (final price in prices) {
      if (price.cadence == cadence) return price;
    }
    return null;
  }

  MealPlan copyWith({
    String? id,
    String? kitchenId,
    String? name,
    String? description,
    List<String>? inclusions,
    bool? isVeg,
    String? imageUrl,
    bool? isActive,
    String? startingPrice,
    List<PlanPrice>? prices,
    List<MealPlanSlot>? slots,
  }) {
    return MealPlan(
      // `id` is settable so a duplicated plan can be forced back to
      // "unsaved" (id: '') and POST as a new plan rather than PATCH the
      // original over the top.
      id: id ?? this.id,
      kitchenId: kitchenId ?? this.kitchenId,
      kitchenName: kitchenName,
      name: name ?? this.name,
      description: description ?? this.description,
      inclusions: inclusions ?? this.inclusions,
      isVeg: isVeg ?? this.isVeg,
      imageUrl: imageUrl ?? this.imageUrl,
      isActive: isActive ?? this.isActive,
      startingPrice: startingPrice ?? this.startingPrice,
      prices: prices ?? this.prices,
      slots: slots ?? this.slots,
    );
  }

  /// Matches `MealPlanWriteSerializer` (a plain ModelSerializer → snake_case).
  Map<String, dynamic> toWriteJson() => {
        'name': name,
        'description': description,
        'inclusions': inclusions,
        'is_veg': isVeg,
        'image_url': imageUrl,
        'is_active': isActive,
        'prices': prices.map((p) => p.toWriteJson()).toList(),
        'slots': slots.map((s) => s.toWriteJson()).toList(),
      };
}