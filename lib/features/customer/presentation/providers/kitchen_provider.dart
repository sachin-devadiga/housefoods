import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/prefs_service.dart';
import '../../../../features/customer/domain/models/kitchen_model.dart';
import '../../../../features/customer/domain/models/subscription_plan_model.dart';
import '../../../../features/customer/domain/repositories/kitchen_repository.dart';
import '../../../../features/chef/domain/models/daily_menu_model.dart';

class KitchenProvider extends ChangeNotifier {
  final KitchenRepository _repository;
  final LocationService _locationService = LocationService();

  KitchenProvider(this._repository);

  List<KitchenModel> _kitchens = [];
  List<KitchenModel> get kitchens => _kitchens;

  List<KitchenModel> get topRatedKitchens =>
      _kitchens.where((k) => k.rating >= 4.5).take(5).toList();

  List<KitchenModel> get healthyKitchens =>
      _kitchens.where((k) => k.categories.contains('healthy')).take(5).toList();

  int _currentPage = 0;
  bool _hasMore = true;
  bool get hasMore => _hasMore;
  final int _pageSize = 10;

  final Map<String, double> _kitchenDistances = {};

  bool _isVegOnly = false;
  bool get isVegOnly => _isVegOnly;

  double _minRating = 0.0;
  double get minRating => _minRating;

  String _sortBy = 'proximity';
  String get sortBy => _sortBy;

  String _selectedCategoryId = 'all';
  String get selectedCategoryId => _selectedCategoryId;

  List<String> _recentSearches = [];
  List<String> get recentSearches => _recentSearches;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isPlansLoading = false;
  bool get isPlansLoading => _isPlansLoading;

  bool _isMenusLoading = false;
  bool get isMenusLoading => _isMenusLoading;

  String? _error;
  String? get error => _error;

  Map<DateTime, DailyMenuModel> _dailyMenus = {};
  Map<DateTime, DailyMenuModel> get dailyMenus => _dailyMenus;

  List<SubscriptionPlanModel> _plans = [];
  List<SubscriptionPlanModel> get plans => _plans;

  Future<void> fetchKitchens() async {
    _isLoading = true;
    _error = null;
    _currentPage = 0;
    _hasMore = true;
    _kitchens = [];
    notifyListeners();

    await _fetchData();
  }

  Future<void> fetchMoreKitchens() async {
    if (!_hasMore || _isLoading) return;
    _isLoading = true;
    notifyListeners();
    await _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final rawKitchens = await _repository.getKitchensPaged(
        limit: _pageSize,
        page: _currentPage > 0 ? _currentPage + 1 : 1,
        categoryId: _selectedCategoryId,
        isVegOnly: _isVegOnly,
        minRating: _minRating,
      );

      var newKitchens = rawKitchens
          .map((e) => KitchenModel.fromMap(e, e['id']?.toString() ?? ''))
          .toList();

      if (_isVegOnly) {
        newKitchens = newKitchens.where((k) => k.isVeg).toList();
      }
      if (_minRating > 0) {
        newKitchens = newKitchens.where((k) => k.rating >= _minRating).toList();
      }

      if (newKitchens.length < _pageSize) _hasMore = false;
      _currentPage++;

      Position? userPos;
      try {
        userPos = await _locationService.getCurrentLocation();
      } catch (e) {
        debugPrint("Location error: $e");
      }

      if (userPos != null) {
        for (var kitchen in newKitchens) {
          _kitchenDistances[kitchen.id] = _locationService.calculateDistance(
            userPos.latitude, userPos.longitude, kitchen.latitude, kitchen.longitude,
          );
        }
      }

      _kitchens.addAll(newKitchens);
      _applyFiltersAndSorting();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _applyFiltersAndSorting() {
    if (_sortBy == 'proximity') {
      _kitchens.sort((a, b) {
        final distA = _kitchenDistances[a.id] ?? double.infinity;
        final distB = _kitchenDistances[b.id] ?? double.infinity;
        return distA.compareTo(distB);
      });
    } else if (_sortBy == 'rating') {
      _kitchens.sort((a, b) => b.rating.compareTo(a.rating));
    }
    notifyListeners();
  }

  Future<void> loadSearchHistory() async {
    _recentSearches = await PrefsService.getSearchHistory();
    notifyListeners();
  }

  Future<void> clearHistory() async {
    await PrefsService.clearSearchHistory();
    _recentSearches = [];
    notifyListeners();
  }

  void setCategory(String categoryId) {
    _selectedCategoryId = categoryId;
    fetchKitchens();
  }

  void setVegFilter(bool val) {
    _isVegOnly = val;
    fetchKitchens();
  }

  void setMinRating(double val) {
    _minRating = val;
    fetchKitchens();
  }

  void setSortBy(String val) {
    _sortBy = val;
    _applyFiltersAndSorting();
  }

  double? getDistanceTo(String kitchenId) => _kitchenDistances[kitchenId];

  Future<void> fetchSubscriptionPlans(String kitchenId) async {
    _isPlansLoading = true; _plans = []; notifyListeners();
    try {
      _plans = await _repository.getSubscriptionPlans(kitchenId);
    } catch (e) { debugPrint("Plans error: $e"); } finally { _isPlansLoading = false; notifyListeners(); }
  }

  Future<void> fetchDailyMenus(String kitchenId) async {
    _isMenusLoading = true; _dailyMenus = {}; notifyListeners();
    try {
      final menus = await _repository.getDailyMenus(kitchenId);
      _dailyMenus = { for (var menu in menus) DateTime(menu.date.year, menu.date.month, menu.date.day): menu };
    } catch (e) { debugPrint("Menus error: $e"); } finally { _isMenusLoading = false; notifyListeners(); }
  }

  Future<void> searchKitchens(String query) async {
    if (query.isEmpty) { fetchKitchens(); return; }
    await PrefsService.saveSearchQuery(query);
    await loadSearchHistory();
    _isLoading = true; _kitchens = []; notifyListeners();
    try {
      final results = await _repository.searchKitchens(query);
      _kitchens = results;
      _applyFiltersAndSorting();
    } catch (e) { debugPrint("Search error: $e"); } finally { _isLoading = false; notifyListeners(); }
  }
}
