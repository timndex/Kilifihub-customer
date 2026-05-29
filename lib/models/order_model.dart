/// Order models for the KilifiHub customer app
///
/// Maps to the order data returned by `GET /kilifi/v1/orders`,
/// `GET /kilifi/v1/orders/{id}`, and `GET /kilifi/v1/orders/{id}/track`.

import 'package:flutter/material.dart';

/// A single item within an order
class OrderItem {
  final String name;
  final int quantity;
  final String price;
  final String imageUrl;

  OrderItem({
    required this.name,
    this.quantity = 1,
    this.price = '0',
    this.imageUrl = '',
  });

  /// Create from WordPress API JSON response
  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      name: json['name'] as String? ?? 'Item',
      quantity: json['quantity'] as int? ?? 1,
      price: json['price']?.toString() ?? '0',
      imageUrl: json['image_url'] as String? ?? '',
    );
  }

  /// Serialize to JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'quantity': quantity,
      'price': price,
      'image_url': imageUrl,
    };
  }

  /// Line total for this item
  double get lineTotal => (double.tryParse(price) ?? 0) * quantity;

  /// Formatted line total
  String get displayLineTotal => 'KSh ${lineTotal.toStringAsFixed(0)}';
}

/// Complete order model with tracking and rider info
class OrderModel {
  final int id;
  final String orderNumber;
  final String status;
  final String statusLabel;
  final double total;
  final List<OrderItem> items;
  final String storeName;
  final String storeCategory;
  final String storeCategoryLabel;
  final String dateCreated;
  final String deliveryAddress;
  final String? mpesaReceipt;
  final String? riderName;
  final String? riderPhone;
  final double? riderLat;
  final double? riderLng;

  OrderModel({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.statusLabel,
    required this.total,
    this.items = const [],
    this.storeName = '',
    this.storeCategory = '',
    this.storeCategoryLabel = '',
    this.dateCreated = '',
    this.deliveryAddress = '',
    this.mpesaReceipt,
    this.riderName,
    this.riderPhone,
    this.riderLat,
    this.riderLng,
  });

  /// Create from WordPress API JSON response
  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return OrderModel(
      id: json['id'] as int? ?? 0,
      orderNumber:
          json['order_number']?.toString() ?? json['id']?.toString() ?? '',
      status: json['status'] as String? ?? 'pending',
      statusLabel: json['status_label'] as String? ?? 'Pending',
      total: double.tryParse(json['total']?.toString() ?? '0') ?? 0,
      items: rawItems
          .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      storeName: json['store_name'] as String? ?? '',
      storeCategory: json['store_category'] as String? ?? '',
      storeCategoryLabel:
          json['store_category_label'] as String? ?? '',
      dateCreated: json['date_created'] as String? ?? '',
      deliveryAddress: json['delivery_address'] as String? ?? '',
      mpesaReceipt: json['mpesa_receipt'] as String?,
      riderName: json['rider_name'] as String?,
      riderPhone: json['rider_phone'] as String?,
      riderLat: double.tryParse(json['rider_lat']?.toString() ?? ''),
      riderLng: double.tryParse(json['rider_lng']?.toString() ?? ''),
    );
  }

  /// Serialize to JSON for local storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_number': orderNumber,
      'status': status,
      'status_label': statusLabel,
      'total': total,
      'items': items.map((e) => e.toJson()).toList(),
      'store_name': storeName,
      'store_category': storeCategory,
      'store_category_label': storeCategoryLabel,
      'date_created': dateCreated,
      'delivery_address': deliveryAddress,
      'mpesa_receipt': mpesaReceipt,
      'rider_name': riderName,
      'rider_phone': riderPhone,
      'rider_lat': riderLat,
      'rider_lng': riderLng,
    };
  }

  /// Color associated with the order status
  Color get statusColor {
    switch (status) {
      case 'pending':
        return const Color(0xFFFF9800); // Orange
      case 'processing':
        return const Color(0xFF2196F3); // Blue
      case 'courier-assignment':
      case 'courier-assigned':
        return const Color(0xFF9C27B0); // Purple
      case 'rider-accepted':
        return const Color(0xFF00BCD4); // Cyan
      case 'rider-picked-up':
      case 'rider-on-the-way':
        return const Color(0xFF4CAF50); // Green
      case 'completed':
        return const Color(0xFF4CAF50); // Green
      case 'cancelled':
        return const Color(0xFFF44336); // Red
      case 'refunded':
        return const Color(0xFF9E9E9E); // Grey
      case 'failed':
        return const Color(0xFFF44336); // Red
      default:
        return const Color(0xFF757575); // Grey
    }
  }

  /// Icon associated with the order status
  IconData get statusIcon {
    switch (status) {
      case 'pending':
        return Icons.schedule;
      case 'processing':
        return Icons.restaurant;
      case 'courier-assignment':
      case 'courier-assigned':
        return Icons.person_search;
      case 'rider-accepted':
        return Icons.directions_bike;
      case 'rider-picked-up':
        return Icons.inventory_2;
      case 'rider-on-the-way':
        return Icons.delivery_dining;
      case 'completed':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      case 'refunded':
        return Icons.replay;
      case 'failed':
        return Icons.error;
      default:
        return Icons.help_outline;
    }
  }

  /// Whether this order is currently active (in progress)
  bool get isActive => [
        'pending',
        'processing',
        'courier-assignment',
        'courier-assigned',
        'rider-accepted',
        'rider-picked-up',
        'rider-on-the-way',
      ].contains(status);

  /// Whether this order has a rider assigned
  bool get hasRider => riderName != null && riderName!.isNotEmpty;

  /// Whether rider location tracking is available
  bool get canTrackRider =>
      isActive && riderLat != null && riderLng != null;

  /// Formatted total
  String get displayTotal => 'KSh ${total.toStringAsFixed(0)}';

  /// Number of items in the order
  int get itemCount => items.length;
}
