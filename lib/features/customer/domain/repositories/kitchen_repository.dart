import '../../../customer/domain/models/kitchen_model.dart';
import '../../../customer/domain/models/subscription_plan_model.dart';
import '../../../chef/domain/models/daily_menu_model.dart';

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
  Future<List<SubscriptionPlanModel>> getSubscriptionPlans(String kitchenId);
  Future<List<DailyMenuModel>> getDailyMenus(String kitchenId);
}
