import 'package:flutter_test/flutter_test.dart';
import 'package:mealin/meal_voice/meal_voice_command.dart';
import 'package:mealin/meal_voice/meal_voice_command_parser.dart';
import 'package:mealin/meal_voice/meal_voice_gemini_parser.dart';
import 'package:mealin/meal_voice/meal_voice_parser_factory.dart';

void main() {
  group('MealVoiceParserFactory', () {
    setUp(() {
      MealVoiceParserFactory.reset();
    });

    test('returns regex parser by default', () {
      final parser = MealVoiceParserFactory.getParser();
      expect(parser, isA<RegexMealVoiceCommandParser>());
    });

    test('getRegexParser returns RegexMealVoiceCommandParser', () {
      final parser = MealVoiceParserFactory.getRegexParser();
      expect(parser, isA<RegexMealVoiceCommandParser>());
    });

    test('getGeminiParser returns GeminiMealVoiceCommandParser', () {
      final parser = MealVoiceParserFactory.getGeminiParser();
      expect(parser, isA<GeminiMealVoiceCommandParser>());
    });

    test('currentParserName is Regex when Gemini not initialized', () {
      expect(MealVoiceParserFactory.currentParserName, 'Regex');
    });

    test('isGeminiAvailable is false by default', () {
      expect(MealVoiceParserFactory.isGeminiAvailable, false);
    });
  });

  group('GeminiMealVoiceCommandParser', () {
    late GeminiMealVoiceCommandParser parser;

    setUp(() {
      parser = GeminiMealVoiceCommandParser();
    });

    test('parserName is GeminiParser', () {
      expect(parser.parserName, 'GeminiParser');
    });

    test('isAvailable is false without API key', () {
      expect(parser.isAvailable, false);
    });

    test('parse falls back to regex when Gemini not available', () {
      // Without initialization, should use regex fallback
      final command = parser.parse('add one chicken biryani');
      expect(command.intent, MealVoiceIntent.add);
      expect(command.items.length, 1);
      expect(command.items.first.itemName, 'chicken biryani');
    });

    test('parseConfirmation returns yes for "yes"', () {
      final result = parser.parseConfirmation('yes');
      expect(result, MealVoiceConfirmation.yes);
    });

    test('parseConfirmation returns no for "no"', () {
      final result = parser.parseConfirmation('no');
      expect(result, MealVoiceConfirmation.no);
    });

    test('parseConfirmation returns yes for "sure"', () {
      final result = parser.parseConfirmation('sure');
      expect(result, MealVoiceConfirmation.yes);
    });

    test('parseConfirmation returns no for "cancel"', () {
      final result = parser.parseConfirmation('cancel');
      expect(result, MealVoiceConfirmation.no);
    });

    group('parseAsync fallback', () {
      test('returns regex result when Gemini not available', () async {
        final command = await parser.parseAsync('add two burgers');
        expect(command.intent, MealVoiceIntent.add);
        expect(command.items.length, 1);
        expect(command.items.first.quantity, 2);
      });

      test('returns regex result for remove command', () async {
        final command = await parser.parseAsync('remove the coke');
        expect(command.intent, MealVoiceIntent.remove);
      });

      test('returns regex result for multi-item command', () async {
        final command = await parser.parseAsync('add one biryani and one coke');
        expect(command.items.length, 2);
      });
    });
  });

  group('GeminiMealVoiceCommandParser JSON parsing', () {
    late GeminiMealVoiceCommandParser parser;

    setUp(() {
      parser = GeminiMealVoiceCommandParser();
    });

    test('parseAsync handles empty transcript gracefully', () async {
      final command = await parser.parseAsync('');
      // Empty string should be handled by regex fallback
      expect(command.intent, MealVoiceIntent.unknown);
    });

    test('parseAsync handles gibberish gracefully', () async {
      final command = await parser.parseAsync('askjdh askjd');
      // Gibberish should be handled by regex fallback
      expect(command.intent, MealVoiceIntent.unknown);
    });
  });

  group('RegexMealVoiceCommandParser (fallback verification)', () {
    late RegexMealVoiceCommandParser parser;

    setUp(() {
      parser = RegexMealVoiceCommandParser();
    });

    test('single item parsing works', () {
      final cmd = parser.parse('add one chicken biryani');
      expect(cmd.intent, MealVoiceIntent.add);
      expect(cmd.items.length, 1);
      expect(cmd.items.first.itemName, 'chicken biryani');
    });

    test('multi-item parsing works', () {
      final cmd = parser.parse('add two burgers and one coke');
      expect(cmd.items.length, 2);
    });

    test('restaurant extraction works', () {
      final cmd = parser.parse('add one biryani from Palace');
      expect(cmd.restaurant, 'palace'); // parser lowercases
    });

    test('remove intent works', () {
      final cmd = parser.parse('remove the coke');
      expect(cmd.intent, MealVoiceIntent.remove);
    });

    test('confirmation parsing works', () {
      expect(parser.parseConfirmation('yes'), MealVoiceConfirmation.yes);
      expect(parser.parseConfirmation('no'), MealVoiceConfirmation.no);
      expect(parser.parseConfirmation('confirm'), MealVoiceConfirmation.yes);
      expect(parser.parseConfirmation('cancel'), MealVoiceConfirmation.no);
    });

    test('unknown intent for gibberish', () {
      final cmd = parser.parse('asjkdh askjd');
      expect(cmd.intent, MealVoiceIntent.unknown);
    });
  });
}
