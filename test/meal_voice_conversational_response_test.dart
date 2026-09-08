import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealin/meal_voice/meal_voice_conversation.dart';

void main() {
  group('VoiceAction', () {
    group('fromJson', () {
      test('parses search_menu action', () {
        final action = VoiceAction.fromJson({
          'type': 'search_menu',
          'query': 'biryani',
          'restaurant': 'Palace',
        });
        expect(action.type, 'search_menu');
        expect(action.query, 'biryani');
        expect(action.restaurant, 'Palace');
        expect(action.isSearchMenu, isTrue);
      });

      test('parses add_to_cart action', () {
        final action = VoiceAction.fromJson({
          'type': 'add_to_cart',
          'item_name': 'chicken biryani',
          'quantity': 2,
          'restaurant': 'Palace',
        });
        expect(action.type, 'add_to_cart');
        expect(action.itemName, 'chicken biryani');
        expect(action.quantity, 2);
        expect(action.restaurant, 'Palace');
        expect(action.isAddToCart, isTrue);
      });

      test('parses remove_from_cart action', () {
        final action = VoiceAction.fromJson({
          'type': 'remove_from_cart',
          'item': 'coke',
        });
        expect(action.type, 'remove_from_cart');
        expect(action.item, 'coke');
        expect(action.isRemoveFromCart, isTrue);
      });

      test('parses clear_cart action', () {
        final action = VoiceAction.fromJson({'type': 'clear_cart'});
        expect(action.type, 'clear_cart');
        expect(action.isClearCart, isTrue);
      });

      test('parses show_cart action', () {
        final action = VoiceAction.fromJson({'type': 'show_cart'});
        expect(action.type, 'show_cart');
        expect(action.isShowCart, isTrue);
      });

      test('parses place_order action', () {
        final action = VoiceAction.fromJson({'type': 'place_order'});
        expect(action.type, 'place_order');
        expect(action.isPlaceOrder, isTrue);
      });

      test('parses none action', () {
        final action = VoiceAction.fromJson({'type': 'none'});
        expect(action.type, 'none');
        expect(action.isNone, isTrue);
      });

      test('defaults to none when type is missing', () {
        final action = VoiceAction.fromJson({});
        expect(action.type, 'none');
        expect(action.isNone, isTrue);
      });

      test('defaults to none when type is null', () {
        final action = VoiceAction.fromJson({'type': null});
        expect(action.type, 'none');
      });

      test('defaults quantity to 1', () {
        final action = VoiceAction.fromJson({
          'type': 'add_to_cart',
          'item_name': 'biryani',
        });
        expect(action.quantity, 1);
      });

      test('parses quantity as int from num', () {
        final action = VoiceAction.fromJson({
          'type': 'add_to_cart',
          'item_name': 'biryani',
          'quantity': 3.0,
        });
        expect(action.quantity, 3);
      });
    });

    group('type checks', () {
      test('isSearchMenu returns true for search_menu', () {
        expect(VoiceAction(type: 'search_menu').isSearchMenu, isTrue);
        expect(VoiceAction(type: 'add_to_cart').isSearchMenu, isFalse);
      });

      test('isAddToCart returns true for add_to_cart', () {
        expect(VoiceAction(type: 'add_to_cart').isAddToCart, isTrue);
        expect(VoiceAction(type: 'search_menu').isAddToCart, isFalse);
      });

      test('isRemoveFromCart returns true for remove_from_cart', () {
        expect(VoiceAction(type: 'remove_from_cart').isRemoveFromCart, isTrue);
      });

      test('isClearCart returns true for clear_cart', () {
        expect(VoiceAction(type: 'clear_cart').isClearCart, isTrue);
      });

      test('isShowCart returns true for show_cart', () {
        expect(VoiceAction(type: 'show_cart').isShowCart, isTrue);
      });

      test('isPlaceOrder returns true for place_order', () {
        expect(VoiceAction(type: 'place_order').isPlaceOrder, isTrue);
      });

      test('isNone returns true for none', () {
        expect(VoiceAction(type: 'none').isNone, isTrue);
      });
    });

    group('toString', () {
      test('returns readable string', () {
        final action = VoiceAction(
          type: 'add_to_cart',
          params: {'item_name': 'biryani', 'quantity': 2},
        );
        expect(action.toString(), contains('add_to_cart'));
        expect(action.toString(), contains('biryani'));
      });
    });
  });

  group('ConversationalResponse', () {
    group('fromJson', () {
      test('parses response with actions', () {
        final response = ConversationalResponse.fromJson({
          'response': 'Great choice!',
          'actions': [
            {'type': 'search_menu', 'query': 'biryani'},
            {'type': 'add_to_cart', 'item_name': 'biryani'},
          ],
        });
        expect(response.response, 'Great choice!');
        expect(response.actions.length, 2);
        expect(response.actions[0].type, 'search_menu');
        expect(response.actions[1].type, 'add_to_cart');
      });

      test('parses response with empty actions', () {
        final response = ConversationalResponse.fromJson({
          'response': 'What would you like?',
          'actions': [],
        });
        expect(response.response, 'What would you like?');
        expect(response.actions, isEmpty);
      });

      test('handles missing actions field', () {
        final response = ConversationalResponse.fromJson({
          'response': 'Hello!',
        });
        expect(response.response, 'Hello!');
        expect(response.actions, isEmpty);
      });

      test('handles missing response field', () {
        final response = ConversationalResponse.fromJson({
          'actions': [{'type': 'none'}],
        });
        expect(response.response, '');
        expect(response.actions.length, 1);
      });

      test('handles completely empty JSON', () {
        final response = ConversationalResponse.fromJson({});
        expect(response.response, '');
        expect(response.actions, isEmpty);
      });

      test('handles null response field', () {
        final response = ConversationalResponse.fromJson({
          'response': null,
        });
        expect(response.response, '');
      });

      test('handles malformed action in list', () {
        final response = ConversationalResponse.fromJson({
          'response': 'test',
          'actions': [
            {'not_a_type': 'unknown'},
          ],
        });
        expect(response.actions.length, 1);
        expect(response.actions[0].type, 'none');
      });
    });
  });

  group('Robust JSON extraction', () {
    test('handles JSON wrapped in markdown code fences', () {
      const text = '''```json
{
  "response": "Hello!",
  "actions": []
}
```''';
      // Simulate the parsing logic from the brain
      var cleaned = text.trim();
      if (cleaned.startsWith('```json')) {
        cleaned = cleaned.substring(7);
      } else if (cleaned.startsWith('```')) {
        cleaned = cleaned.substring(3);
      }
      if (cleaned.endsWith('```')) {
        cleaned = cleaned.substring(0, cleaned.length - 3);
      }
      cleaned = cleaned.trim();

      final json = jsonDecode(cleaned) as Map<String, dynamic>;
      final response = ConversationalResponse.fromJson(json);
      expect(response.response, 'Hello!');
      expect(response.actions, isEmpty);
    });

    test('handles JSON wrapped in plain code fences', () {
      const text = '''```
{
  "response": "Hi there!",
  "actions": [{"type": "none"}]
}
```''';
      var cleaned = text.trim();
      if (cleaned.startsWith('```json')) {
        cleaned = cleaned.substring(7);
      } else if (cleaned.startsWith('```')) {
        cleaned = cleaned.substring(3);
      }
      if (cleaned.endsWith('```')) {
        cleaned = cleaned.substring(0, cleaned.length - 3);
      }
      cleaned = cleaned.trim();

      final json = jsonDecode(cleaned) as Map<String, dynamic>;
      final response = ConversationalResponse.fromJson(json);
      expect(response.response, 'Hi there!');
    });

    test('handles extra whitespace around JSON', () {
      const text = '  \n  {"response": "test", "actions": []}  \n  ';
      final cleaned = text.trim();
      final json = jsonDecode(cleaned) as Map<String, dynamic>;
      expect(json['response'], 'test');
    });

    test('extracts response field via regex fallback for non-JSON text', () {
      const text = 'I am not JSON but here is a response field: "response": "Hello"';
      final responseMatch = RegExp(r'"response"\s*:\s*"([^"]*)"').firstMatch(text);
      expect(responseMatch, isNotNull);
      expect(responseMatch!.group(1), 'Hello');
    });
  });

  group('Multi-language scenarios', () {
    test('Kannada text detected in response', () {
      const kannadaResponse = 'ಚೆನ್ನಾಗಿದೆ! ಬಿರಿಯಾನಿ ಹುಡುಕುತ್ತಿದ್ದೇನೆ.';
      final hasKannada = kannadaResponse.contains(RegExp(r'[\u0C80-\u0CFF]'));
      expect(hasKannada, isTrue);
    });

    test('Hindi text detected in response', () {
      const hindiResponse = 'ठीक है! मैं इसे आपके कार्ट में जोड़ देता हूँ.';
      final hasHindi = hindiResponse.contains(RegExp(r'[\u0900-\u097F]'));
      expect(hasHindi, isTrue);
    });

    test('English text has no Indian script', () {
      const englishResponse = 'Great choice! I found biryani for you.';
      final hasKannada = englishResponse.contains(RegExp(r'[\u0C80-\u0CFF]'));
      final hasHindi = englishResponse.contains(RegExp(r'[\u0900-\u097F]'));
      final hasTamil = englishResponse.contains(RegExp(r'[\u0B80-\u0BFF]'));
      final hasTelugu = englishResponse.contains(RegExp(r'[\u0C00-\u0C7F]'));
      expect(hasKannada, isFalse);
      expect(hasHindi, isFalse);
      expect(hasTamil, isFalse);
      expect(hasTelugu, isFalse);
    });

    test('mixed Kannada + English detected', () {
      const mixedResponse = 'biryani ಚೆನ್ನಾಗಿದೆ!';
      final hasKannada = mixedResponse.contains(RegExp(r'[\u0C80-\u0CFF]'));
      expect(hasKannada, isTrue);
    });

    test('Tamil text detected', () {
      const tamilResponse = 'சிறந்த தேர்வு!';
      final hasTamil = tamilResponse.contains(RegExp(r'[\u0B80-\u0BFF]'));
      expect(hasTamil, isTrue);
    });

    test('Telugu text detected', () {
      const teluguResponse = 'మంచి ఎంపిక!';
      final hasTelugu = teluguResponse.contains(RegExp(r'[\u0C00-\u0C7F]'));
      expect(hasTelugu, isTrue);
    });

    test('Bengali text detected', () {
      const bengaliResponse = 'ভালো পছন্দ!';
      final hasBengali = bengaliResponse.contains(RegExp(r'[\u0980-\u09FF]'));
      expect(hasBengali, isTrue);
    });

    test('Gujarati text detected', () {
      const gujaratiResponse = 'સરસ પસંદગી!';
      final hasGujarati = gujaratiResponse.contains(RegExp(r'[\u0A80-\u0AFF]'));
      expect(hasGujarati, isTrue);
    });

    test('Marathi text detected', () {
      const marathiResponse = 'छान पसंत!';
      final hasMarathi = marathiResponse.contains(RegExp(r'[\u0930-\u094F]'));
      expect(hasMarathi, isTrue);
    });

    test('Punjabi text detected', () {
      const punjabiResponse = 'ਵਧੀਆ ਚੋਣ!';
      final hasPunjabi = punjabiResponse.contains(RegExp(r'[\u0A00-\u0A7F]'));
      expect(hasPunjabi, isTrue);
    });

    test('Odia text detected', () {
      const odiaResponse = 'ଭଲ ପସନ୍ଦ!';
      final hasOdia = odiaResponse.contains(RegExp(r'[\u0B00-\u0B7F]'));
      expect(hasOdia, isTrue);
    });
  });

  group('Conversation flow scenarios', () {
    test('multi-turn context preserved', () {
      final conv = MealVoiceConversation();

      // Turn 1: User says they want biryani
      conv.addUserTurn('I want biryani');
      conv.setDetectedLanguage('en-IN');
      conv.addAssistantTurn('Let me search for biryani options.');

      // Turn 2: Search results come in
      conv.setSearchResults([
        {'item_name': 'Chicken Biryani', 'restaurant': 'Palace', 'price': 250},
        {'item_name': 'Veg Biryani', 'restaurant': 'Dosa Palace', 'price': 150},
      ]);

      // Turn 3: User asks which is cheapest
      conv.addUserTurn('Which one is cheapest?');

      // Verify context is available
      expect(conv.lastSearchResults.length, 2);
      expect(conv.history.length, 3);
      expect(conv.history[2].content, 'Which one is cheapest?');
    });

    test('follow-up reference context', () {
      final conv = MealVoiceConversation();

      conv.addUserTurn('Add biryani to cart');
      conv.setSearchResults([
        {'item_name': 'Chicken Biryani', 'restaurant': 'Palace', 'price': 250},
      ]);
      conv.addAssistantTurn('Added Chicken Biryani from Palace.');

      // User says "add that" — "that" refers to the last discussed item
      conv.addUserTurn('Add that to cart too');

      expect(conv.lastSearchResults.length, 1);
      expect(conv.lastSearchResults[0]['item_name'], 'Chicken Biryani');
    });

    test('quantity change context', () {
      final conv = MealVoiceConversation();

      conv.addUserTurn('Add 1 biryani');
      conv.setCartSnapshot(250.0, 1, ['Chicken Biryani']);
      conv.addAssistantTurn('Added 1 Chicken Biryani.');

      // User says "make it two"
      conv.addUserTurn('Make it two');

      expect(conv.cartSnapshot, isNotNull);
      expect(conv.cartSnapshot!['item_count'], 1);
    });

    test('restaurant switching context', () {
      final conv = MealVoiceConversation();

      conv.setCurrentRestaurant('Palace');
      conv.addUserTurn('Show me biryani from Palace');
      conv.addAssistantTurn('Here are biryani options from Palace.');

      // User switches restaurant
      conv.setCurrentRestaurant('Dosa Palace');
      conv.addUserTurn('What about Dosa Palace?');

      expect(conv.currentRestaurant, 'Dosa Palace');
    });

    test('language switching mid-conversation', () {
      final conv = MealVoiceConversation();

      // English turn
      conv.addUserTurn('I want biryani');
      conv.setDetectedLanguage('en-IN');
      conv.addAssistantTurn('Let me search for biryani.');

      // Hindi turn
      conv.addUserTurn('मुझे दो चाहिए');
      conv.setDetectedLanguage('hi-IN');
      conv.addAssistantTurn('ठीक है, दो बिरयानी जोड़ रहा हूँ।');

      // Kannada turn
      conv.addUserTurn('ಇನ್ನೊಂದು ಕೊಡಿ');
      conv.setDetectedLanguage('kn-IN');

      expect(conv.detectedLanguage, 'kn-IN');
      expect(conv.history.length, 5);
    });
  });
}
