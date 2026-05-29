/// Order detail screen for KilifiHub Customer App
///
/// Displays a detailed view of a single order including:
/// - Status timeline (vertical steps)
/// - Order items
/// - Order summary (subtotal, delivery, total, payment method)
/// - Delivery info with rider contact
/// - Store info card
/// - Category-specific info

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../models/order_model.dart';
import '../providers/order_provider.dart';
import '../widgets/empty_state.dart';
import '../widgets/status_badge.dart';
import 'order_tracking_screen.dart';

class OrderDetailScreen extends StatefulWidget {
  final int orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrderProvider>().fetchOrderDetail(widget.orderId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppConfig.BACKGROUND_COLOR),
      appBar: AppBar(
        title: Text('Order #${widget.orderId}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Consumer<OrderProvider>(
        builder: (context, orderProvider, _) {
          if (orderProvider.isLoading && orderProvider.currentOrder == null) {
            return const Center(
              child: CircularProgressIndicator(
                color: Color(AppConfig.PRIMARY_COLOR),
              ),
            );
          }

          if (orderProvider.error != null && orderProvider.currentOrder == null) {
            return EmptyState.error(
              message: orderProvider.error,
              onRetry: () =>
                  orderProvider.fetchOrderDetail(widget.orderId),
            );
          }

          final order = orderProvider.currentOrder;
          if (order == null) {
            return EmptyState.error(
              message: 'Order not found.',
              onRetry: () =>
                  orderProvider.fetchOrderDetail(widget.orderId),
            );
          }

          return RefreshIndicator(
            color: const Color(AppConfig.PRIMARY_COLOR),
            onRefresh: () =>
                orderProvider.fetchOrderDetail(widget.orderId),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Status header
                _StatusHeader(order: order),
                const SizedBox(height: 16),

                // Status timeline
                _SectionCard(child: _StatusTimeline(order: order)),
                const SizedBox(height: 12),

                // Order items
                _SectionCard(child: _OrderItemsSection(order: order)),
                const SizedBox(height: 12),

                // Order summary
                _SectionCard(child: _OrderSummarySection(order: order)),
                const SizedBox(height: 12),

                // Delivery info
                _SectionCard(child: _DeliveryInfoSection(order: order)),
                const SizedBox(height: 12),

                // Store info
                _SectionCard(child: _StoreInfoSection(order: order)),
                const SizedBox(height: 12),

                // Category-specific info
                if (order.storeCategory.isNotEmpty)
                  _SectionCard(
                      child: _CategoryInfoSection(order: order)),

                // Track delivery button
                if (order.isActive)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => OrderTrackingScreen(
                                  orderId: order.id),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color(AppConfig.PRIMARY_COLOR),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                                AppConfig.RADIUS_MD),
                          ),
                        ),
                        child: const Text(
                          'Track Delivery',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── Section Card ──────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConfig.RADIUS_LG),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ─── Status Header ──────────────────────────────────────

class _StatusHeader extends StatelessWidget {
  final OrderModel order;
  const _StatusHeader({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConfig.RADIUS_LG),
        border: Border.all(
          color: order.statusColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: order.statusColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              order.statusIcon,
              size: 24,
              color: order.statusColor,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  StatusBadge.getStatusLabel(order.status),
                  style: TextStyle(
                    fontSize: AppConfig.FONT_SIZE_XLARGE,
                    fontWeight: FontWeight.w800,
                    color: order.statusColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Order #${order.orderNumber}',
                  style: const TextStyle(
                    fontSize: AppConfig.FONT_SIZE_SMALL,
                    color: Color(AppConfig.TEXT_SECONDARY),
                  ),
                ),
              ],
            ),
          ),
          StatusBadge(status: order.status, showIcon: false),
        ],
      ),
    );
  }
}

// ─── Status Timeline ──────────────────────────────────────

class _StatusTimeline extends StatelessWidget {
  final OrderModel order;
  const _StatusTimeline({required this.order});

  @override
  Widget build(BuildContext context) {
    final steps = _getSteps();
    final currentStepIndex = _getCurrentStepIndex();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.timeline_rounded,
                size: 18, color: Color(AppConfig.PRIMARY_COLOR)),
            SizedBox(width: 8),
            Text(
              'Order Timeline',
              style: TextStyle(
                fontSize: AppConfig.FONT_SIZE_LARGE,
                fontWeight: FontWeight.w700,
                color: Color(AppConfig.TEXT_PRIMARY),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...steps.asMap().entries.map((entry) {
          final index = entry.key;
          final step = entry.value;
          final isCompleted = index < currentStepIndex;
          final isCurrent = index == currentStepIndex;
          final isLast = index == steps.length - 1;

          return _TimelineStep(
            step: step,
            isCompleted: isCompleted,
            isCurrent: isCurrent,
            isLast: isLast,
          );
        }),
      ],
    );
  }

  List<_TimelineStepData> _getSteps() {
    return [
      _TimelineStepData(
        icon: Icons.receipt_long_rounded,
        label: 'Order Placed',
        time: _formatDate(order.dateCreated),
      ),
      _TimelineStepData(
        icon: Icons.payment_rounded,
        label: 'Payment Confirmed',
        time: order.mpesaReceipt != null ? 'Confirmed' : 'Pending',
      ),
      _TimelineStepData(
        icon: Icons.restaurant_rounded,
        label: 'Preparing',
        time: '',
      ),
      _TimelineStepData(
        icon: Icons.person_rounded,
        label: 'Rider Assigned',
        time: order.riderName ?? '',
      ),
      _TimelineStepData(
        icon: Icons.inventory_2_rounded,
        label: 'Picked Up',
        time: '',
      ),
      _TimelineStepData(
        icon: Icons.check_circle_rounded,
        label: 'Delivered',
        time: '',
      ),
    ];
  }

  int _getCurrentStepIndex() {
    switch (order.status) {
      case 'pending':
        return 0;
      case 'processing':
        return 2;
      case 'courier-assignment':
      case 'courier-assigned':
        return 3;
      case 'rider-accepted':
        return 3;
      case 'rider-picked-up':
        return 4;
      case 'rider-on-the-way':
        return 4;
      case 'completed':
      case 'delivered':
        return 5;
      case 'cancelled':
      case 'failed':
        return 0;
      default:
        return 0;
    }
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr;
    }
  }
}

class _TimelineStepData {
  final IconData icon;
  final String label;
  final String time;

  _TimelineStepData({
    required this.icon,
    required this.label,
    required this.time,
  });
}

class _TimelineStep extends StatelessWidget {
  final _TimelineStepData step;
  final bool isCompleted;
  final bool isCurrent;
  final bool isLast;

  const _TimelineStep({
    required this.step,
    required this.isCompleted,
    required this.isCurrent,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final color = isCompleted
        ? const Color(AppConfig.SUCCESS_COLOR)
        : isCurrent
            ? const Color(AppConfig.PRIMARY_COLOR)
            : const Color(AppConfig.TEXT_HINT);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline indicator
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isCompleted
                        ? Icons.check_rounded
                        : step.icon,
                    size: 14,
                    color: color,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      color: isCompleted
                          ? const Color(AppConfig.SUCCESS_COLOR)
                              .withValues(alpha: 0.3)
                          : const Color(AppConfig.DIVIDER_COLOR),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Step content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.label,
                    style: TextStyle(
                      fontSize: AppConfig.FONT_SIZE_MEDIUM,
                      fontWeight:
                          isCurrent ? FontWeight.w700 : FontWeight.w500,
                      color: isCompleted || isCurrent
                          ? const Color(AppConfig.TEXT_PRIMARY)
                          : const Color(AppConfig.TEXT_HINT),
                    ),
                  ),
                  if (step.time.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      step.time,
                      style: TextStyle(
                        fontSize: AppConfig.FONT_SIZE_SMALL,
                        color: isCompleted || isCurrent
                            ? const Color(AppConfig.TEXT_SECONDARY)
                            : const Color(AppConfig.TEXT_HINT),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Order Items Section ──────────────────────────────────

class _OrderItemsSection extends StatelessWidget {
  final OrderModel order;
  const _OrderItemsSection({required this.order});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.shopping_bag_outlined,
                size: 18, color: Color(AppConfig.PRIMARY_COLOR)),
            SizedBox(width: 8),
            Text(
              'Order Items',
              style: TextStyle(
                fontSize: AppConfig.FONT_SIZE_LARGE,
                fontWeight: FontWeight.w700,
                color: Color(AppConfig.TEXT_PRIMARY),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...order.items.map((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${item.name} × ${item.quantity}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: AppConfig.FONT_SIZE_MEDIUM,
                        color: Color(AppConfig.TEXT_PRIMARY),
                      ),
                    ),
                  ),
                  Text(
                    item.displayLineTotal,
                    style: const TextStyle(
                      fontSize: AppConfig.FONT_SIZE_MEDIUM,
                      fontWeight: FontWeight.w600,
                      color: Color(AppConfig.TEXT_PRIMARY),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }
}

// ─── Order Summary Section ──────────────────────────────

class _OrderSummarySection extends StatelessWidget {
  final OrderModel order;
  const _OrderSummarySection({required this.order});

  @override
  Widget build(BuildContext context) {
    final subtotal = order.items.fold<double>(0, (sum, i) => sum + i.lineTotal);
    final deliveryFee = order.total - subtotal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.receipt_long_rounded,
                size: 18, color: Color(AppConfig.PRIMARY_COLOR)),
            SizedBox(width: 8),
            Text(
              'Order Summary',
              style: TextStyle(
                fontSize: AppConfig.FONT_SIZE_LARGE,
                fontWeight: FontWeight.w700,
                color: Color(AppConfig.TEXT_PRIMARY),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _SummaryRow(label: 'Subtotal', value: 'KSh ${subtotal.toStringAsFixed(0)}'),
        const SizedBox(height: 6),
        _SummaryRow(
          label: 'Delivery Fee',
          value: deliveryFee <= 0 ? 'Free' : 'KSh ${deliveryFee.toStringAsFixed(0)}',
          valueColor: deliveryFee <= 0 ? const Color(AppConfig.SUCCESS_COLOR) : null,
        ),
        const SizedBox(height: 8),
        const Divider(height: 1),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Total',
              style: TextStyle(
                fontSize: AppConfig.FONT_SIZE_LARGE,
                fontWeight: FontWeight.w700,
                color: Color(AppConfig.TEXT_PRIMARY),
              ),
            ),
            Text(
              order.displayTotal,
              style: const TextStyle(
                fontSize: AppConfig.FONT_SIZE_LARGE,
                fontWeight: FontWeight.w800,
                color: Color(AppConfig.PRIMARY_COLOR),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Payment method
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Payment Method',
              style: TextStyle(
                fontSize: 13,
                color: Color(AppConfig.TEXT_SECONDARY),
              ),
            ),
            Text(
              order.mpesaReceipt != null ? 'M-Pesa' : 'Cash on Delivery',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(AppConfig.TEXT_PRIMARY),
              ),
            ),
          ],
        ),
        if (order.mpesaReceipt != null) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'M-Pesa Receipt',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(AppConfig.TEXT_SECONDARY),
                ),
              ),
              Text(
                order.mpesaReceipt!,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(AppConfig.SUCCESS_COLOR),
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// ─── Delivery Info Section ──────────────────────────────

class _DeliveryInfoSection extends StatelessWidget {
  final OrderModel order;
  const _DeliveryInfoSection({required this.order});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.delivery_dining_rounded,
                size: 18, color: Color(AppConfig.PRIMARY_COLOR)),
            SizedBox(width: 8),
            Text(
              'Delivery Info',
              style: TextStyle(
                fontSize: AppConfig.FONT_SIZE_LARGE,
                fontWeight: FontWeight.w700,
                color: Color(AppConfig.TEXT_PRIMARY),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Address
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.location_on_outlined,
                size: 18, color: Color(AppConfig.TEXT_SECONDARY)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                order.deliveryAddress.isNotEmpty
                    ? order.deliveryAddress
                    : 'Address not available',
                style: const TextStyle(
                  fontSize: AppConfig.FONT_SIZE_MEDIUM,
                  color: Color(AppConfig.TEXT_SECONDARY),
                ),
              ),
            ),
          ],
        ),

        // Rider info
        if (order.hasRider) ...[
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(AppConfig.PRIMARY_COLOR)
                      .withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.directions_bike_rounded,
                  size: 20,
                  color: Color(AppConfig.PRIMARY_COLOR),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.riderName!,
                      style: const TextStyle(
                        fontSize: AppConfig.FONT_SIZE_MEDIUM,
                        fontWeight: FontWeight.w600,
                        color: Color(AppConfig.TEXT_PRIMARY),
                      ),
                    ),
                    if (order.riderPhone != null)
                      Text(
                        order.riderPhone!,
                        style: const TextStyle(
                          fontSize: AppConfig.FONT_SIZE_SMALL,
                          color: Color(AppConfig.TEXT_SECONDARY),
                        ),
                      ),
                  ],
                ),
              ),
              // Call Rider button
              if (order.riderPhone != null)
                SizedBox(
                  height: 36,
                  child: ElevatedButton.icon(
                    onPressed: () => _callRider(order.riderPhone!),
                    icon: const Icon(Icons.call_rounded, size: 16),
                    label: const Text('Call'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          const Color(AppConfig.SUCCESS_COLOR),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                            AppConfig.RADIUS_MD),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
            ],
          ),
          // Track Delivery button
          if (order.canTrackRider) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          OrderTrackingScreen(orderId: order.id),
                    ),
                  );
                },
                icon: const Icon(Icons.map_rounded, size: 18),
                label: const Text('Track Delivery'),
                style: OutlinedButton.styleFrom(
                  foregroundColor:
                      const Color(AppConfig.PRIMARY_COLOR),
                  side: const BorderSide(
                      color: Color(AppConfig.PRIMARY_COLOR)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                        AppConfig.RADIUS_MD),
                  ),
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }

  Future<void> _callRider(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}

// ─── Store Info Section ──────────────────────────────

class _StoreInfoSection extends StatelessWidget {
  final OrderModel order;
  const _StoreInfoSection({required this.order});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.pushNamed(
          context,
          '/store-detail',
          arguments: {'vendor_id': 0}, // Would need storeId from order model
        );
      },
      borderRadius: BorderRadius.circular(AppConfig.RADIUS_LG),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.store_rounded,
                  size: 18, color: Color(AppConfig.PRIMARY_COLOR)),
              const SizedBox(width: 8),
              const Text(
                'Store',
                style: TextStyle(
                  fontSize: AppConfig.FONT_SIZE_LARGE,
                  fontWeight: FontWeight.w700,
                  color: Color(AppConfig.TEXT_PRIMARY),
                ),
              ),
              const Spacer(),
              const Icon(Icons.chevron_right_rounded,
                  size: 20, color: Color(AppConfig.TEXT_HINT)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(AppConfig.PRIMARY_COLOR)
                      .withValues(alpha: 0.1),
                  borderRadius:
                      BorderRadius.circular(AppConfig.RADIUS_MD),
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  size: 22,
                  color: Color(AppConfig.PRIMARY_COLOR),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.storeName,
                      style: const TextStyle(
                        fontSize: AppConfig.FONT_SIZE_MEDIUM,
                        fontWeight: FontWeight.w600,
                        color: Color(AppConfig.TEXT_PRIMARY),
                      ),
                    ),
                    if (order.storeCategoryLabel.isNotEmpty)
                      Text(
                        order.storeCategoryLabel,
                        style: const TextStyle(
                          fontSize: AppConfig.FONT_SIZE_SMALL,
                          color: Color(AppConfig.TEXT_SECONDARY),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Category Info Section ──────────────────────────────

class _CategoryInfoSection extends StatelessWidget {
  final OrderModel order;
  const _CategoryInfoSection({required this.order});

  @override
  Widget build(BuildContext context) {
    final List<Widget> items = [];

    if (order.storeCategory == 'pharmacy') {
      items.add(
        _InfoChip(
          icon: Icons.receipt_long_rounded,
          label: 'Prescription Uploaded',
          color: const Color(AppConfig.SUCCESS_COLOR),
        ),
      );
    }

    if (order.storeCategory == 'alcohol') {
      items.add(
        _InfoChip(
          icon: Icons.verified_user_rounded,
          label: 'Age Verified (18+)',
          color: const Color(AppConfig.SUCCESS_COLOR),
        ),
      );
    }

    if (order.storeCategory == 'package') {
      items.add(
        _InfoChip(
          icon: Icons.inventory_2_rounded,
          label: 'Package Delivery',
          color: const Color(0xFFE67E22),
        ),
      );
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.info_outline_rounded,
                size: 18, color: Color(AppConfig.PRIMARY_COLOR)),
            SizedBox(width: 8),
            Text(
              'Order Details',
              style: TextStyle(
                fontSize: AppConfig.FONT_SIZE_LARGE,
                fontWeight: FontWeight.w700,
                color: Color(AppConfig.TEXT_PRIMARY),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: items),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppConfig.RADIUS_ROUND),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
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
            fontSize: 13,
            color: Color(AppConfig.TEXT_SECONDARY),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: valueColor ?? const Color(AppConfig.TEXT_PRIMARY),
          ),
        ),
      ],
    );
  }
}
