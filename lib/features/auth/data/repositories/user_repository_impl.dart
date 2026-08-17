import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/token_service.dart';
import '../../domain/models/user_model.dart';
import '../../domain/models/address_model.dart';
import '../../domain/repositories/user_repository.dart';

class UserRepositoryImpl implements UserRepository {
  final ApiService _api;
  final TokenService _tokenService;

  UserRepositoryImpl({ApiService? apiService, TokenService? tokenService})
      : _api = apiService ?? ApiService(baseUrl: AppConstants.apiBaseUrl),
        _tokenService = tokenService ?? TokenService();

  Future<void> _ensureAuthenticated() async {
    final token = await _tokenService.getAccessToken();
    if (token != null) {
      _api.setToken(token);
    }
  }

  @override
  Future<void> saveUser(UserModel user) async {
    await _ensureAuthenticated();
    await _api.post(AppConstants.profileSetupEndpoint, body: {
      'email': user.email,
      'name': user.name,
      'role': user.role,
      'phone': user.phoneNumber,
      'avatar_url': user.profileImage,
    });
  }

  @override
  Future<UserModel?> getUser(String uid) async {
    await _ensureAuthenticated();
    try {
      final data = await _api.get('${AppConstants.userByUidEndpoint}/$uid/');
      if (data['uid'] != null) {
        return UserModel.fromMap(data);
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<void> updateUser(UserModel user) async {
    await _ensureAuthenticated();
    final body = <String, dynamic>{
      'email': user.email,
      'name': user.name,
      'phone': user.phoneNumber,
    };
    if (user.profileImage != null && user.profileImage!.isNotEmpty) {
      body['avatar_url'] = user.profileImage;
    }
    await _api.put(AppConstants.profileEndpoint, body: body);
  }

  @override
  Future<void> updateAddresses(String uid, List<AddressModel> addresses) async {
    await _ensureAuthenticated();
    if (addresses.isNotEmpty) {
      final lastAddress = addresses.last;
      await _api.post(AppConstants.addressesEndpoint, body: lastAddress.toMap());
    }
  }

  @override
  Future<void> toggleFavorite(String uid, String kitchenId, bool isFavorite) async {
    await _ensureAuthenticated();
    await _api.post(
      '${AppConstants.toggleFavoriteEndpoint}/$kitchenId/',
    );
  }
}
