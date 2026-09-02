import 'package:flutter_test/flutter_test.dart';
import 'package:mealin/meal_voice/meal_voice_command.dart';
import 'package:mealin/meal_voice/meal_voice_command_parser.dart';

void main() {
  group('RegexMealVoiceCommandParser', () {
    late RegexMealVoiceCommandParser parser;

    setUp(() {
      parser = RegexMealVoiceCommandParser();
    });

    group('Single item commands', () {
      test('add one chicken biryani', () {
        final cmd = parser.parse('add one chicken biryani');
        expect(cmd.intent, MealVoiceIntent.add);
        expect(cmd.items.length, 1);
        expect(cmd.items.first.itemName, 'chicken biryani');
        expect(cmd.items.first.quantity, 1);
      });

      test('order two chicken biryanis', () {
        final cmd = parser.parse('order two chicken biryanis');
        expect(cmd.intent, MealVoiceIntent.add);
        expect(cmd.items.length, 1);
        expect(cmd.items.first.itemName, 'chicken biryani'); // plural cleaned
        expect(cmd.items.first.quantity, 2);
      });

      test('get me a masala dosa', () {
        final cmd = parser.parse('get me a masala dosa');
        expect(cmd.intent, MealVoiceIntent.add);
        expect(cmd.items.length, 1);
        expect(cmd.items.first.itemName, 'masala dosa');
        expect(cmd.items.first.quantity, 1);
      });

      test('i want a chocolate cake', () {
        final cmd = parser.parse('i want a chocolate cake');
        expect(cmd.intent, MealVoiceIntent.add);
        expect(cmd.items.length, 1);
        expect(cmd.items.first.itemName, 'chocolate cake');
        expect(cmd.items.first.quantity, 1);
      });

      test('quantity 3 with digit', () {
        final cmd = parser.parse('add 3 burgers');
        expect(cmd.intent, MealVoiceIntent.add);
        expect(cmd.items.first.quantity, 3);
        expect(cmd.items.first.itemName, 'burger');
      });
    });

    group('Restaurant extraction', () {
      test('order one chicken biryani from palace', () {
        final cmd = parser.parse('order one chicken biryani from palace');
        expect(cmd.restaurant, 'palace');
        expect(cmd.items.first.itemName, 'chicken biryani');
      });

      test('add two burgers from mcdonalds', () {
        final cmd = parser.parse('add two burgers from mcdonalds');
        expect(cmd.restaurant, 'mcdonalds');
        expect(cmd.items.length, 1);
      });

      test('get me a cake from cake palace', () {
        final cmd = parser.parse('get me a cake from cake palace');
        expect(cmd.restaurant, 'cake palace');
      });
    });

    group('Multi-item commands', () {
      test('two burgers and one coke', () {
        final cmd = parser.parse('add two burgers and one coke');
        expect(cmd.intent, MealVoiceIntent.add);
        expect(cmd.items.length, 2);
        expect(cmd.items[0].itemName, 'burger');
        expect(cmd.items[0].quantity, 2);
        expect(cmd.items[1].itemName, 'coke');
        expect(cmd.items[1].quantity, 1);
      });

      test('one masala dosa and one coffee', () {
        final cmd = parser.parse('add one masala dosa and one coffee');
        expect(cmd.items.length, 2);
        expect(cmd.items[0].itemName, 'masala dosa');
        expect(cmd.items[0].quantity, 1);
        expect(cmd.items[1].itemName, 'coffee');
        expect(cmd.items[1].quantity, 1);
      });

      test('multi-item with restaurant', () {
        final cmd = parser.parse('order two burgers and one coke from palace');
        expect(cmd.restaurant, 'palace');
        expect(cmd.items.length, 2);
      });
    });

    group('Remove commands', () {
      test('remove the coke', () {
        final cmd = parser.parse('remove the coke');
        expect(cmd.intent, MealVoiceIntent.remove);
        expect(cmd.items.length, 1);
        expect(cmd.items.first.itemName, 'coke');
      });

      test('delete the burger', () {
        final cmd = parser.parse('delete the burger');
        expect(cmd.intent, MealVoiceIntent.remove);
        expect(cmd.items.first.itemName, 'burger');
      });
    });

    group('Unknown commands', () {
      test('empty string', () {
        final cmd = parser.parse('');
        expect(cmd.intent, MealVoiceIntent.unknown);
        expect(cmd.items, isEmpty);
      });

      test('gibberish', () {
        final cmd = parser.parse('asjkdh askjd');
        expect(cmd.intent, MealVoiceIntent.unknown);
      });
    });

    group('Food word detection', () {
      test('implicit add intent when food word present', () {
        final cmd = parser.parse('one chicken biryani');
        expect(cmd.intent, MealVoiceIntent.add);
      });
    });

    group('Parser name', () {
      test('returns RegexParser', () {
        expect(parser.parserName, 'RegexParser');
      });
    });
  });

  group('ConfirmationConfig', () {
    test('yes variants', () {
      expect(ConfirmationConfig.parse('yes'), MealVoiceConfirmation.yes);
      expect(ConfirmationConfig.parse('yeah'), MealVoiceConfirmation.yes);
      expect(ConfirmationConfig.parse('yep'), MealVoiceConfirmation.yes);
      expect(ConfirmationConfig.parse('sure'), MealVoiceConfirmation.yes);
      expect(ConfirmationConfig.parse('confirm'), MealVoiceConfirmation.yes);
      expect(ConfirmationConfig.parse('go ahead'), MealVoiceConfirmation.yes);
      expect(ConfirmationConfig.parse('do it'), MealVoiceConfirmation.yes);
      expect(ConfirmationConfig.parse('okay'), MealVoiceConfirmation.yes);
      expect(ConfirmationConfig.parse('add it'), MealVoiceConfirmation.yes);
      expect(ConfirmationConfig.parse('sounds good'), MealVoiceConfirmation.yes);
    });

    test('no variants', () {
      expect(ConfirmationConfig.parse('no'), MealVoiceConfirmation.no);
      expect(ConfirmationConfig.parse('nope'), MealVoiceConfirmation.no);
      expect(ConfirmationConfig.parse('cancel'), MealVoiceConfirmation.no);
      expect(ConfirmationConfig.parse('not now'), MealVoiceConfirmation.no);
      expect(ConfirmationConfig.parse('skip'), MealVoiceConfirmation.no);
      expect(ConfirmationConfig.parse('change'), MealVoiceConfirmation.no);
    });

    test('unknown responses', () {
      expect(ConfirmationConfig.parse('maybe'), MealVoiceConfirmation.unknown);
      expect(ConfirmationConfig.parse('idk'), MealVoiceConfirmation.unknown);
      expect(ConfirmationConfig.parse('what'), MealVoiceConfirmation.unknown);
    });
  });
}
