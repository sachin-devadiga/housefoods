import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/api_service.dart';
import '../../domain/models/cart_model.dart';

class CartProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService(baseUrl: AppConstants.apiBaseUrl);
  CartModel? _cart;
  bool _isLoading = false;
  String? _error;

  CartModel? get cart => _cart;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get itemCount => _cart?.totalItemCount ?? 0;
  double get subtotal => _cart?.subtotal ?? 0.0;
  bool get isEmpty => _cart?.isEmpty ?? true;
  bool get isNotEmpty => _cart?.isNotEmpty ?? false;

  void setToken(String token) {
    _apiService.setToken(token);
  }

  Future<void> loadCart() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.get(AppConstants.cartEndpoint);
      _cart = CartModel.fromMap(response);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addItem({
    required String menuItemId,
    int quantity = 1,
    String specialInstructions = '',
  }) async {
    _error = null;

    try {
      final response = await _apiService.post(
        AppConstants.cartItemsEndpoint,
        body: {
          'menu_item': menuItemId,
          'quantity': quantity,
          'special_instructions': specialInstructions,
        },
      );
      _cart = CartModel.fromMap(response);
    } catch (e) {
      _error = e.toString();
    } finally {
      notifyListeners();
    }
  }

  Future<void> updateItemQuantity(String cartItemId, int quantity) async {
    _error = null;

    try {
      if (quantity <= 0) {
        await _apiService.delete('${AppConstants.cartItemsEndpoint}$cartItemId/');
      } else {
        await _apiService.put(
          '${AppConstants.cartItemsEndpoint}$cartItemId/',
          body: {'quantity': quantity},
        );
      }
      await loadCart();
    } catch (e) {
      _error = e.toString();
    } finally {
      notifyListeners();
    }
  }

  Future<void> removeItem(String cartItemId) async {
    _error = null;

    try {
      await _apiService.delete('${AppConstants.cartItemsEndpoint}$cartItemId/');
      await loadCart();
    } catch (e) {
      _error = e.toString();
    } finally {
      notifyListeners();
    }
  }

  Future<void> clearCart() async {
    _error = null;

    try {
      await _apiService.delete(AppConstants.cartClearEndpoint);
      _cart = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      notifyListeners();
    }
  }
}
