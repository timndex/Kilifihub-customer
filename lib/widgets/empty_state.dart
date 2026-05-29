import 'package:flutter/material.dart';
import '../config/app_config.dart';

/// Configurable empty state widget for different scenarios
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? iconColor;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
    this.iconColor,
  });

  /// No orders empty state
  factory EmptyState.noOrders({VoidCallback? onBrowse}) {
    return EmptyState(
      icon: Icons.receipt_long_outlined,
      title: 'No Orders Yet',
      subtitle: 'When you place your first order, it will appear here.',
      actionLabel: 'Browse Stores',
      onAction: onBrowse,
    );
  }

  /// No stores empty state
  factory EmptyState.noStores({VoidCallback? onRetry}) {
    return EmptyState(
      icon: Icons.store_outlined,
      title: 'No Stores Found',
      subtitle: 'We couldn\'t find any stores in this category right now.',
      actionLabel: 'Try Again',
      onAction: onRetry,
    );
  }

  /// No search results empty state
  factory EmptyState.noSearchResults({String? query}) {
    return EmptyState(
      icon: Icons.search_off_rounded,
      title: 'No Results Found',
      subtitle: query != null
          ? 'No results for "$query". Try a different search.'
          : 'Try searching with different keywords.',
    );
  }

  /// Empty cart empty state
  factory EmptyState.emptyCart({VoidCallback? onBrowse}) {
    return EmptyState(
      icon: Icons.shopping_cart_outlined,
      title: 'Your Cart is Empty',
      subtitle: 'Add items from your favorite stores to get started.',
      actionLabel: 'Browse Stores',
      onAction: onBrowse,
    );
  }

  /// Network error empty state
  factory EmptyState.networkError({VoidCallback? onRetry}) {
    return EmptyState(
      icon: Icons.wifi_off_rounded,
      title: 'No Connection',
      subtitle: 'Please check your internet connection and try again.',
      actionLabel: 'Retry',
      onAction: onRetry,
      iconColor: const Color(AppConfig.WARNING_COLOR),
    );
  }

  /// General error empty state
  factory EmptyState.error({String? message, VoidCallback? onRetry}) {
    return EmptyState(
      icon: Icons.error_outline_rounded,
      title: 'Something Went Wrong',
      subtitle: message ?? 'An unexpected error occurred. Please try again.',
      actionLabel: 'Retry',
      onAction: onRetry,
      iconColor: const Color(AppConfig.ERROR_COLOR),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConfig.SPACING_LG,
          vertical: AppConfig.SPACING_XL,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: (iconColor ?? const Color(AppConfig.TEXT_HINT))
                    .withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 40,
                color: iconColor ?? const Color(AppConfig.TEXT_HINT),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: AppConfig.FONT_SIZE_XLARGE,
                fontWeight: FontWeight.w700,
                color: Color(AppConfig.TEXT_PRIMARY),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: AppConfig.FONT_SIZE_MEDIUM,
                color: Color(AppConfig.TEXT_SECONDARY),
                height: 1.4,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(AppConfig.PRIMARY_COLOR),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppConfig.RADIUS_ROUND),
                  ),
                ),
                child: Text(
                  actionLabel!,
                  style: const TextStyle(
                    fontSize: AppConfig.FONT_SIZE_MEDIUM,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
