import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../models/category_model.dart';

class CategoryCard extends StatefulWidget {
  final CategoryModel category;
  final VoidCallback? onTap;

  const CategoryCard({
    super.key,
    required this.category,
    this.onTap,
  });

  @override
  State<CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<CategoryCard> {
  bool _isPressed = false;

  /// Get emoji for category slug
  String get _emoji {
    const emojiMap = {
      'hotel': '🏨',
      'pharmacy': '💊',
      'supermarket': '🛒',
      'groceries': '🥬',
      'shops': '🛍️',
      'package': '📦',
      'alcohol': '🍷',
    };
    return emojiMap[widget.category.slug] ?? '🏪';
  }

  @override
  Widget build(BuildContext context) {
    final colorValue = AppConfig.getCategoryColor(widget.category.slug);
    final categoryColor = Color(colorValue);

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: AppConfig.ANIM_FAST),
        curve: Curves.easeInOut,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: categoryColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  _emoji,
                  style: const TextStyle(fontSize: 28),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 72,
              child: Text(
                widget.category.label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: AppConfig.FONT_SIZE_SMALL,
                  fontWeight: FontWeight.w600,
                  color: Color(AppConfig.TEXT_PRIMARY),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
