import 'meal_voice_command.dart';

/// Abstract interface for parsing voice transcripts into structured commands.
///
/// Current implementation: [RegexMealVoiceCommandParser]
/// Future: Gemini/LLM-based implementation can be swapped in without
/// changing the controller or order handler.
abstract class MealVoiceCommandParser {
  /// Parse a raw voice transcript into a structured command.
  MealVoiceCommand parse(String transcript);

  /// Parse a confirmation response (yes/no).
  MealVoiceConfirmation parseConfirmation(String transcript);

  /// Human-readable name of this parser implementation.
  String get parserName;
}

/// Regex/keyword-based command parser for food ordering.
///
/// Handles natural language commands like:
/// - "Order one chicken biryani from Palace"
/// - "Add two burgers and one coke"
/// - "Remove the coke"
/// - "I want a chocolate cake"
class RegexMealVoiceCommandParser implements MealVoiceCommandParser {
  @override
  String get parserName => 'RegexParser';

  // Intent detection keywords
  static const Map<MealVoiceIntent, List<String>> _intentKeywords = {
    MealVoiceIntent.add: [
      'order', 'get me', 'get', 'i want', 'i\'d like', 'i would like',
      'add', 'buy', 'bring', 'give me', 'have', 'grab',
      'can i get', 'let me get', 'i\'ll have', 'i\'ll take',
      'send me', 'fetch',
    ],
    MealVoiceIntent.remove: [
      'remove', 'delete', 'cancel', 'take out', 'drop',
      'take off', 'get rid of', 'no more',
    ],
  };

  // Quantity word mapping
  static const Map<String, int> _quantityWords = {
    'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5,
    'six': 6, 'seven': 7, 'eight': 8, 'nine': 9, 'ten': 10,
    'a': 1, 'an': 1, 'single': 1, 'double': 2, 'triple': 3,
  };

  // Restaurant/bakery prefix patterns
  static final List<RegExp> _businessPatterns = [
    RegExp(r'from\s+(.+?)(?:\s*$)', caseSensitive: false),
    RegExp(r'at\s+(.+?)(?:\s*$)', caseSensitive: false),
    RegExp(r'from\s+(.+?)(?:\s+and\s+|$)', caseSensitive: false),
  ];

  // Multi-item separator
  static final RegExp _multiItemSeparator = RegExp(
    r'\s+and\s+|\s*,\s*|\s+also\s+|\s+plus\s+',
    caseSensitive: false,
  );

  @override
  MealVoiceCommand parse(String transcript) {
    final raw = transcript.trim();
    if (raw.isEmpty) {
      return MealVoiceCommand(
        intent: MealVoiceIntent.unknown,
        items: [],
        rawText: raw,
      );
    }

    final lower = raw.toLowerCase();

    // 1. Detect intent
    final intent = _detectIntent(lower);

    // 2. Extract business name (restaurant/bakery)
    final business = _extractBusiness(lower);

    // 3. Extract items
    final items = _extractItems(lower, intent);

    return MealVoiceCommand(
      intent: intent,
      items: items,
      restaurant: business,
      bakery: business, // Same field — backend determines type
      rawText: raw,
    );
  }

  @override
  MealVoiceConfirmation parseConfirmation(String transcript) {
    return ConfirmationConfig.parse(transcript);
  }

  MealVoiceIntent _detectIntent(String lower) {
    for (final entry in _intentKeywords.entries) {
      for (final keyword in entry.value) {
        if (lower.startsWith(keyword) || lower.contains(' $keyword ') || lower.contains(' $keyword')) {
          return entry.key;
        }
      }
    }
    // Default to ADD if food-like words are present
    if (_containsFoodWord(lower)) {
      return MealVoiceIntent.add;
    }
    return MealVoiceIntent.unknown;
  }

  String? _extractBusiness(String lower) {
    for (final pattern in _businessPatterns) {
      final match = pattern.firstMatch(lower);
      if (match != null) {
        final name = match.group(1)?.trim();
        if (name != null && name.isNotEmpty) {
          // Clean up common trailing words
          return name
              .replaceAll(RegExp(r'\s+(and|please|thanks|thank you)$'), '')
              .trim();
        }
      }
    }
    return null;
  }

  List<MealVoiceItem> _extractItems(String lower, MealVoiceIntent intent) {
    // Remove intent keywords from the beginning
    var text = _stripIntent(lower);

    // Remove business reference
    text = text.replaceAll(RegExp(r'\s+from\s+.+$'), '');
    text = text.replaceAll(RegExp(r'\s+at\s+.+$'), '');

    // Split multi-item commands
    final segments = text.split(_multiItemSeparator);
    final items = <MealVoiceItem>[];

    for (final segment in segments) {
      final trimmed = segment.trim();
      if (trimmed.isEmpty) continue;

      final item = _parseSingleItem(trimmed);
      if (item != null) {
        items.add(item);
      }
    }

    // If no items parsed, try the whole text as one item
    if (items.isEmpty && text.trim().isNotEmpty) {
      final item = _parseSingleItem(text.trim());
      if (item != null) {
        items.add(item);
      }
    }

    return items;
  }

  MealVoiceItem? _parseSingleItem(String segment) {
    final lower = segment.toLowerCase().trim();

    // Try to extract quantity
    int quantity = 1;
    String itemName = lower;

    // Check for digit quantity: "2 burgers", "1 biryani"
    final digitMatch = RegExp(r'^(\d+)\s+(.+)$').firstMatch(lower);
    if (digitMatch != null) {
      quantity = int.parse(digitMatch.group(1)!);
      itemName = digitMatch.group(2)!;
    } else {
      // Check for word quantity: "two burgers", "one biryani"
      for (final entry in _quantityWords.entries) {
        if (lower.startsWith('${entry.key} ') || lower == entry.key) {
          quantity = entry.value;
          itemName = lower.substring(entry.key.length).trim();
          break;
        }
      }
    }

    // Remove articles and filler words
    itemName = itemName
        .replaceAll(RegExp(r'^the\s+'), '')
        .replaceAll(RegExp(r'^some\s+'), '')
        .replaceAll(RegExp(r'^a\s+'), '')
        .replaceAll(RegExp(r'^an\s+'), '')
        .replaceAll(RegExp(r'\s+please$'), '')
        .replaceAll(RegExp(r'\s+thanks$'), '')
        .trim();

    if (itemName.isEmpty) return null;

    // Clean up common STT artifacts
    itemName = _cleanItemName(itemName);

    return MealVoiceItem(itemName: itemName, quantity: quantity);
  }

  /// FIX #7: Only strip intent from the beginning of text, never mid-sentence.
  /// This prevents corrupting item names like "noodles" or "a burger".
  String _stripIntent(String lower) {
    for (final keywords in _intentKeywords.values) {
      for (final keyword in keywords) {
        // FIX #7: Only strip from the start — never remove mid-sentence keywords
        if (lower.startsWith(keyword)) {
          final stripped = lower.substring(keyword.length).trim();
          if (stripped.isNotEmpty) return stripped;
        }
      }
    }
    return lower;
  }

  bool _containsFoodWord(String text) {
    final foodIndicators = [
      'biryani', 'burger', 'pizza', 'pasta', 'dosa', 'idli',
      'cake', 'coke', 'cola', 'water', 'juice', 'coffee', 'tea',
      'rice', 'noodles', 'fried rice', 'momos', 'samosa',
      'chicken', 'paneer', 'fish', 'mutton', 'veg', 'non-veg',
      'sandwich', 'wrap', 'roll', 'shawarma', 'tikka',
      'bread', 'naan', 'roti', 'paratha', 'butter',
      'ice cream', 'dessert', 'brownie', 'pastry',
    ];
    return foodIndicators.any((food) => text.contains(food));
  }

  String _cleanItemName(String name) {
    // Known singular/plural mappings
    final singularMap = {
      'biriyani': 'biryani',
      'biriani': 'biryani',
      'biryanis': 'biryani',
      'burgers': 'burger',
      'masala dosas': 'masala dosa',
      'black forest': 'black forest cake',
      'black forest cake': 'black forest cake',
      'pizzas': 'pizza',
      'pastas': 'pasta',
      'momos': 'momo',
      'samosas': 'samosa',
      'cokes': 'coke',
    };

    // Try exact match first
    for (final entry in singularMap.entries) {
      if (name == entry.key) {
        return entry.value;
      }
    }

    // Try suffix replacement (e.g., "chicken biryanis" → "chicken biryani")
    for (final entry in singularMap.entries) {
      if (name.endsWith(' ${entry.key}')) {
        final prefix = name.substring(0, name.length - entry.key.length);
        return '$prefix${entry.value}';
      }
    }

    // Handle trailing "s" plural → singular
    if (name.length > 4 &&
        name.endsWith('s') &&
        !name.endsWith('ss') &&
        !name.endsWith('us') &&
        !name.endsWith('is') &&
        !name.endsWith('es')) {
      return name.substring(0, name.length - 1);
    }

    return name;
  }
}
