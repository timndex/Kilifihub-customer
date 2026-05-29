/// Orders list screen for KilifiHub Customer App
///
/// Displays customer orders in two tabs: Active and Past.
/// Features pull-to-refresh, loading shimmer, empty states,
/// and order cards with status badges.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../config/app_config.dart';
import '../models/order_model.dart';
import '../providers/order_provider.dart';
import '../widgets/empty_state.dart';
import '../widgets/status_badge.dart';
import 'order_detail_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrderProvider>().fetchOrders();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppConfig.BACKGROUND_COLOR),
      appBar: AppBar(
        title: const Text('My Orders'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(AppConfig.PRIMARY_COLOR),
          unselectedLabelColor: const Color(AppConfig.TEXT_SECONDARY),
          indicatorColor: const Color(AppConfig.PRIMARY_COLOR),
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 15,
          ),
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'Past'),
          ],
        ),
      ),
      body: Consumer<OrderProvider>(
        builder: (context, orderProvider, _) {
          if (orderProvider.isLoading && orderProvider.orders.isEmpty) {
            return const _OrdersShimmer();
          }

          if (orderProvider.error != null && orderProvider.orders.isEmpty) {
            return EmptyState.error(
              message: orderProvider.error,
              onRetry: () => orderProvider.fetchOrders(),
            );
          }

          return TabBarView(
            controller: _tabController,
            children: [
              // Active orders
              _OrdersList(
                orders: orderProvider.activeOrders,
                emptyState: EmptyState(
                  icon: Icons.local_shipping_outlined,
                  title: 'No Active Orders',
                  subtitle: 'Your active orders will appear here once placed.',
                  actionLabel: 'Browse Stores',
                  onAction: () => Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/home',
                    (route) => route.isFirst,
                  ),
                ),
                onRefresh: () => orderProvider.fetchOrders(),
              ),

              // Past orders
              _OrdersList(
                orders: orderProvider.pastOrders,
                emptyState: EmptyState.noOrders(
                  onBrowse: () => Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/home',
                    (route) => route.isFirst,
                  ),
                ),
                onRefresh: () => orderProvider.fetchOrders(),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Orders List ──────────────────────────────────────────

class _OrdersList extends StatelessWidget {
  final List<OrderModel> orders;
  final Widget emptyState;
  final Future<void> Function() onRefresh;

  const _OrdersList({
    required this.orders,
    required this.emptyState,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return emptyState;
    }

    return RefreshIndicator(
      color: const Color(AppConfig.PRIMARY_COLOR),
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: orders.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final order = orders[index];
          return _OrderCard(order: order);
        },
      ),
    );
  }
}

// ─── Order Card ──────────────────────────────────────────

class _OrderCard extends StatelessWidget {
  final OrderModel order;

  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OrderDetailScreen(orderId: order.id),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: store name + status badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Store info
                Expanded(
                  child: Row(
                    children: [
                      _CategoryIcon(category: order.storeCategory),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.storeName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: AppConfig.FONT_SIZE_LARGE,
                                fontWeight: FontWeight.w700,
                                color: Color(AppConfig.TEXT_PRIMARY),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Order #${order.orderNumber}',
                              style: const TextStyle(
                                fontSize: AppConfig.FONT_SIZE_SMALL,
                                color: Color(AppConfig.TEXT_SECONDARY),
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                StatusBadge(status: order.status),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Bottom row: date + items + total + track button
            Row(
              children: [
                // Date
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatDate(order.dateCreated),
                        style: const TextStyle(
                          fontSize: AppConfig.FONT_SIZE_SMALL,
                          color: Color(AppConfig.TEXT_HINT),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${order.itemCount} item${order.itemCount != 1 ? 's' : ''} • ${order.displayTotal}',
                        style: const TextStyle(
                          fontSize: AppConfig.FONT_SIZE_MEDIUM,
                          fontWeight: FontWeight.w600,
                          color: Color(AppConfig.TEXT_PRIMARY),
                        ),
                      ),
                    ],
                  ),
                ),

                // Track button (for active orders)
                if (order.isActive)
                  SizedBox(
                    height: 36,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                OrderTrackingScreen(orderId: order.id),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color(AppConfig.PRIMARY_COLOR),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppConfig.RADIUS_MD),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Track',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return dateStr;
    }
  }
}

// ─── Category Icon ──────────────────────────────────────────

class _CategoryIcon extends StatelessWidget {
  final String category;
  const _CategoryIcon({required this.category});

  IconData get _icon {
    switch (category) {
      case 'hotel':
        return Icons.restaurant_rounded;
      case 'pharmacy':
        return Icons.local_pharmacy_rounded;
      case 'supermarket':
        return Icons.shopping_cart_rounded;
      case 'groceries':
        return Icons.eco_rounded;
      case 'shops':
        return Icons.store_rounded;
      case 'package':
        return Icons.inventory_2_rounded;
      case 'alcohol':
        return Icons.wine_bar_rounded;
      default:
        return Icons.shopping_bag_rounded;
    }
  }

  Color get _color {
    final colorValue = AppConfig.CATEGORY_COLORS[category] ?? AppConfig.PRIMARY_COLOR;
    return Color(colorValue);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppConfig.RADIUS_MD),
      ),
      child: Icon(_icon, size: 22, color: _color),
    );
  }
}

// ─── Shimmer ──────────────────────────────────────────

class _OrdersShimmer extends StatelessWidget {
  const _OrdersShimmer();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE0E0E0),
      highlightColor: const Color(0xFFF5F5F5),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => Container(
          height: 130,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppConfig.RADIUS_LG),
          ),
        ),
      ),
    );
  }
}
