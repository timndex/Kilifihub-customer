import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/app_config.dart';
import '../models/store_model.dart';

class StoreCard extends StatelessWidget {
  final StoreModel store;
  final VoidCallback? onTap;

  const StoreCard({
    super.key,
    required this.store,
    this.onTap,
  });

  /// Get emoji for category slug
  String _categoryEmoji(String category) {
    const emojiMap = {
      'hotel': '🏨',
      'pharmacy': '💊',
      'supermarket': '🛒',
      'groceries': '🥬',
      'shops': '🛍️',
      'package': '📦',
      'alcohol': '🍷',
    };
    return emojiMap[category] ?? '🏪';
  }

  @override
  Widget build(BuildContext context) {
    final categoryColor =
        Color(AppConfig.getCategoryColor(store.category));

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppConfig.RADIUS_LG),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Banner Image ──
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppConfig.RADIUS_LG),
                  ),
                  child: store.hasBanner
                      ? CachedNetworkImage(
                          imageUrl: store.storeBanner,
                          height: 100,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => _bannerPlaceholder(categoryColor),
                          errorWidget: (_, __, ___) =>
                              _bannerPlaceholder(categoryColor),
                        )
                      : _bannerPlaceholder(categoryColor),
                ),

                // Open / Closed badge
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: store.isOpen
                          ? const Color(AppConfig.SUCCESS_COLOR)
                          : const Color(AppConfig.ERROR_COLOR),
                      borderRadius:
                          BorderRadius.circular(AppConfig.RADIUS_ROUND),
                    ),
                    child: Text(
                      store.isOpen ? 'Open' : 'Closed',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),

                // Category icon badge
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: categoryColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: categoryColor.withValues(alpha: 0.4),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        _categoryEmoji(store.category),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // ── Store Info ──
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Avatar
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: categoryColor.withValues(alpha: 0.15),
                        backgroundImage: store.hasAvatar
                            ? CachedNetworkImageProvider(store.storeAvatar)
                            : null,
                        child: !store.hasAvatar
                            ? Text(
                                store.storeName.isNotEmpty
                                    ? store.storeName[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: categoryColor,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 8),
                      // Name
                      Expanded(
                        child: Text(
                          store.storeName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(AppConfig.TEXT_PRIMARY),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      // Rating
                      const Icon(Icons.star, size: 14, color: Color(AppConfig.ACCENT_COLOR)),
                      const SizedBox(width: 2),
                      Text(
                        store.ratingDisplay,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(AppConfig.TEXT_SECONDARY),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Delivery time
                      const Icon(Icons.access_time, size: 13, color: Color(AppConfig.TEXT_SECONDARY)),
                      const SizedBox(width: 2),
                      Text(
                        store.deliveryTime,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(AppConfig.TEXT_SECONDARY),
                        ),
                      ),
                    ],
                  ),
                  if (store.minOrder > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Min: ${store.minOrderDisplay}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(AppConfig.TEXT_HINT),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bannerPlaceholder(Color categoryColor) {
    return Container(
      height: 100,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            categoryColor.withValues(alpha: 0.7),
            categoryColor.withValues(alpha: 0.3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          _categoryEmoji(store.category),
          style: const TextStyle(fontSize: 32),
        ),
      ),
    );
  }
}
