/// Cart provider for the KilifiHub Customer App
///
/// Manages the shopping cart state using ChangeNotifier.
/// All cart mutations are synced with the server-side cart
/// stored in WordPress user meta `_kilifi_cart`.

import 'package:flutter/foundation.dart';

import '../models/cart_model.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

class CartProvider extends ChangeNotifier {
  final ApiService _api = ApiService.instance;
  final StorageService _storage = StorageService.instance;

  CartModel? _cart;
  bool _isLoading = false;
  String? _error;

  // ── Getters ──

  /// The current cart state
  CartModel? get cart => _cart;

  /// Whether a cart operation is in progress
  bool get isLoading => _isLoading;

  /// Last error message, if any
  String? get error => _error;

  /// Number of items in the cart
  int get itemCount => _cart?.itemCount ?? 0;

  /// Cart subtotal
  double get subtotal => _cart?.subtotal ?? 0;

  /// Cart total (subtotal + delivery fee)
  double get total => _cart?.total ?? 0;

  /// Delivery fee
  double get deliveryFee => _cart?.deliveryFee ?? 0;

  /// Whether the cart is empty
  bool get isEmpty => _cart?.isEmpty ?? true;

  /// Whether the cart has items
  bool get isNotEmpty => _cart?.isNotEmpty ?? false;

  /// Formatted subtotal
  String get displaySubtotal => _cart?.displaySubtotal ?? 'KSh 0';

  /// Formatted total
  String get displayTotal => _cart?.displayTotal ?? 'KSh 0';

  /// Formatted delivery fee
  String get displayDeliveryFee =>
      _cart?.displayDeliveryFee ?? 'KSh 0';

  // ── Cart Operations ──

  /// Add an item to the cart
  ///
  /// Calls the API, updates local state, and caches the cart.
  Future<bool> addItem(int productId, int quantity) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final cart = await _api.addToCart(productId, quantity);
      _cart = cart;
      await _storage.saveCartData(cart);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = _extractError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Remove an item from the cart
  ///
  /// Calls the API, updates local state, and caches the cart.
  Future<bool> removeItem(String cartItemKey) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final cart = await _api.removeFromCart(cartItemKey);
      _cart = cart;
      await _storage.saveCartData(cart);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = _extractError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Refresh the cart from the API
  ///
  /// Useful when returning to the cart screen or after
  /// a checkout to verify the cart is cleared.
  Future<void> refreshCart() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final cart = await _api.getCart();
      _cart = cart;
      await _storage.saveCartData(cart);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = _extractError(e);
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load cached cart data for offline display
  ///
  /// Call this on app startup to show cached cart data
  /// before the API response arrives.
  Future<void> loadCachedCart() async {
    final cachedCart = await _storage.getCartData();
    if (cachedCart != null) {
      _cart = cachedCart;
      notifyListeners();
    }
  }

  /// Clear the local cart state
  ///
  /// Does NOT call the API — used after a successful checkout
  /// where the server has already cleared the cart.
  void clearCart() {
    _cart = CartModel();
    _storage.saveCartData(_cart!);
    notifyListeners();
  }

  /// Check if a specific product is in the cart
  bool containsProduct(int productId) {
    return _cart?.items.any((item) => item.productId == productId) ?? false;
  }

  /// Get the quantity of a specific product in the cart
  int getProductQuantity(int productId) {
    final item = _cart?.items
        .where((item) => item.productId == productId)
        .firstOrNull;
    return item?.quantity ?? 0;
  }

  // ── Error Handling ──

  String _extractError(dynamic e) {
    final errorStr = e.toString();

    if (errorStr.contains('401')) {
      return 'Please log in to manage your cart.';
    }
    if (errorStr.contains('SocketException') ||
        errorStr.contains('Failed host lookup')) {
      return 'No internet connection. Showing cached cart.';
    }
    if (errorStr.contains('TimeoutException') ||
        errorStr.contains('timed out')) {
      return 'Connection timed out. Please try again.';
    }

    return 'Failed to update cart. Please try again.';
  }
}
