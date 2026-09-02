import 'package:flutter/foundation.dart';
import '../features/customer/presentation/providers/cart_provider.dart';
import '../features/customer/presentation/providers/kitchen_provider.dart';
import '../features/customer/domain/models/menu_item_model.dart';
import '../features/customer/domain/models/kitchen_model.dart';

/// Result of searching for an item in the MEALIN backend.
class SearchResult {
  final MenuItemModel menuItem;
  final KitchenModel kitchen;

  const SearchResult({
    required this.menuItem,
    required this.kitchen,
  });
}

/// Result of adding an item to cart via voice.
enum CartAddResult {
  success,
  cartConflict,
  itemUnavailable,
  kitchenNotFound,
  itemNotFound,
  networkError,
  unknownError,
}

/// Handles voice command execution — searching menus and modifying cart.
///
/// Does NOT care whether the command came from regex or Gemini parser.
/// Only interacts with existing CartProvider and KitchenProvider.
class MealVoiceOrderHandler {
  final KitchenProvider _kitchenProvider;
  final CartProvider _cartProvider;

  MealVoiceOrderHandler({
    required KitchenProvider kitchenProvider,
    required CartProvider cartProvider,
  })  : _kitchenProvider = kitchenProvider,
        _cartProvider = cartProvider;

  /// Search for a menu item across available kitchens.
  ///
  /// If [restaurantName] is provided, searches that specific kitchen first.
  /// Returns the best match or null if not found.
  Future<SearchResult?> searchItem({
    required String itemName,
    String? restaurantName,
  }) async {
    try {
      // 1. If restaurant specified, search that kitchen first
      if (restaurantName != null && restaurantName.isNotEmpty) {
        await _kitchenProvider.searchKitchens(restaurantName);
        for (final kitchen in _kitchenProvider.kitchens) {
          if (_matchesBusinessName(kitchen.name, restaurantName)) {
            await _kitchenProvider.fetchMenuItems(kitchen.id);
            final match = _findBestMatch(_kitchenProvider.menuItems, itemName);
            if (match != null) {
              return SearchResult(menuItem: match, kitchen: kitchen);
            }
          }
        }
      }

      // 2. Search all available kitchens
      for (final kitchen in _kitchenProvider.kitchens) {
        await _kitchenProvider.fetchMenuItems(kitchen.id);
        final match = _findBestMatch(_kitchenProvider.menuItems, itemName);
        if (match != null) {
          return SearchResult(menuItem: match, kitchen: kitchen);
        }
      }

      // 3. Try search API directly
      await _kitchenProvider.searchKitchens(itemName);
      for (final kitchen in _kitchenProvider.kitchens) {
        await _kitchenProvider.fetchMenuItems(kitchen.id);
        final match = _findBestMatch(_kitchenProvider.menuItems, itemName);
        if (match != null) {
          return SearchResult(menuItem: match, kitchen: kitchen);
        }
      }

      return null;
    } catch (e) {
      debugPrint('[MEAL OrderHandler] Search error: $e');
      return null;
    }
  }

  /// Add an item to the cart.
  Future<CartAddResult> addToCart({
    required SearchResult searchResult,
    required int quantity,
  }) async {
    try {
      final item = searchResult.menuItem;
      final kitchen = searchResult.kitchen;

      if (!item.isAvailable) {
        return CartAddResult.itemUnavailable;
      }

      // Check cart compatibility
      final currentCart = _cartProvider.cart;
      if (currentCart != null && currentCart.isNotEmpty) {
        if (currentCart.kitchenId != kitchen.id) {
          return CartAddResult.cartConflict;
        }
      }

      await _cartProvider.addItem(
        menuItemId: item.id,
        quantity: quantity,
      );

      return CartAddResult.success;
    } catch (e) {
      debugPrint('[MEAL OrderHandler] Add to cart error: $e');
      return CartAddResult.networkError;
    }
  }

  /// Clear the current cart.
  Future<void> clearCart() async {
    try {
      await _cartProvider.clearCart();
    } catch (e) {
      debugPrint('[MEAL OrderHandler] Clear cart error: $e');
    }
  }

  double get cartTotal => _cartProvider.subtotal;
  int get cartItemCount => _cartProvider.itemCount;
  bool get isCartEmpty => _cartProvider.isEmpty;

  /// Find the best matching menu item from a list.
  MenuItemModel? _findBestMatch(List<MenuItemModel> items, String query) {
    if (items.isEmpty) return null;

    final lowerQuery = query.toLowerCase().trim();

    // Exact name match
    for (final item in items) {
      if (item.name.toLowerCase() == lowerQuery) {
        return item;
      }
    }

    // Contains match
    for (final item in items) {
      final itemName = item.name.toLowerCase();
      if (itemName.contains(lowerQuery) || lowerQuery.contains(itemName)) {
        return item;
      }
    }

    // Word-level match
    final queryWords = lowerQuery.split(RegExp(r'\s+'));
    MenuItemModel? bestMatch;
    int bestScore = 0;

    for (final item in items) {
      final itemWords = item.name.toLowerCase().split(RegExp(r'\s+'));
      int score = 0;
      for (final qw in queryWords) {
        for (final iw in itemWords) {
          if (iw == qw || iw.contains(qw) || qw.contains(iw)) {
            score++;
          }
        }
      }
      if (score > bestScore) {
        bestScore = score;
        bestMatch = item;
      }
    }

    return bestScore > 0 ? bestMatch : null;
  }

  /// Check if a kitchen name matches the user-specified business name.
  bool _matchesBusinessName(String kitchenName, String query) {
    final lowerKitchen = kitchenName.toLowerCase();
    final lowerQuery = query.toLowerCase();

    if (lowerKitchen.contains(lowerQuery) || lowerQuery.contains(lowerKitchen)) {
      return true;
    }

    final queryWords = lowerQuery.split(RegExp(r'\s+'));
    int matchCount = 0;
    for (final word in queryWords) {
      if (lowerKitchen.contains(word)) matchCount++;
    }
    return matchCount >= queryWords.length ~/ 2;
  }
}
