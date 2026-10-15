import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/token_service.dart';
import '../../domain/models/meal_plan_model.dart';

/// Chef-side state for subscription plans.
///
/// Known API gap: there is **no** endpoint a chef can use to list, create or
/// update their own plans, and none to list their subscribers
/// (`backend/api/subscription_views.py` is entirely customer-scoped). So:
///   * [fetchPlans] calls the only genuine read available — the public plan
///     list — and filters client-side to this kitchen. If the backend is
///     unreachable or returns nothing, the UI shows an honest empty state.
///   * [savePlan] is the isolated write seam. It is wired and ready but does
///     not call anything yet, and says so instead of pretending to persist.
///     TODO(backend): point this at the chef plan CRUD endpoint when it lands.
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

  static String slotKey(int dayOfWeek, String mealType) => '$dayOfWeek|$mealType';

  void reset() {
    _plans = [];
    _draft = null;
    _draftSlots.clear();
    _draftPrices.clear();
    _isLoading = false;
    _isSaving = false;
    _error = null;
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
      final data = await _api.get(AppConstants.subscriptionPlansEndpoint);
      final results = (data['results'] as List?) ?? (data['data'] as List?) ?? [];
      _plans = results
          .whereType<Map<String, dynamic>>()
          .map(MealPlan.fromMap)
          .where((p) => p.kitchenId == kitchenId)
          .toList();
    } catch (e) {
      debugPrint("Error fetching subscription plans: $e");
      _error = e.toString();
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

  /// Write seam for the whole plan (grid + prices).
  ///
  /// Intentionally a no-op: the chef plan endpoints do not exist yet, so this
  /// must not pretend to persist. Kept isolated so wiring it up later is a
  /// one-method change with no UI impact.
  ///
  /// TODO(backend): POST to the chef plan endpoint
  /// (AppConstants.chefMealPlansEndpoint) with `plan.toWriteJson()`, then
  /// `await fetchPlans(kitchenId)`. The payload is already in
  /// `MealPlanWriteSerializer` shape.
  Future<void> savePlan(MealPlan plan) async {
    _isSaving = true;
    _error = null;
    notifyListeners();
    try {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      debugPrint(
          'savePlan: not persisted — chef plan API not available yet. Plan "${plan.name}" held in memory.');
      _draft = plan;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// True when the current API surface cannot serve chef plan writes.
  /// The builder uses this to label its save affordance honestly.
  bool get canPersistPlans => false;
}