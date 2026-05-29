import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../config/app_config.dart';
import '../models/product_model.dart';
import '../providers/cart_provider.dart';

class ProductCard extends StatelessWidget {
  final ProductModel product;
  final int vendorId;
  final VoidCallback? onTap;

  const ProductCard({
    super.key,
    required this.product,
    required this.vendorId,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cartProvider = context.watch<CartProvider>();
    final quantity = cartProvider.getProductQuantity(product.id);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppConfig.RADIUS_LG),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Product Image ──
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppConfig.RADIUS_LG),
                  ),
                  child: product.hasImage
                      ? CachedNetworkImage(
                          imageUrl: product.imageUrl,
                          height: 110,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => _imagePlaceholder(),
                          errorWidget: (_, __, ___) => _imagePlaceholder(),
                        )
                      : _imagePlaceholder(),
                ),
                // Sale badge
                if (product.isOnSale)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(AppConfig.PRIMARY_COLOR),
                        borderRadius:
                            BorderRadius.circular(AppConfig.RADIUS_SM),
                      ),
                      child: const Text(
                        'SALE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                // Out of stock overlay
                if (product.isOutOfStock)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.7),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(AppConfig.RADIUS_LG),
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          'Out of Stock',
                          style: TextStyle(
                            color: Color(AppConfig.ERROR_COLOR),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            // ── Product Info ──
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(AppConfig.TEXT_PRIMARY),
                        height: 1.2,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product.displayPrice,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Color(AppConfig.PRIMARY_COLOR),
                                ),
                              ),
                              if (product.isOnSale)
                                Text(
                                  product.displayRegularPrice,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Color(AppConfig.TEXT_HINT),
                                    decoration:
                                        TextDecoration.lineThrough,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // Add / Quantity button
                        _buildAddButton(context, cartProvider, quantity),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton(
      BuildContext context, CartProvider cartProvider, int quantity) {
    if (product.isOutOfStock) {
      return const SizedBox.shrink();
    }

    if (quantity > 0) {
      return Container(
        decoration: BoxDecoration(
          color: const Color(AppConfig.PRIMARY_COLOR),
          borderRadius: BorderRadius.circular(AppConfig.RADIUS_MD),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _qtyButton(
              icon: Icons.remove,
              onTap: () => _updateQuantity(cartProvider, quantity - 1),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                '$quantity',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            _qtyButton(
              icon: Icons.add,
              onTap: () => _updateQuantity(cartProvider, quantity + 1),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () => _updateQuantity(cartProvider, 1),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: const Color(AppConfig.PRIMARY_COLOR),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(AppConfig.PRIMARY_COLOR).withValues(alpha: 0.3),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(
          Icons.add,
          color: Colors.white,
          size: 18,
        ),
      ),
    );
  }

  Widget _qtyButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, color: Colors.white, size: 14),
      ),
    );
  }

  Future<void> _updateQuantity(
      CartProvider cartProvider, int newQuantity) async {
    if (newQuantity <= 0) {
      // Find the cart item key to remove
      final cart = cartProvider.cart;
      if (cart != null) {
        final item = cart.items
            .where((i) => i.productId == product.id)
            .firstOrNull;
        if (item != null) {
          await cartProvider.removeItem(item.cartItemKey);
        }
      }
    } else {
      await cartProvider.addItem(product.id, newQuantity);
    }
  }

  Widget _imagePlaceholder() {
    return Container(
      height: 110,
      width: double.infinity,
      color: const Color(AppConfig.BACKGROUND_COLOR),
      child: const Icon(
        Icons.shopping_bag_outlined,
        color: Color(AppConfig.TEXT_HINT),
        size: 32,
      ),
    );
  }
}
