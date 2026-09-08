import 'package:flutter_test/flutter_test.dart';
import 'package:mealin/meal_voice/meal_voice_conversation.dart';

void main() {
  group('MealVoiceConversation', () {
    late MealVoiceConversation conversation;

    setUp(() {
      conversation = MealVoiceConversation();
    });

    group('Conversation history', () {
      test('starts empty', () {
        expect(conversation.history, isEmpty);
      });

      test('adds user turn', () {
        conversation.addUserTurn('I want biryani');
        expect(conversation.history.length, 1);
        expect(conversation.history.first.role, 'user');
        expect(conversation.history.first.content, 'I want biryani');
      });

      test('adds assistant turn', () {
        conversation.addAssistantTurn('Great choice!');
        expect(conversation.history.length, 1);
        expect(conversation.history.first.role, 'model');
        expect(conversation.history.first.content, 'Great choice!');
      });

      test('alternates user and assistant turns', () {
        conversation.addUserTurn('Hello');
        conversation.addAssistantTurn('Hi there!');
        conversation.addUserTurn('I want food');
        conversation.addAssistantTurn('What kind?');
        expect(conversation.history.length, 4);
        expect(conversation.history[0].role, 'user');
        expect(conversation.history[1].role, 'model');
        expect(conversation.history[2].role, 'user');
        expect(conversation.history[3].role, 'model');
      });

      test('trims history to max 10 turns', () {
        for (int i = 0; i < 15; i++) {
          conversation.addUserTurn('message $i');
        }
        expect(conversation.history.length, 10);
        expect(conversation.history.first.content, 'message 5');
        expect(conversation.history.last.content, 'message 14');
      });

      test('returns unmodifiable list', () {
        conversation.addUserTurn('test');
        expect(
          () => conversation.history.add(
            ConversationTurn(role: 'user', content: 'hacked'),
          ),
          throwsA(isA<UnsupportedError>()),
        );
      });
    });

    group('Detected language', () {
      test('defaults to en-IN', () {
        expect(conversation.detectedLanguage, 'en-IN');
      });

      test('updates detected language', () {
        conversation.setDetectedLanguage('kn-IN');
        expect(conversation.detectedLanguage, 'kn-IN');
      });

      test('ignores empty language code', () {
        conversation.setDetectedLanguage('kn-IN');
        conversation.setDetectedLanguage('');
        expect(conversation.detectedLanguage, 'kn-IN');
      });
    });

    group('Restaurant context', () {
      test('starts null', () {
        expect(conversation.currentRestaurant, isNull);
      });

      test('sets restaurant', () {
        conversation.setCurrentRestaurant('Palace');
        expect(conversation.currentRestaurant, 'Palace');
      });

      test('clears restaurant', () {
        conversation.setCurrentRestaurant('Palace');
        conversation.setCurrentRestaurant(null);
        expect(conversation.currentRestaurant, isNull);
      });
    });

    group('Search results context', () {
      test('starts empty', () {
        expect(conversation.lastSearchResults, isEmpty);
      });

      test('updates search results', () {
        conversation.setSearchResults([
          {'item_name': 'biryani', 'price': 200.0, 'restaurant': 'Palace'},
          {'item_name': 'dosa', 'price': 80.0, 'restaurant': 'Dosa Palace'},
        ]);
        expect(conversation.lastSearchResults.length, 2);
        expect(conversation.lastSearchResults[0]['item_name'], 'biryani');
      });

      test('returns unmodifiable list', () {
        conversation.setSearchResults([
          {'item_name': 'biryani'},
        ]);
        expect(
          () => conversation.lastSearchResults.add({'hacked': true}),
          throwsA(isA<UnsupportedError>()),
        );
      });
    });

    group('Cart snapshot', () {
      test('starts null', () {
        expect(conversation.cartSnapshot, isNull);
      });

      test('updates cart snapshot', () {
        conversation.setCartSnapshot(350.0, 3, ['biryani', 'coke', 'cake']);
        final cart = conversation.cartSnapshot;
        expect(cart, isNotNull);
        expect(cart!['total'], 350.0);
        expect(cart['item_count'], 3);
        expect(cart['items'], ['biryani', 'coke', 'cake']);
      });
    });

    group('Pending confirmation', () {
      test('starts null', () {
        expect(conversation.pendingConfirmation, isNull);
      });

      test('sets pending confirmation', () {
        conversation.setPendingConfirmation({
          'item_name': 'biryani',
          'quantity': 1,
          'restaurant': 'Palace',
        });
        expect(conversation.pendingConfirmation, isNotNull);
        expect(conversation.pendingConfirmation!['item_name'], 'biryani');
      });

      test('clears pending confirmation', () {
        conversation.setPendingConfirmation({'item': 'test'});
        conversation.setPendingConfirmation(null);
        expect(conversation.pendingConfirmation, isNull);
      });
    });

    group('buildGeminiHistory', () {
      test('builds correct format', () {
        conversation.addUserTurn('Hello');
        conversation.addAssistantTurn('Hi!');
        conversation.addUserTurn('I want food');

        final history = conversation.buildGeminiHistory();
        expect(history.length, 3);
        expect(history[0], {'role': 'user', 'content': 'Hello'});
        expect(history[1], {'role': 'model', 'content': 'Hi!'});
        expect(history[2], {'role': 'user', 'content': 'I want food'});
      });
    });

    group('buildContext', () {
      test('includes detected language', () {
        conversation.setDetectedLanguage('hi-IN');
        final ctx = conversation.buildContext();
        expect(ctx['detected_language'], 'hi-IN');
      });

      test('includes restaurant when set', () {
        conversation.setCurrentRestaurant('Palace');
        final ctx = conversation.buildContext();
        expect(ctx['current_restaurant'], 'Palace');
      });

      test('includes search results when set', () {
        conversation.setSearchResults([
          {'item_name': 'biryani'},
        ]);
        final ctx = conversation.buildContext();
        expect(ctx['last_search_results'], isA<List>());
      });

      test('includes cart when set', () {
        conversation.setCartSnapshot(200.0, 2, ['biryani', 'coke']);
        final ctx = conversation.buildContext();
        expect(ctx['cart'], isA<Map>());
        expect(ctx['cart']['total'], 200.0);
      });

      test('includes pending confirmation when set', () {
        conversation.setPendingConfirmation({'item': 'test'});
        final ctx = conversation.buildContext();
        expect(ctx['pending_confirmation'], isA<Map>());
      });

      test('omits null fields', () {
        final ctx = conversation.buildContext();
        expect(ctx.containsKey('restaurant'), isFalse);
        expect(ctx.containsKey('last_search_results'), isFalse);
        expect(ctx.containsKey('cart'), isFalse);
        expect(ctx.containsKey('pending_confirmation'), isFalse);
      });
    });

    group('reset', () {
      test('clears all state', () {
        conversation.addUserTurn('test');
        conversation.addAssistantTurn('response');
        conversation.setDetectedLanguage('kn-IN');
        conversation.setCurrentRestaurant('Palace');
        conversation.setSearchResults([{'item': 'test'}]);
        conversation.setCartSnapshot(100.0, 1, ['test']);
        conversation.setPendingConfirmation({'confirm': true});

        conversation.reset();

        expect(conversation.history, isEmpty);
        expect(conversation.detectedLanguage, 'en-IN');
        expect(conversation.currentRestaurant, isNull);
        expect(conversation.lastSearchResults, isEmpty);
        expect(conversation.cartSnapshot, isNull);
        expect(conversation.pendingConfirmation, isNull);
      });
    });

    group('toJsonString', () {
      test('returns valid JSON string', () {
        conversation.addUserTurn('hello');
        conversation.setDetectedLanguage('hi-IN');

        final json = conversation.toJsonString();
        expect(json, isA<String>());
        expect(json.contains('"history"'), isTrue);
        expect(json.contains('"language"'), isTrue);
      });
    });
  });

  group('ConversationTurn', () {
    test('serializes to JSON', () {
      final turn = ConversationTurn(role: 'user', content: 'Hello');
      final json = turn.toJson();
      expect(json['role'], 'user');
      expect(json['content'], 'Hello');
    });

    test('deserializes from JSON', () {
      final turn = ConversationTurn.fromJson({
        'role': 'model',
        'content': 'Hi there!',
      });
      expect(turn.role, 'model');
      expect(turn.content, 'Hi there!');
    });
  });
}
