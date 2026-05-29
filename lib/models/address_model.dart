/// Address model representing a saved delivery address
///
/// Maps to the address data returned by `GET /kilifi/v1/customer/addresses`
/// and `POST /kilifi/v1/customer/addresses`.
class AddressModel {
  final int? id;
  final String label;
  final String address;
  final double? lat;
  final double? lng;
  final bool isDefault;

  AddressModel({
    this.id,
    required this.label,
    required this.address,
    this.lat,
    this.lng,
    this.isDefault = false,
  });

  /// Create from WordPress API JSON response
  factory AddressModel.fromJson(Map<String, dynamic> json) {
    return AddressModel(
      id: json['id'] as int?,
      label: json['label'] as String? ?? 'Home',
      address: json['address'] as String? ?? '',
      lat: double.tryParse(json['lat']?.toString() ?? ''),
      lng: double.tryParse(json['lng']?.toString() ?? ''),
      isDefault: json['is_default'] as bool? ?? false,
    );
  }

  /// Serialize to JSON for local storage
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'label': label,
      'address': address,
      'lat': lat,
      'lng': lng,
      'is_default': isDefault,
    };
  }

  /// Whether this address has location coordinates
  bool get hasCoordinates => lat != null && lng != null;

  /// Short label for display (e.g., "Home", "Work")
  String get displayLabel => label;

  /// Icon based on label
  String get iconLabel {
    final lower = label.toLowerCase();
    if (lower.contains('home') || lower.contains('house')) return 'home';
    if (lower.contains('work') || lower.contains('office')) return 'work';
    if (lower.contains('hotel') || lower.contains('room')) return 'hotel';
    return 'place';
  }

  AddressModel copyWith({
    int? id,
    String? label,
    String? address,
    double? lat,
    double? lng,
    bool? isDefault,
  }) {
    return AddressModel(
      id: id ?? this.id,
      label: label ?? this.label,
      address: address ?? this.address,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}
