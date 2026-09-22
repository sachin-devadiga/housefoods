import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/api_service.dart';
import '../../../../features/customer/domain/models/kitchen_model.dart';
import '../../../../features/customer/domain/models/menu_item_model.dart';
import '../../../../features/customer/domain/repositories/kitchen_repository.dart';

class KitchenRepositoryImpl implements KitchenRepository {
  final ApiService _api;

  KitchenRepositoryImpl({ApiService? apiService})
      : _api = apiService ?? ApiService(baseUrl: AppConstants.apiBaseUrl);

  @override
  Future<List<Map<String, dynamic>>> getKitchensPaged({
    required int limit,
    int page = 1,
    String? categoryId,
    bool isVegOnly = false,
    double minRating = 0,
  }) async {
    final params = <String, dynamic>{'page': page.toString()};
    if (categoryId != null && categoryId != 'all') {
      params['category'] = categoryId;
    }
    if (isVegOnly) {
      params['is_veg'] = 'true';
    }
    if (minRating > 0) {
      params['min_rating'] = minRating.toString();
    }
    final data = await _api.get(AppConstants.kitchensEndpoint, queryParams: params);
    final list = (data['data'] as List?) ?? [];
    return list.cast<Map<String, dynamic>>();
  }

  @override
  Future<List<KitchenModel>> getAllKitchens() async {
    final data = await _api.get(AppConstants.kitchensEndpoint);
    final list = (data['data'] as List?) ?? [];
    return list
        .map((e) => KitchenModel.fromMap(e as Map<String, dynamic>, e['id'].toString()))
        .toList();
  }

  @override
  Future<List<KitchenModel>> searchKitchens(String query) async {
    final data = await _api.get(AppConstants.kitchensEndpoint, queryParams: {'search': query});
    final list = (data['data'] as List?) ?? [];
    return list
        .map((e) => KitchenModel.fromMap(e as Map<String, dynamic>, e['id'].toString()))
        .toList();
  }

  @override
  Future<List<MenuItemModel>> getMenuItems(String kitchenId) async {
    final data = await _api.get('${AppConstants.menuItemsEndpoint}/$kitchenId/menu-items/');
    final list = (data['data'] as List?) ?? [];
    return list
        .map((e) => MenuItemModel.fromMap(e as Map<String, dynamic>, e['id'].toString()))
        .toList();
  }
}
