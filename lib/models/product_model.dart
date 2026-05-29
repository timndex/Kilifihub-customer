/// Product model representing a WooCommerce product
///
/// Maps to the product data returned by `GET /kilifi/v1/stores/{id}/products`
/// and included in store detail responses.
class ProductModel {
  final int id;
  final String name;
  final String slug;
  final String price;
  final String regularPrice;
  final String? salePrice;
  final String imageUrl;
  final String shortDescription;
  final List<String> categories;
  final bool inStock;
  final bool manageStock;
  final int? stockQuantity;
  final String type;

  ProductModel({
    required this.id,
    required this.name,
    this.slug = '',
    this.price = '0',
    this.regularPrice = '',
    this.salePrice,
    this.imageUrl = '',
    this.shortDescription = '',
    this.categories = const [],
    this.inStock = true,
    this.manageStock = false,
    this.stockQuantity,
    this.type = 'simple',
  });

  /// Create from WordPress API JSON response
  factory ProductModel.fromJson(Map<String, dynamic> json) {
    // categories can be a List of strings or a List of maps with 'slug' key
    List<String> categorySlugs = [];
    final rawCats = json['categories'];
    if (rawCats is List) {
      for (final cat in rawCats) {
        if (cat is String) {
          categorySlugs.add(cat);
        } else if (cat is Map<String, dynamic>) {
          categorySlugs.add(cat['slug'] as String? ?? cat['name'] as String? ?? '');
        }
      }
    }

    return ProductModel(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? 'Product',
      slug: json['slug'] as String? ?? '',
      price: json['price']?.toString() ?? '0',
      regularPrice: json['regular_price']?.toString() ?? '',
      salePrice: json['sale_price'] as String?,
      imageUrl: json['image_url'] as String? ?? '',
      shortDescription: json['short_description'] as String? ?? '',
      categories: categorySlugs,
      inStock: json['in_stock'] as bool? ?? true,
      manageStock: json['manage_stock'] as bool? ?? false,
      stockQuantity: json['stock_quantity'] as int?,
      type: json['type'] as String? ?? 'simple',
    );
  }

  /// Serialize to JSON for local storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'price': price,
      'regular_price': regularPrice,
      'sale_price': salePrice,
      'image_url': imageUrl,
      'short_description': shortDescription,
      'categories': categories,
      'in_stock': inStock,
      'manage_stock': manageStock,
      'stock_quantity': stockQuantity,
      'type': type,
    };
  }

  /// Whether this product is currently on sale
  bool get isOnSale =>
      salePrice != null && salePrice!.isNotEmpty && salePrice != price;

  /// Formatted display price (e.g., "KSh 250")
  String get displayPrice => 'KSh $price';

  /// Formatted regular price (e.g., "KSh 350")
  String get displayRegularPrice => 'KSh $regularPrice';

  /// Whether this product has an image
  bool get hasImage => imageUrl.isNotEmpty;

  /// Whether this product is out of stock
  bool get isOutOfStock => !inStock;

  /// Numeric price value for calculations
  double get priceValue => double.tryParse(price) ?? 0;
}
