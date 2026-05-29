/// Status badge widget for displaying order status with appropriate colors
///
/// Maps order status strings to consistent colors and icons
/// across the app (orders list, order detail, tracking).

import 'package:flutter/material.dart';
import '../config/app_config.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  final bool showIcon;
  final double fontSize;
  final double verticalPadding;
  final double horizontalPadding;

  const StatusBadge({
    super.key,
    required this.status,
    this.showIcon = true,
    this.fontSize = 11,
    this.verticalPadding = 4,
    this.horizontalPadding = 10,
  });

  /// Color mapping for each order status
  static Color getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return const Color(0xFFFF9800); // Orange
      case 'processing':
        return const Color(0xFF2196F3); // Blue
      case 'courier-assignment':
      case 'courier-assigned':
        return const Color(0xFF3F51B5); // Indigo
      case 'rider-accepted':
        return const Color(0xFF9C27B0); // Purple
      case 'rider-picked-up':
      case 'rider-on-the-way':
      case 'out-for-delivery':
        return const Color(0xFF009688); // Teal
      case 'completed':
      case 'delivered':
        return const Color(0xFF4CAF50); // Green
      case 'cancelled':
        return const Color(0xFFF44336); // Red
      case 'failed':
        return const Color(0xFFE53935); // Red
      case 'refunded':
        return const Color(0xFF9E9E9E); // Grey
      default:
        return const Color(AppConfig.TEXT_SECONDARY);
    }
  }

  /// Icon mapping for each order status
  static IconData getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.schedule_rounded;
      case 'processing':
        return Icons.restaurant_rounded;
      case 'courier-assignment':
      case 'courier-assigned':
        return Icons.person_search_rounded;
      case 'rider-accepted':
        return Icons.directions_bike_rounded;
      case 'rider-picked-up':
        return Icons.inventory_2_rounded;
      case 'rider-on-the-way':
      case 'out-for-delivery':
        return Icons.delivery_dining_rounded;
      case 'completed':
      case 'delivered':
        return Icons.check_circle_rounded;
      case 'cancelled':
        return Icons.cancel_rounded;
      case 'failed':
        return Icons.error_rounded;
      case 'refunded':
        return Icons.replay_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  /// Get display label for a status
  static String getStatusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'processing':
        return 'Processing';
      case 'courier-assignment':
        return 'Finding Rider';
      case 'courier-assigned':
        return 'Rider Assigned';
      case 'rider-accepted':
        return 'Rider Accepted';
      case 'rider-picked-up':
        return 'Picked Up';
      case 'rider-on-the-way':
        return 'On the Way';
      case 'out-for-delivery':
        return 'Out for Delivery';
      case 'completed':
        return 'Completed';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      case 'failed':
        return 'Failed';
      case 'refunded':
        return 'Refunded';
      default:
        return status
            .split('-')
            .map((w) => w[0].toUpperCase() + w.substring(1))
            .join(' ');
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = getStatusColor(status);
    final icon = getStatusIcon(status);
    final label = getStatusLabel(status);

    return Container(
      padding: EdgeInsets.symmetric(
        vertical: verticalPadding,
        horizontal: horizontalPadding,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppConfig.RADIUS_ROUND),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(icon, size: fontSize + 5, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
