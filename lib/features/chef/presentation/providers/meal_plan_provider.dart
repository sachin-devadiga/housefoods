import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/token_service.dart';
import '../../domain/models/meal_plan_model.dart';
import '../../domain/models/plan_subscriber.dart';

/// Chef-side state for subscription plans.
///
/// Reads and writes go to the chef endpoints in `backend/api/chef_plan_views.py`,
/// which scope every queryset to kitchens the caller owns. A non-chef gets a
/// 403 rather than an empty list, so an authorisation failure is never
/// mistaken for "you have no plans".
///
/// [fetchPlans] takes a kitchenId only to scope the builder UI; the server
/// already restricts the result, so the id is used for client-side labelling
/// and defence-in-depth filtering, not for access control.
class MealPlanProvider extends ChangeNotifier {
  final ApiService _api;
  final TokenService _tokenService;

  MealPlanProvider({ApiService? apiService, TokenService? tokenService})
      : _api = apiService ?? ApiService(baseUrl: AppConstants.apiBaseUrl),
        _tokenService = tokenService ?? TokenService();

  Future<void> _ensureAuthenticated() async {
    final token = await _tokenService.getAccessToken();
    if (token != null) _api.setToken(token);
  }

  List<MealPlan> _plans = [];
  List<MealPlan> get plans => _plans;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get errorMessage => _error;

  /// The plan currently open in the builder, unsaved.
  MealPlan? _draft;
  MealPlan? get draft => _draft;

  /// Cells the chef has filled in, keyed "day|mealType". Survives navigation
  /// between the builder, the pricing screen and back.
  final Map<String, MealPlanSlot> _draftSlots = {};
  Map<String, MealPlanSlot> get draftSlots => Map.unmodifiable(_draftSlots);

  /// Cadence prices being edited, keyed cadence.
  final Map<String, PlanPrice> _draftPrices = {};
  Map<String, PlanPrice> get draftPrices => Map.unmodifiable(_draftPrices);

  bool _isSaving = false;
  bool get isSaving => _isSaving;

  List<PlanSubscriber> _subscribers = [];
  List<PlanSubscriber> get subscribers => List.unmodifiable(_subscribers);

  bool _isLoadingSubscribers = false;
  bool get isLoadingSubscribers => _isLoadingSubscribers;

  String? _subscriberError;
  String? get subscriberError => _subscriberError;

  /// True when [fetchSubscribers] stopped at its page cap with rows remaining
  /// server-side. The screen shows a "showing first N" note rather than
  /// presenting a truncated list as complete.
  bool _subscribersTruncated = false;
  bool get subscribersTruncated => _subscribersTruncated;

  static String slotKey(int dayOfWeek, String mealType) => '$dayOfWeek|$mealType';

  void reset() {
    _plans = [];
    _draft = null;
    _draftSlots.clear();
    _draftPrices.clear();
    _isLoading = false;
    _isSaving = false;
    _error = null;
    _subscribers = [];
    _isLoadingSubscribers = false;
    _subscriberError = null;
    _subscribersTruncated = false;
    notifyListeners();
  }

  /// Loads plans for a kitchen.
  ///
  /// The public plan list is customer-scoped and filtered by radius, so a plan
  /// the chef has deactivated (or whose kitchen is closed) will not appear.
  /// That is a real limitation of the read path, not a bug to paper over —
  /// the empty state below says so.
  Future<void> fetchPlans(String kitchenId) async {
    if (kitchenId.isEmpty) {
      _plans = [];
      notifyListeners();
      return;
    }
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _ensureAuthenticated();
      final data = await _api.get(AppConstants.chefMealPlansEndpoint);
      // Paginated envelope, but tolerate a bare array so a future change to
      // the server's serializer does not blank the chef's whole plan list.
      final results =
          (data['results'] as List?) ?? (data['data'] as List?) ?? const [];
      var parsed = results
          .whereType<Map<String, dynamic>>()
          .map(MealPlan.fromMap)
          .toList();
      // The server already scopes to owned kitchens. Filtering again on the
      // client keeps a stale response from a previous kitchen out of the UI.
      if (kitchenId.isNotEmpty) {
        parsed = parsed.where((p) => p.kitchenId == kitchenId).toList();
      }
      _plans = parsed;
    } catch (e) {
      debugPrint("Error fetching chef meal plans: $e");
      _error = _readableError(e);
      _plans = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Opens a plan for editing. Passing null starts a blank draft.
  void startDraft(MealPlan? plan) {
    _draft = plan ??
        const MealPlan(
          name: '',
          description: '',
          inclusions: [],
        );
    _draftSlots.clear();
    _draftPrices.clear();
    for (final slot in _draft!.slots) {
      _draftSlots[slotKey(slot.dayOfWeek, slot.mealType)] = slot;
    }
    for (final price in _draft!.prices) {
      _draftPrices[price.cadence] = price;
    }
    notifyListeners();
  }

  void setDraftName(String name) {
    final draft = _draft;
    if (draft == null) return;
    _draft = draft.copyWith(name: name);
    notifyListeners();
  }

  void setDraftActive(bool isActive) {
    final draft = _draft;
    if (draft == null) return;
    _draft = draft.copyWith(isActive: isActive);
    notifyListeners();
  }

  void upsertSlot(MealPlanSlot slot) {
    _draftSlots[slotKey(slot.dayOfWeek, slot.mealType)] = slot;
    notifyListeners();
  }

  MealPlanSlot? slotAt(int dayOfWeek, String mealType) =>
      _draftSlots[slotKey(dayOfWeek, mealType)];

  void setSlotActive(int dayOfWeek, String mealType, bool isActive) {
    final slot = slotAt(dayOfWeek, mealType);
    if (slot == null || slot.isActive == isActive) return;
    upsertSlot(slot.copyWith(isActive: isActive));
  }

  void upsertPrice(PlanPrice price) {
    _draftPrices[price.cadence] = price;
    notifyListeners();
  }

  PlanPrice? priceFor(String cadence) => _draftPrices[cadence];

  /// Folds the in-progress grid and prices into one draft plan.
  MealPlan buildDraftPlan() {
    final draft = _draft ?? const MealPlan(name: '');
    final slots = _draftSlots.values.toList()
      ..sort((a, b) {
        final byDay = a.dayOfWeek.compareTo(b.dayOfWeek);
        return byDay != 0 ? byDay : a.mealType.compareTo(b.mealType);
      });
    return draft.copyWith(slots: slots, prices: _draftPrices.values.toList());
  }

  /// Persists the whole plan (grid + prices) and refreshes the list.
  ///
  /// POST for a plan with no id, PATCH otherwise. `MealPlan.toWriteJson()`
  /// already matches `MealPlanWriteSerializer` (snake_case, since the write
  /// serializer is a plain ModelSerializer rather than the camelCase read one).
  ///
  /// Two server-side behaviours this deliberately does not fight:
  ///   * POST always creates a **draft**, ignoring a client-sent `is_active`.
  ///     Publishing is an explicit second step ([publishPlan]) so a
  ///     half-finished plan cannot become subscribable by accident.
  ///   * `kitchen` cannot be reassigned by PATCH; moving a plan would
  ///     silently transfer its subscribers.
  ///
  /// On success the returned plan replaces the draft, so the builder holds a
  /// real server id and a subsequent save is an update rather than a
  /// duplicate create.
  Future<void> savePlan(MealPlan plan) async {
    _isSaving = true;
    _error = null;
    notifyListeners();
    try {
      await _ensureAuthenticated();
      final body = plan.toWriteJson();

      Map<String, dynamic> saved;
      if (plan.id.isEmpty) {
        if (plan.kitchenId.isEmpty) {
          throw StateError('A kitchen is required before a plan can be saved.');
        }
        saved = await _api.post(
          AppConstants.chefMealPlansEndpoint,
          body: {'kitchen': plan.kitchenId, ...body},
        );
      } else {
        saved = await _api.patch(
          '${AppConstants.chefMealPlansEndpoint}${plan.id}/',
          body: body,
        );
      }

      final persisted = MealPlan.fromMap(saved);
      _draft = persisted;
      // Fold the server's echo back into the in-progress grid so a slot the
      // server normalised (or rejected) is visible rather than silently lost.
      _draftSlots.clear();
      for (final slot in persisted.slots) {
        _draftSlots[slotKey(slot.dayOfWeek, slot.mealType)] = slot;
      }
      _draftPrices.clear();
      for (final price in persisted.prices) {
        _draftPrices[price.cadence] = price;
      }
      await fetchPlans(persisted.kitchenId);
    } catch (e) {
      debugPrint('Error saving meal plan: $e');
      _error = _readableError(e);
      rethrow;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Publishes or unpublishes an existing plan.
  ///
  /// Separate from [savePlan] because the server refuses to auto-publish on
  /// create. A 404 here means the plan is not the caller's; the message says
  /// so rather than showing a generic failure.
  Future<void> publishPlan(String planId, bool publish) async {
    _isSaving = true;
    _error = null;
    notifyListeners();
    try {
      await _ensureAuthenticated();
      final saved = await _api.patch(
        '${AppConstants.chefMealPlansEndpoint}$planId/',
        body: {'is_active': publish},
      );
      final persisted = MealPlan.fromMap(saved);
      final idx = _plans.indexWhere((p) => p.id == persisted.id);
      if (idx >= 0) _plans[idx] = persisted;
      if (_draft?.id == persisted.id) _draft = persisted;
    } catch (e) {
      debugPrint('Error publishing meal plan: $e');
      _error = _readableError(e);
      rethrow;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Deletes a plan.
  ///
  /// The server returns 409 when the plan still has subscribers (the
  /// `Subscription.plan` FK is PROTECT). That is surfaced as a message telling
  /// the chef to unpublish instead, not as a generic error.
  Future<void> deletePlan(String planId) async {
    _isSaving = true;
    _error = null;
    notifyListeners();
    try {
      await _ensureAuthenticated();
      await _api.delete('${AppConstants.chefMealPlansEndpoint}$planId/');
      _plans.removeWhere((p) => p.id == planId);
      if (_draft?.id == planId) {
        _draft = null;
        _draftSlots.clear();
        _draftPrices.clear();
      }
    } catch (e) {
      debugPrint('Error deleting meal plan: $e');
      _error = _readableError(e);
      rethrow;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Subscribers across all of this chef's plans, newest first.
  ///
  /// Walks pages until the server says there is no next one. [maxPages] bounds
  /// that walk so a chef with thousands of subscribers cannot hang the screen;
  /// when the cap trips, [subscribersTruncated] is true so the UI can say the
  /// list is partial rather than implying it is everything.
  ///
  /// Empty list means either "no subscribers" or "not loaded yet" — the screen
  /// distinguishes those via [isLoadingSubscribers].
  Future<List<PlanSubscriber>> fetchSubscribers({
    String? planId,
    int maxPages = 20,
  }) async {
    _isLoadingSubscribers = true;
    _subscriberError = null;
    _subscribersTruncated = false;
    notifyListeners();
    try {
      await _ensureAuthenticated();
      final endpoint = planId != null && planId.isNotEmpty
          ? '${AppConstants.chefMealPlansEndpoint}$planId/subscribers/'
          : AppConstants.chefPlanSubscribersEndpoint;

      final all = <PlanSubscriber>[];
      var page = 1;
      while (page <= maxPages) {
        final data = await _api.get(
          endpoint,
          queryParams: {'page': page, 'page_size': 100},
        );
        final rows = (data['results'] as List?) ?? const [];
        all.addAll(
          rows.whereType<Map<String, dynamic>>().map(PlanSubscriber.fromMap),
        );
        final hasNext = data['has_next'] as bool? ??
            (data['next'] != null && data['next'] != '');
        if (!hasNext || rows.isEmpty) break;
        page++;
      }
      _subscribersTruncated = page > maxPages;
      if (_subscribersTruncated) {
        debugPrint(
          'fetchSubscribers: stopped at $maxPages pages (${all.length} rows). '
          'Raise maxPages or add real pagination to the screen.',
        );
      }
      _subscribers = all;
      return _subscribers;
    } catch (e) {
      debugPrint('Error fetching plan subscribers: $e');
      _subscriberError = _readableError(e);
      _subscribers = [];
      return const [];
    } finally {
      _isLoadingSubscribers = false;
      notifyListeners();
    }
  }

  void clearSubscribers() {
    _subscribers = [];
    _subscriberError = null;
    _subscribersTruncated = false;
    notifyListeners();
  }

  /// Turns a transport error into something a chef can act on.
  ///
  /// A raw `DioException` string is noise on a phone screen. The server's
  /// `detail` is already human-written, so prefer it.
  String _readableError(Object e) {
    if (e is ApiException) return e.message;
    if (e is StateError) return e.message;
    final text = e.toString();
    // Strip the exception type prefix so the screen shows just the message.
    return text.replaceFirst(RegExp(r'^\w+Exception: '), '').trim();
  }

  /// True now that the chef write endpoints exist.
  bool get canPersistPlans => true;
}