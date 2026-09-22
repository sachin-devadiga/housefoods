import '../../../customer/domain/models/kitchen_model.dart';
import '../../../customer/domain/models/menu_item_model.dart';

abstract class KitchenRepository {
  Future<List<Map<String, dynamic>>> getKitchensPaged({
    required int limit,
    int page = 1,
    String? categoryId,
    bool isVegOnly = false,
    double minRating = 0,
  });

  Future<List<KitchenModel>> getAllKitchens();
  Future<List<KitchenModel>> searchKitchens(String query);
  Future<List<MenuItemModel>> getMenuItems(String kitchenId);
}
