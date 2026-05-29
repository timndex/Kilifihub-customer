/// Store model representing a WCFM vendor/store
///
/// Maps to the store data returned by `GET /kilifi/v1/stores`
/// and `GET /kilifi/v1/stores/{vendor_id}`.
class StoreModel {
  final int vendorId;
  final String storeName;
  final String storeSlug;
  final String storeAvatar;
  final String storeBanner;
  final String storeAddress;
  final String storePhone;
  final String category;
  final String categoryLabel;
  final double rating;
  final bool isOpen;
  final String deliveryTime;
  final double minOrder;
  final String description;

  StoreModel({
    required this.vendorId,
    required this.storeName,
    this.storeSlug = '',
    this.storeAvatar = '',
    this.storeBanner = '',
    this.storeAddress = '',
    this.storePhone = '',
    this.category = '',
    this.categoryLabel = 'Store',
    this.rating = 0,
    this.isOpen = true,
    this.deliveryTime = '30-45 min',
    this.minOrder = 0,
    this.description = '',
  });

  /// Create from WordPress API JSON response
  factory StoreModel.fromJson(Map<String, dynamic> json) {
    return StoreModel(
      vendorId: json['vendor_id'] as int? ?? 0,
      storeName: json['store_name'] as String? ?? 'Unknown Store',
      storeSlug: json['store_slug'] as String? ?? '',
      storeAvatar: json['store_avatar'] as String? ?? '',
      storeBanner: json['store_banner'] as String? ?? '',
      storeAddress: json['store_address'] as String? ?? '',
      storePhone: json['store_phone'] as String? ?? '',
      category: json['category'] as String? ?? '',
      categoryLabel: json['category_label'] as String? ?? 'Store',
      rating: double.tryParse(json['rating']?.toString() ?? '0') ?? 0,
      isOpen: json['is_open'] as bool? ?? true,
      deliveryTime: json['delivery_time'] as String? ?? '30-45 min',
      minOrder: double.tryParse(json['min_order']?.toString() ?? '0') ?? 0,
      description: json['description'] as String? ?? '',
    );
  }

  /// Serialize to JSON for local storage
  Map<String, dynamic> toJson() {
    return {
      'vendor_id': vendorId,
      'store_name': storeName,
      'store_slug': storeSlug,
      'store_avatar': storeAvatar,
      'store_banner': storeBanner,
      'store_address': storeAddress,
      'store_phone': storePhone,
      'category': category,
      'category_label': categoryLabel,
      'rating': rating,
      'is_open': isOpen,
      'delivery_time': deliveryTime,
      'min_order': minOrder,
      'description': description,
    };
  }

  /// Whether this store has a banner image
  bool get hasBanner => storeBanner.isNotEmpty;

  /// Whether this store has an avatar image
  bool get hasAvatar => storeAvatar.isNotEmpty;

  /// Formatted rating string (e.g., "4.5")
  String get ratingDisplay => rating.toStringAsFixed(1);

  /// Formatted minimum order (e.g., "KSh 200")
  String get minOrderDisplay => 'KSh ${minOrder.toStringAsFixed(0)}';
}
