// Models for the customer subscription flow.
//
// Field names mirror `backend/api/serializers.py` (SUBSCRIPTION SERIALIZERS).
// Read serializers inherit CamelCaseModelSerializer, so keys arrive camelCase.
// Money arrives as a string (Decimal -> str) and is parsed with
// double.tryParse, exactly as order_model.dart does — round-tripping paise
// through a JSON float loses money.

/// One billable cadence for a plan (week | month | year).
class PlanPriceModel {
  final String id;
  final String cadence;
  final double price;
  final int durationDays;
  final bool isActive;

  PlanPriceModel({
    required this.id,
    required this.cadence,
    required this.price,
    required this.durationDays,
    required this.isActive,
  });

  String get cadenceLabel {
    switch (cadence) {
      case 'week':
        return 'Weekly';
      case 'month':
        return 'Monthly';
      case 'year':
        return 'Yearly';
      default:
        return cadence;
    }
  }

  factory PlanPriceModel.fromMap(Map<String, dynamic> map) {
    return PlanPriceModel(
      id: '${map['id'] ?? ''}',
      cadence: '${map['cadence'] ?? 'week'}',
      price: double.tryParse('${map['price'] ?? '0'}') ?? 0.0,
      durationDays: int.tryParse('${map['durationDays'] ?? 0}') ?? 0,
      isActive: map['isActive'] ?? true,
    );
  }
}

/// One cell of a kitchen's weekly template, e.g. Monday dinner.
class PlanSlotModel {
  final String id;
  final int dayOfWeek; // 0 = Monday .. 6 = Sunday
  final String dayName;
  final String mealType; // breakfast | lunch | dinner
  final String title;
  final List<dynamic> items;
  final double slotTotal;
  final bool isActive;

  PlanSlotModel({
    required this.id,
    required this.dayOfWeek,
    required this.dayName,
    required this.mealType,
    required this.title,
    required this.items,
    required this.slotTotal,
    required this.isActive,
  });

  String get mealTypeLabel {
    if (mealType.isEmpty) return '';
    return mealType[0].toUpperCase() + mealType.substring(1);
  }

  /// Item names captured at publish time. Items are `{menu_item, name, qty,
  /// price}` dicts; anything without a usable name is skipped rather than
  /// rendered as "null".
  List<String> get itemNames {
    final names = <String>[];
    for (final item in items) {
      if (item is Map) {
        final name = item['name'];
        if (name != null && '$name'.trim().isNotEmpty) names.add('$name');
      } else if (item != null && '$item'.trim().isNotEmpty) {
        names.add('$item');
      }
    }
    return names;
  }

  factory PlanSlotModel.fromMap(Map<String, dynamic> map) {
    return PlanSlotModel(
      id: '${map['id'] ?? ''}',
      dayOfWeek: int.tryParse('${map['dayOfWeek'] ?? 0}') ?? 0,
      dayName: '${map['dayName'] ?? ''}',
      mealType: '${map['mealType'] ?? ''}',
      title: '${map['title'] ?? ''}',
      items: (map['items'] as List<dynamic>?) ?? const [],
      slotTotal: double.tryParse('${map['slotTotal'] ?? '0'}') ?? 0.0,
      isActive: map['isActive'] ?? true,
    );
  }
}

/// A kitchen's meal plan, as returned by `subscriptions/plans/`.
class MealPlanModel {
  final String id;
  final String kitchenId;
  final String kitchenName;
  final String kitchenAddress;
  final String name;
  final String description;
  final List<String> inclusions;
  final bool isVeg;
  final String imageUrl;
  final bool isActive;
  final double? startingPrice;
  final double? distanceKm;
  final List<PlanPriceModel> prices;
  final List<PlanSlotModel> slots;

  MealPlanModel({
    required this.id,
    required this.kitchenId,
    required this.kitchenName,
    required this.kitchenAddress,
    required this.name,
    required this.description,
    required this.inclusions,
    required this.isVeg,
    required this.imageUrl,
    required this.isActive,
    required this.startingPrice,
    required this.distanceKm,
    required this.prices,
    required this.slots,
  });

  List<PlanPriceModel> get activePrices =>
      prices.where((p) => p.isActive).toList();

  List<PlanSlotModel> get activeSlots =>
      slots.where((s) => s.isActive).toList();

  int get weeklyMeals => activeSlots.length;

  /// "2.4 km away", or null when the address has no coordinates and the
  /// backend could not compute a distance. Never faked.
  String? get distanceLabel => distanceKm == null ? null : '${distanceKm!.toStringAsFixed(1)} km away';

  /// Weekly preview line, e.g. "Dinner daily · 7 meals/week". Null when the
  /// kitchen has published no slots — an unconfigured plan shows no preview
  /// rather than an invented one.
  String? get weeklyPreview {
    final active = activeSlots;
    if (active.isEmpty) return null;
    final types = <String>[];
    for (final slot in active) {
      final label = slot.mealTypeLabel;
      if (label.isNotEmpty && !types.contains(label)) types.add(label);
    }
    types.sort();
    final when = types.isEmpty
        ? '${active.length} meals/week'
        : '${types.join('/')} · ${active.length} meals/week';
    return when;
  }

  PlanPriceModel? priceFor(String cadence) {
    for (final p in activePrices) {
      if (p.cadence == cadence) return p;
    }
    return null;
  }

  factory MealPlanModel.fromMap(Map<String, dynamic> map) {
    List<String> readStrings(String key) {
      final raw = map[key];
      if (raw is! List) return const [];
      return raw.map((e) => '$e').toList();
    }

    return MealPlanModel(
      id: '${map['id'] ?? ''}',
      kitchenId: '${map['kitchen'] ?? ''}',
      kitchenName: '${map['kitchenName'] ?? ''}',
      kitchenAddress: '${map['kitchenAddress'] ?? ''}',
      name: '${map['name'] ?? ''}',
      description: '${map['description'] ?? ''}',
      inclusions: readStrings('inclusions'),
      isVeg: map['isVeg'] ?? true,
      imageUrl: '${map['imageUrl'] ?? ''}',
      isActive: map['isActive'] ?? true,
      startingPrice: map['startingPrice'] == null
          ? null
          : double.tryParse('${map['startingPrice']}'),
      distanceKm:
          map['distanceKm'] == null ? null : double.tryParse('${map['distanceKm']}'),
      prices: ((map['prices'] as List<dynamic>?) ?? const [])
          .map((e) => PlanPriceModel.fromMap(e as Map<String, dynamic>))
          .toList(),
      slots: ((map['slots'] as List<dynamic>?) ?? const [])
          .map((e) => PlanSlotModel.fromMap(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// The `subscriptions/quote/` response. This endpoint returns a plain dict,
/// not a serializer, so its keys stay snake_case.
class SubscriptionQuoteModel {
  final double planPrice;
  final String cadence;
  final int durationDays;
  final int mealsPerPeriod;
  final double deliveryFeePerKm;
  final double? distanceKm;
  final double deliveryFeeTotal;
  final double periodTotal;
  final String currency;

  SubscriptionQuoteModel({
    required this.planPrice,
    required this.cadence,
    required this.durationDays,
    required this.mealsPerPeriod,
    required this.deliveryFeePerKm,
    required this.distanceKm,
    required this.deliveryFeeTotal,
    required this.periodTotal,
    required this.currency,
  });

  String get currencySymbol => currency == 'INR' ? '₹' : '$currency ';

  factory SubscriptionQuoteModel.fromMap(Map<String, dynamic> map) {
    double money(String key) => double.tryParse('${map[key] ?? '0'}') ?? 0.0;

    return SubscriptionQuoteModel(
      planPrice: money('plan_price'),
      cadence: '${map['cadence'] ?? ''}',
      durationDays: int.tryParse('${map['duration_days'] ?? 0}') ?? 0,
      mealsPerPeriod: int.tryParse('${map['meals_per_period'] ?? 0}') ?? 0,
      deliveryFeePerKm: money('delivery_fee_per_km'),
      distanceKm:
          map['distance_km'] == null ? null : double.tryParse('${map['distance_km']}'),
      deliveryFeeTotal: money('delivery_fee_total'),
      periodTotal: money('period_total'),
      currency: '${map['currency'] ?? 'INR'}',
    );
  }
}

/// One scheduled delivery inside a subscription.
class SubscriptionMealModel {
  final String id;
  final String mealType;
  final String title;
  final DateTime? date;
  final String status; // scheduled | ordered | skipped | delivered
  final String skipReason;

  SubscriptionMealModel({
    required this.id,
    required this.mealType,
    required this.title,
    required this.date,
    required this.status,
    required this.skipReason,
  });

  factory SubscriptionMealModel.fromMap(Map<String, dynamic> map) {
    DateTime? date;
    final raw = map['date'];
    if (raw != null && '$raw'.isNotEmpty) date = DateTime.tryParse('$raw');
    return SubscriptionMealModel(
      id: '${map['id'] ?? ''}',
      mealType: '${map['mealType'] ?? ''}',
      title: '${map['title'] ?? ''}',
      date: date,
      status: '${map['status'] ?? 'scheduled'}',
      skipReason: '${map['skipReason'] ?? ''}',
    );
  }
}

/// A row from `subscriptions/mine/`.
class SubscriptionModel {
  final String id;
  final String kitchenId;
  final String kitchenName;
  final String planId;
  final String planName;
  final String planDescription;
  final String planImageUrl;
  final String cadence;
  final String addressId;
  final String addressText;
  final DateTime? startDate;
  final DateTime? endDate;
  final String status; // active | paused | cancelled | expired
  final double pricePaid;
  final String paymentId;
  final List<SubscriptionMealModel> meals;

  SubscriptionModel({
    required this.id,
    required this.kitchenId,
    required this.kitchenName,
    required this.planId,
    required this.planName,
    required this.planDescription,
    required this.planImageUrl,
    required this.cadence,
    required this.addressId,
    required this.addressText,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.pricePaid,
    required this.paymentId,
    required this.meals,
  });

  bool get isActive => status == 'active';
  bool get isPaused => status == 'paused';
  bool get isCancelled =>
      status == 'cancelled' || status == 'expired';

  String get cadenceLabel {
    switch (cadence) {
      case 'week':
        return 'Weekly';
      case 'month':
        return 'Monthly';
      case 'year':
        return 'Yearly';
      default:
        return cadence;
    }
  }

  /// Only meals the customer can still act on: in the future and not yet
  /// ordered, skipped or delivered.
  List<SubscriptionMealModel> get skippableMeals {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return meals
        .where((m) =>
            m.date != null &&
            m.date!.isAfter(today) &&
            m.status == 'scheduled')
        .toList()
      ..sort((a, b) => a.date!.compareTo(b.date!));
  }

  factory SubscriptionModel.fromMap(Map<String, dynamic> map) {
    DateTime? date(String key) {
      final raw = map[key];
      if (raw == null || '$raw'.isEmpty) return null;
      return DateTime.tryParse('$raw');
    }

    return SubscriptionModel(
      id: '${map['id'] ?? ''}',
      kitchenId: '${map['kitchen'] ?? ''}',
      kitchenName: '${map['kitchenName'] ?? ''}',
      planId: '${map['plan'] ?? ''}',
      planName: '${map['planName'] ?? ''}',
      planDescription: '${map['planDescription'] ?? ''}',
      planImageUrl: '${map['planImageUrl'] ?? ''}',
      cadence: '${map['cadence'] ?? ''}',
      addressId: '${map['address'] ?? ''}',
      addressText: '${map['addressText'] ?? ''}',
      startDate: date('startDate'),
      endDate: date('endDate'),
      status: '${map['status'] ?? ''}',
      pricePaid: double.tryParse('${map['pricePaid'] ?? '0'}') ?? 0.0,
      paymentId: '${map['paymentId'] ?? ''}',
      meals: ((map['meals'] as List<dynamic>?) ?? const [])
          .map((e) => SubscriptionMealModel.fromMap(e as Map<String, dynamic>))
          .toList(),
    );
  }
}