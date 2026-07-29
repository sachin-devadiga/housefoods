import '../models/user_model.dart';
import '../models/address_model.dart';

abstract class UserRepository {
  Future<void> saveUser(UserModel user);
  Future<UserModel?> getUser(String uid);
  Future<void> updateUser(UserModel user);
  Future<void> updateAddresses(String uid, List<AddressModel> addresses);
  Future<void> toggleFavorite(String uid, String kitchenId, bool isFavorite);
}
