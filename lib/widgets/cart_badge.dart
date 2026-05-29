import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:badges/badges.dart' as badges;
import '../config/app_config.dart';
import '../providers/cart_provider.dart';

class CartBadge extends StatelessWidget {
  final IconData icon;
  final double? iconSize;
  final Color? iconColor;
  final VoidCallback? onTap;

  const CartBadge({
    super.key,
    this.icon = Icons.shopping_cart_outlined,
    this.iconSize = 24,
    this.iconColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cartProvider = context.watch<CartProvider>();
    final count = cartProvider.itemCount;

    return GestureDetector(
      onTap: onTap,
      child: badges.Badge(
        showBadge: count > 0,
        badgeContent: Text(
          '$count',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
        badgeStyle: badges.BadgeStyle(
          badgeColor: const Color(AppConfig.PRIMARY_COLOR),
          padding: const EdgeInsets.all(4),
          elevation: 0,
        ),
        position: badges.BadgePosition.topEnd(top: -6, end: -6),
        child: Icon(
          icon,
          size: iconSize,
          color: iconColor ?? const Color(AppConfig.TEXT_PRIMARY),
        ),
      ),
    );
  }
}
