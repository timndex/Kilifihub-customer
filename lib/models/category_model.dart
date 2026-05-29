/// Category model representing a store category (hotel, pharmacy, etc.)
///
/// Maps to the response from `GET /kilifi/v1/categories`.
/// Categories are defined in `kilifihub-store-categories.php` and
/// returned as an array under the `categories` key.
class CategoryModel {
  final String slug;
  final String label;
  final String singular;
  final String icon;
  final String color;
  final String description;
  final String heroText;
  final String searchPlaceholder;
  final String deliveryTimeAvg;
  final double minOrder;
  final bool ageVerification;
  final bool prescriptionRequired;
  final bool isPackageDelivery;
  final bool active;

  CategoryModel({
    required this.slug,
    required this.label,
    required this.singular,
    this.icon = '',
    this.color = '#E23744',
    this.description = '',
    this.heroText = '',
    this.searchPlaceholder = 'Search...',
    this.deliveryTimeAvg = '30-45 min',
    this.minOrder = 0,
    this.ageVerification = false,
    this.prescriptionRequired = false,
    this.isPackageDelivery = false,
    this.active = true,
  });

  /// Create from WordPress API JSON response
  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      slug: json['slug'] as String? ?? '',
      label: json['label'] as String? ?? '',
      singular: json['singular'] as String? ?? '',
      icon: json['icon'] as String? ?? '',
      color: json['color'] as String? ?? '#E23744',
      description: json['description'] as String? ?? '',
      heroText: json['hero_text'] as String? ?? '',
      searchPlaceholder: json['search_placeholder'] as String? ?? 'Search...',
      deliveryTimeAvg: json['delivery_time_avg'] as String? ?? '30-45 min',
      minOrder: double.tryParse(json['min_order']?.toString() ?? '0') ?? 0,
      ageVerification: json['age_verification'] as bool? ?? false,
      prescriptionRequired: json['prescription_required'] as bool? ?? false,
      isPackageDelivery: json['is_package_delivery'] as bool? ?? false,
      active: json['active'] as bool? ?? true,
    );
  }

  /// Serialize to JSON for local storage
  Map<String, dynamic> toJson() {
    return {
      'slug': slug,
      'label': label,
      'singular': singular,
      'icon': icon,
      'color': color,
      'description': description,
      'hero_text': heroText,
      'search_placeholder': searchPlaceholder,
      'delivery_time_avg': deliveryTimeAvg,
      'min_order': minOrder,
      'age_verification': ageVerification,
      'prescription_required': prescriptionRequired,
      'is_package_delivery': isPackageDelivery,
      'active': active,
    };
  }

  /// Parse the hex color string to an int suitable for Flutter's Color class
  ///
  /// Converts `#FF6B35` → `0xFFFF6B35`
  int get colorValue => int.parse(color.replaceFirst('#', '0xFF'));

  /// Whether this category requires special verification before ordering
  bool get requiresVerification => ageVerification || prescriptionRequired;
}
