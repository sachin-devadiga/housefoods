/// Represents a parsed voice command from the user.
///
/// Designed to be extensible — future versions can add fields
/// for size, variant, customization, notes, etc.
class MealVoiceCommand {
  final MealVoiceIntent intent;
  final List<MealVoiceItem> items;
  final String? restaurant;
  final String? bakery;
  final String rawText;
  final DateTime parsedAt;

  MealVoiceCommand({
    required this.intent,
    required this.items,
    this.restaurant,
    this.bakery,
    required this.rawText,
    DateTime? parsedAt,
  }) : parsedAt = parsedAt ?? DateTime.now();

  /// Single-item convenience constructor
  factory MealVoiceCommand.single({
    required MealVoiceIntent intent,
    required String itemName,
    int quantity = 1,
    String? restaurant,
    String? bakery,
    required String rawText,
  }) {
    return MealVoiceCommand(
      intent: intent,
      items: [MealVoiceItem(itemName: itemName, quantity: quantity)],
      restaurant: restaurant,
      bakery: bakery,
      rawText: rawText,
    );
  }

  /// Confirmation response command
  factory MealVoiceCommand.confirmation({
    required bool confirmed,
    required String rawText,
  }) {
    return MealVoiceCommand(
      intent: confirmed ? MealVoiceIntent.confirm : MealVoiceIntent.cancel,
      items: [],
      rawText: rawText,
    );
  }

  bool get isAdd => intent == MealVoiceIntent.add;
  bool get isRemove => intent == MealVoiceIntent.remove;
  bool get isConfirm => intent == MealVoiceIntent.confirm;
  bool get isCancel => intent == MealVoiceIntent.cancel;
  bool get hasMultipleItems => items.length > 1;
  bool get hasRestaurant => restaurant != null && restaurant!.isNotEmpty;
  bool get hasBakery => bakery != null && bakery!.isNotEmpty;
  String? get businessName => hasBakery ? bakery : restaurant;

  @override
  String toString() =>
      'MealVoiceCommand(intent: $intent, items: $items, restaurant: $restaurant, bakery: $bakery)';
}

/// A single item within a voice command.
class MealVoiceItem {
  final String itemName;
  final int quantity;
  final String? size;
  final String? variant;
  final String? customization;
  final String? notes;

  const MealVoiceItem({
    required this.itemName,
    this.quantity = 1,
    this.size,
    this.variant,
    this.customization,
    this.notes,
  });

  MealVoiceItem copyWith({
    String? itemName,
    int? quantity,
    String? size,
    String? variant,
    String? customization,
    String? notes,
  }) {
    return MealVoiceItem(
      itemName: itemName ?? this.itemName,
      quantity: quantity ?? this.quantity,
      size: size ?? this.size,
      variant: variant ?? this.variant,
      customization: customization ?? this.customization,
      notes: notes ?? this.notes,
    );
  }

  @override
  String toString() => 'MealVoiceItem($quantity x $itemName)';
}

/// User intent extracted from voice command.
enum MealVoiceIntent {
  add,
  remove,
  cancel,
  confirm,
  unknown,
}

/// Parsed confirmation response.
enum MealVoiceConfirmation {
  yes,
  no,
  timeout,
  unknown,
}

/// Configuration for yes/no confirmation matching.
class ConfirmationConfig {
  static const Set<String> yesWords = {
    'yes', 'yeah', 'yep', 'sure', 'confirm', 'go ahead',
    'do it', 'okay', 'ok', 'add it', 'add', 'yup',
    'absolutely', 'definitely', 'please', 'sounds good',
  };

  static const Set<String> noWords = {
    'no', 'nope', 'cancel', 'don\'t', 'not now', 'never mind',
    'nah', 'naw', 'skip', 'change', 'wrong', 'stop',
  };

  static MealVoiceConfirmation parse(String text) {
    final lower = text.toLowerCase().trim();
    for (final word in yesWords) {
      if (lower == word || lower.startsWith(word)) {
        return MealVoiceConfirmation.yes;
      }
    }
    for (final word in noWords) {
      if (lower == word || lower.startsWith(word)) {
        return MealVoiceConfirmation.no;
      }
    }
    return MealVoiceConfirmation.unknown;
  }
}
