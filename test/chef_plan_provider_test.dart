import 'package:flutter_test/flutter_test.dart';
import 'package:mealin/core/constants/app_constants.dart';
import 'package:mealin/core/services/api_service.dart';
import 'package:mealin/features/chef/domain/models/meal_plan_model.dart';
import 'package:mealin/features/chef/domain/models/plan_subscriber.dart';
import 'package:mealin/core/services/token_service.dart';
import 'package:mealin/features/chef/presentation/providers/meal_plan_provider.dart';

/// Records every call and replays queued responses.
class FakeApiService extends ApiService {
  final List<String> gets = [];
  final List<Map<String, dynamic>> getQueries = [];
  final List<String> posts = [];
  final List<Map<String, dynamic>> postBodies = [];
  final List<String> patches = [];
  final List<Map<String, dynamic>> patchBodies = [];
  final List<String> deletes = [];

  /// Consumed one-per-call; the last entry repeats once exhausted so a test can
  /// queue "same page forever" to exercise the pagination cap.
  final List<Map<String, dynamic>> getQueue = [];
  Map<String, dynamic> postResponse = {};
  Map<String, dynamic> patchResponse = {};
  Object? throwOnGet;
  Object? throwOnPost;
  Object? throwOnPatch;
  Object? throwOnDelete;

  FakeApiService() : super(baseUrl: 'https://example.test');

  Map<String, dynamic> _nextGet() {
    if (throwOnGet != null) throw throwOnGet!;
    if (getQueue.isEmpty) return {'results': <dynamic>[], 'count': 0};
    if (getQueue.length == 1) return getQueue.first;
    return getQueue.removeAt(0);
  }

  @override
  Future<Map<String, dynamic>> get(String endpoint,
      {Map<String, dynamic>? queryParams}) async {
    gets.add(endpoint);
    getQueries.add(queryParams ?? {});
    return _nextGet();
  }

  @override
  Future<Map<String, dynamic>> post(String endpoint,
      {Map<String, dynamic>? body, Map<String, dynamic>? queryParams}) async {
    posts.add(endpoint);
    postBodies.add(body ?? {});
    if (throwOnPost != null) throw throwOnPost!;
    return postResponse;
  }

  @override
  Future<Map<String, dynamic>> patch(String endpoint,
      {Map<String, dynamic>? body}) async {
    patches.add(endpoint);
    patchBodies.add(body ?? {});
    if (throwOnPatch != null) throw throwOnPatch!;
    return patchResponse;
  }

  @override
  Future<Map<String, dynamic>> delete(String endpoint) async {
    deletes.add(endpoint);
    if (throwOnDelete != null) throw throwOnDelete!;
    return {};
  }

  @override
  void setToken(String token) {}
}

/// Returns no token without touching secure storage, which has no test
/// implementation and would otherwise throw MissingPluginException.
class FakeTokenService extends TokenService {
  @override
  Future<String?> getAccessToken() async => null;
}

Map<String, dynamic> _planJson({
  int id = 7,
  String kitchen = '3',
  String name = 'Weekly Thali',
  bool active = false,
}) =>
    {
      'id': id,
      'kitchen': kitchen,
      'name': name,
      'description': 'desc',
      'inclusions': <String>[],
      'isVeg': true,
      'imageUrl': '',
      'isActive': active,
      'startingPrice': '250.00',
      'prices': <dynamic>[
        {'id': 1, 'cadence': 'week', 'price': '250.00', 'durationDays': 7, 'isActive': true}
      ],
      'slots': <dynamic>[],
    };

void main() {
  // MealPlanProvider's default TokenService reads SharedPreferences, which
  // needs the binding even though these tests never exercise auth.
  TestWidgetsFlutterBinding.ensureInitialized();

  MealPlanProvider build(FakeApiService api) =>
      MealPlanProvider(apiService: api, tokenService: FakeTokenService());

  group('fetchPlans', () {
    test('reads the chef endpoint, not the customer one', () async {
      final api = FakeApiService();
      api.getQueue.add({'count': 1, 'results': [_planJson()]});

      await build(api).fetchPlans('3');

      expect(api.gets, [AppConstants.chefMealPlansEndpoint]);
      expect(api.gets.first, isNot(AppConstants.subscriptionPlansEndpoint));
    });

    test('parses the paginated envelope', () async {
      final api = FakeApiService();
      api.getQueue.add({'count': 1, 'results': [_planJson(name: 'Priced')]});

      final provider = build(api);
      await provider.fetchPlans('3');

      expect(provider.plans, hasLength(1));
      expect(provider.plans.single.name, 'Priced');
      expect(provider.plans.single.kitchenId, '3');
      expect(provider.plans.single.prices.single.cadence, 'week');
    });

    test('drops plans belonging to another kitchen', () async {
      final api = FakeApiService();
      api.getQueue.add({
        'count': 2,
        'results': [_planJson(id: 1, kitchen: '3'), _planJson(id: 2, kitchen: '999')],
      });

      final provider = build(api);
      await provider.fetchPlans('3');

      // Defence in depth: the server already scopes this, but a stale response
      // from a previously-viewed kitchen must not leak into the builder.
      expect(provider.plans.map((p) => p.id), ['1']);
    });

    test('surfaces the server message rather than a raw exception', () async {
      final api = FakeApiService();
      api.throwOnGet = ApiException('Only kitchen accounts can manage meal plans.', 403);

      final provider = build(api);
      await provider.fetchPlans('3');

      expect(provider.errorMessage, 'Only kitchen accounts can manage meal plans.');
      expect(provider.errorMessage, isNot(contains('ApiException')));
      expect(provider.plans, isEmpty);
    });
  });

  group('savePlan', () {
    test('POSTs when the plan has no id', () async {
      final api = FakeApiService();
      api.postResponse = _planJson(id: 42);
      api.getQueue.add({'count': 1, 'results': [_planJson(id: 42)]});

      final provider = build(api);
      provider.startDraft(null);
      provider.setDraftName('New plan');

      await provider.savePlan(const MealPlan(
        name: 'New plan',
        kitchenId: '3',
      ));

      expect(api.posts, [AppConstants.chefMealPlansEndpoint]);
      expect(api.patches, isEmpty);
      expect(api.postBodies.single['kitchen'], '3');
    });

    test('PATCHes when the plan already has an id', () async {
      final api = FakeApiService();
      api.patchResponse = _planJson(id: 42, name: 'Renamed');
      api.getQueue.add({'count': 1, 'results': [_planJson(id: 42, name: 'Renamed')]});

      final provider = build(api);
      await provider.savePlan(const MealPlan(id: '42', name: 'Renamed', kitchenId: '3'));

      expect(api.posts, isEmpty);
      expect(api.patches, ['${AppConstants.chefMealPlansEndpoint}42/']);
    });

    test('adopts the server id so a second save is an update', () async {
      final api = FakeApiService();
      api.postResponse = _planJson(id: 42);
      api.getQueue.add({'count': 1, 'results': [_planJson(id: 42)]});
      api.patchResponse = _planJson(id: 42, name: 'Renamed');
      api.getQueue.add({'count': 1, 'results': [_planJson(id: 42, name: 'Renamed')]});

      final provider = build(api);
      await provider.savePlan(const MealPlan(name: 'First', kitchenId: '3'));
      expect(provider.draft!.id, '42');

      await provider.savePlan(provider.buildDraftPlan());
      expect(api.posts, hasLength(1), reason: 'no duplicate create');
      expect(api.patches, hasLength(1));
    });

    test('refuses to create without a kitchen', () async {
      final api = FakeApiService();
      final provider = build(api);

      await expectLater(
        provider.savePlan(const MealPlan(name: 'Orphan')),
        throwsA(isA<StateError>()),
      );
      expect(api.posts, isEmpty);
      expect(provider.errorMessage, contains('kitchen'));
    });

    test('rethrows so the screen can stay put and keep the grid', () async {
      final api = FakeApiService();
      api.throwOnPost = ApiException('Name is required.', 400);

      final provider = build(api);
      await expectLater(
        provider.savePlan(const MealPlan(name: 'x', kitchenId: '3')),
        throwsA(isA<ApiException>()),
      );
      expect(provider.errorMessage, 'Name is required.');
      // Draft survives the failure so nothing the chef typed is lost.
      expect(provider.draft, isNull);
      expect(provider.isSaving, isFalse);
    });

    test('folds the server echo back into the draft grid', () async {
      final api = FakeApiService();
      api.postResponse = {
        ..._planJson(id: 42),
        'slots': [
          {
            'id': 5,
            'dayOfWeek': 0,
            'mealType': 'dinner',
            'title': 'Monday dinner',
            'items': <dynamic>[],
            'isActive': true,
          }
        ],
      };
      api.getQueue.add({'count': 1, 'results': [_planJson(id: 42)]});

      final provider = build(api);
      await provider.savePlan(const MealPlan(name: 'Gridded', kitchenId: '3'));

      expect(provider.draft!.id, '42');
      expect(provider.draftSlots.keys, contains('0|dinner'));
      expect(provider.draftPrices.keys, contains('week'));
    });
  });

  group('publishPlan / deletePlan', () {
    test('publish toggles only is_active', () async {
      final api = FakeApiService();
      api.patchResponse = _planJson(id: 42, active: true);
      api.getQueue.add({'count': 0, 'results': <dynamic>[]});

      final provider = build(api);
      await provider.publishPlan('42', true);

      expect(api.patchBodies.single, {'is_active': true});
    });

    test('unpublish sends false', () async {
      final api = FakeApiService();
      api.patchResponse = _planJson(id: 42, active: false);
      api.getQueue.add({'count': 0, 'results': <dynamic>[]});

      await build(api).publishPlan('42', false);
      expect(api.patchBodies.single, {'is_active': false});
    });

    test('delete removes the plan and clears an open draft', () async {
      final api = FakeApiService();
      api.getQueue.add({'count': 1, 'results': [_planJson(id: 42)]});

      final provider = build(api);
      await provider.fetchPlans('3');
      provider.startDraft(provider.plans.single);
      expect(provider.draft!.id, '42');

      await provider.deletePlan('42');

      expect(api.deletes, ['${AppConstants.chefMealPlansEndpoint}42/']);
      expect(provider.plans, isEmpty);
      expect(provider.draft, isNull);
    });

    test('a 409 (has subscribers) surfaces as the server message', () async {
      final api = FakeApiService();
      api.throwOnDelete =
          ApiException('This plan has active subscribers and cannot be deleted.', 409);

      final provider = build(api);
      await expectLater(provider.deletePlan('42'), throwsA(isA<ApiException>()));
      expect(provider.errorMessage, contains('active subscribers'));
    });
  });

  group('fetchSubscribers', () {
    test('reads the all-plans endpoint by default', () async {
      final api = FakeApiService();
      api.getQueue.add({
        'count': 1,
        'has_next': false,
        'results': [
          {
            'id': 1,
            'status': 'active',
            'cadence': 'week',
            'price_paid': '250.00',
            'start_date': '2026-01-04',
            'customer_uid': 'uid-1',
            'customer_name': 'Asha',
            'plan_id': 7,
            'plan_name': 'Weekly Thali',
          }
        ],
      });

      final provider = build(api);
      final rows = await provider.fetchSubscribers();

      expect(api.gets.first, AppConstants.chefPlanSubscribersEndpoint);
      expect(rows, hasLength(1));
      expect(rows.single.customerName, 'Asha');
      expect(rows.single.planName, 'Weekly Thali');
      expect(rows.single.isActive, isTrue);
    });

    test('reads the per-plan endpoint when planId is given', () async {
      final api = FakeApiService();
      api.getQueue.add({'count': 0, 'has_next': false, 'results': <dynamic>[]});

      await build(api).fetchSubscribers(planId: '42');
      expect(api.gets.single, '${AppConstants.chefMealPlansEndpoint}42/subscribers/');
    });

    test('follows has_next across pages', () async {
      final api = FakeApiService();
      api.getQueue.add({
        'count': 2,
        'has_next': true,
        'results': [
          {'id': 1, 'customer_uid': 'a', 'customer_name': 'A', 'status': 'active'}
        ],
      });
      api.getQueue.add({
        'count': 2,
        'has_next': false,
        'results': [
          {'id': 2, 'customer_uid': 'b', 'customer_name': 'B', 'status': 'paused'}
        ],
      });

      final provider = build(api);
      final rows = await provider.fetchSubscribers();

      expect(rows, hasLength(2));
      expect(api.gets, hasLength(2));
      expect(api.getQueries.first['page'], 1);
      expect(api.getQueries.last['page'], 2);
      expect(provider.subscribersTruncated, isFalse);
    });

    test('stops at the page cap and flags truncation', () async {
      final api = FakeApiService();
      // One repeating page that always claims another one exists.
      api.getQueue.add({
        'count': 9999,
        'has_next': true,
        'results': [
          {'id': 1, 'customer_uid': 'a', 'customer_name': 'A', 'status': 'active'}
        ],
      });

      final provider = build(api);
      final rows = await provider.fetchSubscribers(maxPages: 3);

      expect(rows, hasLength(3));
      expect(api.gets, hasLength(3));
      // The UI needs to know this list is not everything, or a chef would
      // conclude only 3 customers ever subscribed.
      expect(provider.subscribersTruncated, isTrue);
    });

    test('an error yields an empty list and a readable message', () async {
      final api = FakeApiService();
      api.throwOnGet = ApiException('Not found.', 404);

      final provider = build(api);
      final rows = await provider.fetchSubscribers();

      expect(rows, isEmpty);
      expect(provider.subscriberError, 'Not found.');
      expect(provider.isLoadingSubscribers, isFalse);
    });

    test('clearSubscribers resets truncation too', () async {
      final api = FakeApiService();
      api.getQueue.add({
        'count': 9999,
        'has_next': true,
        'results': [
          {'id': 1, 'customer_uid': 'a', 'customer_name': 'A', 'status': 'active'}
        ],
      });

      final provider = build(api);
      await provider.fetchSubscribers(maxPages: 2);
      expect(provider.subscribersTruncated, isTrue);

      provider.clearSubscribers();
      expect(provider.subscribers, isEmpty);
      expect(provider.subscribersTruncated, isFalse);
      expect(provider.subscriberError, isNull);
    });
  });

  group('PlanSubscriber mapping', () {
    test('reads snake_case keys', () {
      final s = PlanSubscriber.fromMap({
        'id': 9,
        'status': 'active',
        'cadence': 'month',
        'price_paid': '900.00',
        'start_date': '2026-02-01',
        'end_date': '2026-03-01',
        'customer_uid': 'uid-9',
        'customer_name': 'Ravi',
        'customer_phone': '9800000000',
        'address': '12 MG Road',
      });

      expect(s.id, '9');
      expect(s.pricePaid, '900.00');
      expect(s.customerPhone, '9800000000');
      expect(s.address, '12 MG Road');
      expect(s.cadenceLabel, 'months');
    });

    test('missing keys degrade instead of throwing', () {
      final s = PlanSubscriber.fromMap({'id': 1});
      expect(s.customerName, '');
      expect(s.pricePaid, '');
      expect(s.isActive, isFalse);
    });

    test('displayName falls back to the uid, never blank', () {
      expect(
        PlanSubscriber.fromMap({'id': 1, 'customer_uid': 'uid-1'}).displayName,
        'uid-1',
      );
      expect(
        PlanSubscriber.fromMap({'id': 1, 'customer_uid': 'uid-1', 'customer_name': 'Asha'}).displayName,
        'Asha',
      );
    });
  });

  group('draft duplication and cover image', () {
    test('startDuplicate clears the id so it POSTs as a new plan', () {
      final provider = build(FakeApiService());

      provider.startDuplicate(const MealPlan(
        id: '42',
        name: 'Weekly Thali',
        kitchenId: '3',
        isActive: true,
      ));

      // id cleared => savePlan takes the POST branch instead of PATCHing over
      // the original plan, which would overwrite it.
      expect(provider.draft!.id, isEmpty);
      expect(provider.draft!.name, 'Weekly Thali (copy)');
      // The server forces is_active=false on create anyway; the draft should
      // not claim to be live.
      expect(provider.draft!.isActive, isFalse);
      expect(provider.draft!.kitchenId, '3');
    });

    test('startDuplicate carries the grid and prices across', () {
      final provider = build(FakeApiService());

      provider.startDuplicate(const MealPlan(
        id: '42',
        name: 'Gridded',
        kitchenId: '3',
        slots: [
          MealPlanSlot(
            dayOfWeek: 0,
            dayName: 'Mon',
            mealType: 'dinner',
            title: 'Dal Rice',
          ),
        ],
        prices: [PlanPrice(cadence: 'week', price: '250')],
      ));

      expect(provider.draftSlots.keys, contains('0|dinner'));
      expect(provider.draftPrices.keys, contains('week'));
    });

    test('setDraftImage updates the draft and the write payload', () {
      final provider = build(FakeApiService());
      provider.startDraft(null);
      provider.setDraftName('With photo');

      provider.setDraftImage('/media/uploads/abc.jpg');

      expect(provider.draft!.imageUrl, '/media/uploads/abc.jpg');
      // The snake_case key the backend's ModelSerializer expects.
      expect(provider.buildDraftPlan().toWriteJson()['image_url'],
          '/media/uploads/abc.jpg');
    });

    test('setDraftImage is a no-op with no draft open', () {
      final provider = build(FakeApiService());
      provider.setDraftImage('/media/uploads/abc.jpg');
      expect(provider.draft, isNull);
    });
  });

  group('reset', () {
    test('clears subscriber state too', () async {
      final api = FakeApiService();
      api.getQueue.add({
        'count': 1,
        'has_next': false,
        'results': [
          {'id': 1, 'customer_uid': 'a', 'customer_name': 'A', 'status': 'active'}
        ],
      });

      final provider = build(api);
      await provider.fetchSubscribers();
      expect(provider.subscribers, isNotEmpty);

      provider.reset();
      expect(provider.subscribers, isEmpty);
      expect(provider.isLoadingSubscribers, isFalse);
      expect(provider.subscriberError, isNull);
      expect(provider.subscribersTruncated, isFalse);
    });
  });
}
