/// Cart screen for KilifiHub Customer App
///
/// Displays cart items grouped by store with quantity selectors,
/// swipe-to-delete, and a sticky bottom section with totals.
/// Includes empty state, loading shimmer, and clear-all confirmation.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';

import '../config/app_config.dart';
import '../models/cart_model.dart';
import '../providers/cart_provider.dart';
import '../widgets/empty_state.dart';
import '../widgets/quantity_selector.dart';
import '../screens/checkout_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  @override
  void initState() {
    super.initState();
    // Refresh cart from API on screen open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CartProvider>().refreshCart();
    });
  }

  void _navigateToCheckout() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CheckoutScreen()),
    );
  }

  void _navigateToStores() {
    Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => route.isFirst);
  }

  Future<void> _showClearCartDialog(CartProvider cartProvider) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConfig.RADIUS_LG),
        ),
        title: const Text('Clear Cart?'),
        content: const Text(
          'This will remove all items from your cart. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(AppConfig.ERROR_COLOR),
            ),
            child: const Text(
              'Clear All',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      // Remove all items one by one from server
      final cart = cartProvider.cart;
      if (cart != null) {
        for (final item in cart.items) {
          await cartProvider.removeItem(item.cartItemKey);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppConfig.BACKGROUND_COLOR),
      appBar: AppBar(
        title: const Text('My Cart'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Consumer<CartProvider>(
            builder: (context, cart, _) {
              if (cart.isNotEmpty) {
                return TextButton(
                  onPressed: () => _showClearCartDialog(cart),
                  child: const Text(
                    'Clear All',
                    style: TextStyle(
                      color: Color(AppConfig.ERROR_COLOR),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: Consumer<CartProvider>(
        builder: (context, cartProvider, _) {
          // Loading state
          if (cartProvider.isLoading && cartProvider.cart == null) {
            return const _CartShimmer();
          }

          // Error state
          if (cartProvider.error != null && cartProvider.isEmpty) {
            return EmptyState.error(
              message: cartProvider.error,
              onRetry: () => cartProvider.refreshCart(),
            );
          }

          // Empty cart
          if (cartProvider.isEmpty) {
            return EmptyState.emptyCart(onBrowse: _navigateToStores);
          }

          final cart = cartProvider.cart!;

          return Column(
            children: [
              // Cart items list
              Expanded(
                child: RefreshIndicator(
                  color: const Color(AppConfig.PRIMARY_COLOR),
                  onRefresh: () => cartProvider.refreshCart(),
                  child: _CartItemsList(
                    cart: cart,
                    cartProvider: cartProvider,
                  ),
                ),
              ),

              // Sticky bottom totals
              _CartBottomSection(
                cart: cart,
                onCheckout: _navigateToCheckout,
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Cart Items List ──────────────────────────────────────

class _CartItemsList extends StatelessWidget {
  final CartModel cart;
  final CartProvider cartProvider;

  const _CartItemsList({
    required this.cart,
    required this.cartProvider,
  });

  /// Group items by store
  Map<int, List<CartItem>> get _groupedByStore {
    final map = <int, List<CartItem>>{};
    for (final item in cart.items) {
      map.putIfAbsent(item.storeId, () => []).add(item);
    }
    return map;
  }

  /// Get store name from store ID
  String _storeName(int storeId) {
    final item = cart.items.firstWhere(
      (i) => i.storeId == storeId,
    );
    return item.storeName;
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupedByStore;
    final storeIds = grouped.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: storeIds.length,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemBuilder: (context, index) {
        final storeId = storeIds[index];
        final storeItems = grouped[storeId]!;
        final storeName = _storeName(storeId);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Store header
            _StoreHeader(storeName: storeName),
            const SizedBox(height: 8),

            // Items for this store
            ...storeItems.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _CartItemCard(
                    item: item,
                    cartProvider: cartProvider,
                  ),
                )),

            if (index < storeIds.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(height: 1),
              ),
          ],
        );
      },
    );
  }
}

// ─── Store Header ──────────────────────────────────────

class _StoreHeader extends StatelessWidget {
  final String storeName;

  const _StoreHeader({required this.storeName});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(AppConfig.PRIMARY_COLOR).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppConfig.RADIUS_SM),
          ),
          child: const Icon(
            Icons.store_rounded,
            size: 18,
            color: Color(AppConfig.PRIMARY_COLOR),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            storeName,
            style: const TextStyle(
              fontSize: AppConfig.FONT_SIZE_LARGE,
              fontWeight: FontWeight.w700,
              color: Color(AppConfig.TEXT_PRIMARY),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Cart Item Card ──────────────────────────────────────

class _CartItemCard extends StatelessWidget {
  final CartItem item;
  final CartProvider cartProvider;

  const _CartItemCard({
    required this.item,
    required this.cartProvider,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(item.cartItemKey),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConfig.RADIUS_LG),
            ),
            title: const Text('Remove Item?'),
            content: Text('Remove "${item.name}" from your cart?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(AppConfig.ERROR_COLOR),
                ),
                child: const Text('Remove'),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) {
        cartProvider.removeItem(item.cartItemKey);
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: const Color(AppConfig.ERROR_COLOR).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppConfig.RADIUS_LG),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: Color(AppConfig.ERROR_COLOR),
          size: 28,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppConfig.RADIUS_LG),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product image
            ClipRRect(
              borderRadius: BorderRadius.circular(AppConfig.RADIUS_MD),
              child: SizedBox(
                width: 72,
                height: 72,
                child: item.imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: item.imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          color: const Color(AppConfig.BACKGROUND_COLOR),
                          child: const Icon(
                            Icons.image_outlined,
                            color: Color(AppConfig.TEXT_HINT),
                          ),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: const Color(AppConfig.BACKGROUND_COLOR),
                          child: const Icon(
                            Icons.image_not_supported_outlined,
                            color: Color(AppConfig.TEXT_HINT),
                          ),
                        ),
                      )
                    : Container(
                        color: const Color(AppConfig.BACKGROUND_COLOR),
                        child: const Icon(
                          Icons.shopping_bag_outlined,
                          color: Color(AppConfig.TEXT_HINT),
                        ),
                      ),
              ),
            ),

            const SizedBox(width: 12),

            // Item details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name
                  Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: AppConfig.FONT_SIZE_MEDIUM,
                      fontWeight: FontWeight.w600,
                      color: Color(AppConfig.TEXT_PRIMARY),
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Unit price
                  Text(
                    'KSh ${item.price}',
                    style: const TextStyle(
                      fontSize: AppConfig.FONT_SIZE_SMALL,
                      color: Color(AppConfig.TEXT_SECONDARY),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Bottom row: quantity selector + line total
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Quantity selector
                      QuantitySelector(
                        quantity: item.quantity,
                        onIncrement: (newQty) async {
                          // Remove and re-add with new quantity
                          await cartProvider.removeItem(item.cartItemKey);
                          if (mounted) {
                            await cartProvider.addItem(item.productId, newQty);
                          }
                        },
                        onDecrement: (newQty) async {
                          await cartProvider.removeItem(item.cartItemKey);
                          if (mounted) {
                            await cartProvider.addItem(item.productId, newQty);
                          }
                        },
                        buttonSize: 28,
                        iconSize: 16,
                        fontSize: 13,
                      ),

                      // Line total
                      Text(
                        item.displayLineTotal,
                        style: const TextStyle(
                          fontSize: AppConfig.FONT_SIZE_LARGE,
                          fontWeight: FontWeight.w700,
                          color: Color(AppConfig.PRIMARY_COLOR),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Remove button
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: GestureDetector(
                onTap: () => cartProvider.removeItem(item.cartItemKey),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(AppConfig.ERROR_COLOR).withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: Color(AppConfig.ERROR_COLOR),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Cart Bottom Section ──────────────────────────────────

class _CartBottomSection extends StatelessWidget {
  final CartModel cart;
  final VoidCallback onCheckout;

  const _CartBottomSection({
    required this.cart,
    required this.onCheckout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppConfig.RADIUS_XL),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Subtotal
              _SummaryRow(
                label: 'Subtotal',
                value: cart.displaySubtotal,
              ),
              const SizedBox(height: 8),

              // Delivery fee
              _SummaryRow(
                label: 'Delivery Fee',
                value: cart.deliveryFee == 0 ? 'Free' : cart.displayDeliveryFee,
                valueColor: cart.deliveryFee == 0
                    ? const Color(AppConfig.SUCCESS_COLOR)
                    : null,
              ),
              const SizedBox(height: 12),

              const Divider(height: 1),

              const SizedBox(height: 12),

              // Total
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total',
                    style: TextStyle(
                      fontSize: AppConfig.FONT_SIZE_XLARGE,
                      fontWeight: FontWeight.w700,
                      color: Color(AppConfig.TEXT_PRIMARY),
                    ),
                  ),
                  Text(
                    cart.displayTotal,
                    style: const TextStyle(
                      fontSize: AppConfig.FONT_SIZE_XLARGE,
                      fontWeight: FontWeight.w800,
                      color: Color(AppConfig.PRIMARY_COLOR),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Checkout button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: cart.isEmpty ? null : onCheckout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(AppConfig.PRIMARY_COLOR),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        const Color(AppConfig.TEXT_HINT).withValues(alpha: 0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppConfig.RADIUS_MD),
                    ),
                  ),
                  child: const Text(
                    'Proceed to Checkout',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Summary Row ──────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: AppConfig.FONT_SIZE_MEDIUM,
            color: Color(AppConfig.TEXT_SECONDARY),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: AppConfig.FONT_SIZE_MEDIUM,
            fontWeight: FontWeight.w600,
            color: valueColor ?? const Color(AppConfig.TEXT_PRIMARY),
          ),
        ),
      ],
    );
  }
}

// ─── Cart Shimmer ──────────────────────────────────────────

class _CartShimmer extends StatelessWidget {
  const _CartShimmer();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE0E0E0),
      highlightColor: const Color(0xFFF5F5F5),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 4,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Store header
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 140,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Item card
              Container(
                height: 90,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppConfig.RADIUS_LG),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
