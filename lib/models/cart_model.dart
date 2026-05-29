/// Cart models for the KilifiHub shopping cart
///
/// Maps to the cart data returned by `GET /kilifi/v1/cart`,
/// `POST /kilifi/v1/cart/add`, and `POST /kilifi/v1/cart/remove`.
/// Cart is stored server-side in user meta `_kilifi_cart`.

/// A single item in the cart
class CartItem {
  final String cartItemKey;
  final int productId;
  final String name;
  final String price;
  final int quantity;
  final String imageUrl;
  final String storeName;
  final int storeId;

  CartItem({
    required this.cartItemKey,
    required this.productId,
    required this.name,
    this.price = '0',
    this.quantity = 1,
    this.imageUrl = '',
    this.storeName = '',
    this.storeId = 0,
  });

  /// Create from WordPress API JSON response
  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      cartItemKey: json['cart_item_key'] as String? ?? '',
      productId: json['product_id'] as int? ?? 0,
      name: json['name'] as String? ?? 'Item',
      price: json['price']?.toString() ?? '0',
      quantity: json['quantity'] as int? ?? 1,
      imageUrl: json['image_url'] as String? ?? '',
      storeName: json['store_name'] as String? ?? '',
      storeId: json['store_id'] as int? ?? 0,
    );
  }

  /// Serialize to JSON for local storage
  Map<String, dynamic> toJson() {
    return {
      'cart_item_key': cartItemKey,
      'product_id': productId,
      'name': name,
      'price': price,
      'quantity': quantity,
      'image_url': imageUrl,
      'store_name': storeName,
      'store_id': storeId,
    };
  }

  /// Line total (price × quantity)
  double get lineTotal => (double.tryParse(price) ?? 0) * quantity;

  /// Formatted line total
  String get displayLineTotal => 'KSh ${lineTotal.toStringAsFixed(0)}';
}

/// The complete cart with items and totals
class CartModel {
  final List<CartItem> items;
  final double subtotal;
  final double deliveryFee;
  final double total;
  final int itemCount;

  CartModel({
    this.items = const [],
    this.subtotal = 0,
    this.deliveryFee = 0,
    this.total = 0,
    this.itemCount = 0,
  });

  /// Create from WordPress API JSON response
  factory CartModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return CartModel(
      items: rawItems
          .map((e) => CartItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      subtotal:
          double.tryParse(json['subtotal']?.toString() ?? '0') ?? 0,
      deliveryFee:
          double.tryParse(json['delivery_fee']?.toString() ?? '0') ?? 0,
      total: double.tryParse(json['total']?.toString() ?? '0') ?? 0,
      itemCount: json['item_count'] as int? ?? 0,
    );
  }

  /// Serialize to JSON for local storage
  Map<String, dynamic> toJson() {
    return {
      'items': items.map((e) => e.toJson()).toList(),
      'subtotal': subtotal,
      'delivery_fee': deliveryFee,
      'total': total,
      'item_count': itemCount,
    };
  }

  /// Whether the cart is empty
  bool get isEmpty => items.isEmpty;

  /// Whether the cart has items
  bool get isNotEmpty => items.isNotEmpty;

  /// Formatted subtotal
  String get displaySubtotal => 'KSh ${subtotal.toStringAsFixed(0)}';

  /// Formatted delivery fee
  String get displayDeliveryFee => 'KSh ${deliveryFee.toStringAsFixed(0)}';

  /// Formatted total
  String get displayTotal => 'KSh ${total.toStringAsFixed(0)}';

  /// Get unique store IDs in the cart
  List<int> get storeIds =>
      items.map((item) => item.storeId).toSet().toList();
}
