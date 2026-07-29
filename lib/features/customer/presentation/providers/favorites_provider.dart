import 'package:flutter/material.dart';
import '../../../../features/auth/domain/repositories/user_repository.dart';

class FavoritesProvider extends ChangeNotifier {
  final UserRepository _userRepository;
  List<String> _favoriteKitchenIds = [];

  FavoritesProvider(this._userRepository);

  List<String> get favoriteKitchenIds => _favoriteKitchenIds;

  /// Load favorites for the given user
  Future<void> loadFavorites(String uid) async {
    final user = await _userRepository.getUser(uid);
    if (user != null) {
      _favoriteKitchenIds = user.favoriteKitchenIds;
      notifyListeners();
    }
  }

  /// Check if a specific kitchen is favorited
  bool isFavorite(String kitchenId) {
    return _favoriteKitchenIds.contains(kitchenId);
  }

  /// Toggle favorite status locally and in Firestore
  Future<void> toggleFavorite(String uid, String kitchenId) async {
    final currentlyFavorite = _favoriteKitchenIds.contains(kitchenId);
    
    if (currentlyFavorite) {
      _favoriteKitchenIds.remove(kitchenId);
    } else {
      _favoriteKitchenIds.add(kitchenId);
    }
    notifyListeners();

    try {
      await _userRepository.toggleFavorite(uid, kitchenId, !currentlyFavorite);
    } catch (e) {
      // Rollback on failure
      if (currentlyFavorite) {
        _favoriteKitchenIds.add(kitchenId);
      } else {
        _favoriteKitchenIds.remove(kitchenId);
      }
      notifyListeners();
      debugPrint("Error toggling favorite: $e");
    }
  }
}
