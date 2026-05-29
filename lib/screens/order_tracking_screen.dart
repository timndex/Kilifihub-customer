/// Real-time order tracking screen for KilifiHub Customer App
///
/// Features:
/// - Google Maps with store, customer, and rider markers
/// - Live rider tracking with auto-refresh every 5 seconds
/// - Status section with animated step indicators
/// - Rider info card with call/message buttons
/// - ETA display
/// - Pull-to-refresh for manual updates

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../models/order_model.dart';
import '../providers/order_provider.dart';
import '../widgets/empty_state.dart';
import '../widgets/status_badge.dart';

class OrderTrackingScreen extends StatefulWidget {
  final int orderId;

  const OrderTrackingScreen({super.key, required this.orderId});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  GoogleMapController? _mapController;
  final double _defaultLat = -3.6317; // Kilifi, Kenya
  final double _defaultLng = 39.8499;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final orderProvider = context.read<OrderProvider>();
      orderProvider.fetchOrderDetail(widget.orderId);
      orderProvider.startTracking(widget.orderId);
    });
  }

  @override
  void dispose() {
    context.read<OrderProvider>().stopTracking();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppConfig.BACKGROUND_COLOR),
      appBar: AppBar(
        title: const Text('Track Order'),
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

          final order = orderProvider.currentOrder;
          if (order == null) {
            return EmptyState.error(
              message: orderProvider.error ?? 'Order not found.',
              onRetry: () {
                orderProvider.fetchOrderDetail(widget.orderId);
                orderProvider.startTracking(widget.orderId);
              },
            );
          }

          final trackingData = orderProvider.trackingData;

          return RefreshIndicator(
            color: const Color(AppConfig.PRIMARY_COLOR),
            onRefresh: () => orderProvider.fetchOrderDetail(widget.orderId),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Map
                  SizedBox(
                    height: 280,
                    child: _MapSection(
                      order: order,
                      trackingData: trackingData,
                      defaultLat: _defaultLat,
                      defaultLng: _defaultLng,
                      onMapCreated: (controller) {
                        _mapController = controller;
                      },
                    ),
                  ),

                  // Status section
                  _StatusSection(order: order),

                  const SizedBox(height: 12),

                  // Rider info card
                  if (order.hasRider)
                    _RiderInfoCard(order: order),

                  const SizedBox(height: 12),

                  // ETA section
                  _ETASection(order: order, trackingData: trackingData),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Map Section ──────────────────────────────────────────

class _MapSection extends StatelessWidget {
  final OrderModel order;
  final Map<String, dynamic>? trackingData;
  final double defaultLat;
  final double defaultLng;
  final ValueChanged<GoogleMapController> onMapCreated;

  const _MapSection({
    required this.order,
    this.trackingData,
    required this.defaultLat,
    required this.defaultLng,
    required this.onMapCreated,
  });

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>{};

    // Store marker (pickup)
    final storeLat = trackingData?['store_lat'] as double? ?? defaultLat - 0.01;
    final storeLng = trackingData?['store_lng'] as double? ?? defaultLng - 0.01;

    markers.add(Marker(
      markerId: const MarkerId('store'),
      position: LatLng(storeLat, storeLng),
      infoWindow: InfoWindow(
        title: order.storeName,
        snippet: 'Pickup location',
      ),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
    ));

    // Customer marker (delivery)
    final custLat = trackingData?['customer_lat'] as double? ?? defaultLat + 0.01;
    final custLng = trackingData?['customer_lng'] as double? ?? defaultLng + 0.01;

    markers.add(Marker(
      markerId: const MarkerId('customer'),
      position: LatLng(custLat, custLng),
      infoWindow: const InfoWindow(
        title: 'Delivery Location',
        snippet: 'Your location',
      ),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
    ));

    // Rider marker (live)
    final riderLat = order.riderLat ?? trackingData?['rider_lat'] as double?;
    final riderLng = order.riderLng ?? trackingData?['rider_lng'] as double?;

    if (riderLat != null && riderLng != null) {
      markers.add(Marker(
        markerId: const MarkerId('rider'),
        position: LatLng(riderLat, riderLng),
        infoWindow: InfoWindow(
          title: order.riderName ?? 'Rider',
          snippet: 'Your delivery rider',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        rotation: trackingData?['rider_heading'] as double? ?? 0,
      ));
    }

    // Determine camera position
    LatLng cameraTarget;
    double zoom;

    if (riderLat != null && riderLng != null) {
      // Center between all markers
      final allLat = [storeLat, custLat, riderLat];
      final allLng = [storeLng, custLng, riderLng];
      cameraTarget = LatLng(
        (allLat.reduce((a, b) => a + b)) / allLat.length,
        (allLng.reduce((a, b) => a + b)) / allLng.length,
      );
      zoom = 14;
    } else {
      // Center between store and customer
      cameraTarget = LatLng(
        (storeLat + custLat) / 2,
        (storeLng + custLng) / 2,
      );
      zoom = 14;
    }

    return Stack(
      children: [
        GoogleMap(
          onMapCreated: onMapCreated,
          initialCameraPosition: CameraPosition(
            target: cameraTarget,
            zoom: zoom,
          ),
          markers: markers,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          myLocationButtonEnabled: false,
          compassEnabled: true,
          trafficEnabled: true,
        ),
        // Map overlay legend
        Positioned(
          bottom: 12,
          left: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppConfig.RADIUS_MD),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MapLegend(color: Colors.red, label: 'Store'),
                const SizedBox(width: 10),
                _MapLegend(color: Colors.blue, label: 'Rider'),
                const SizedBox(width: 10),
                _MapLegend(color: Colors.green, label: 'You'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MapLegend extends StatelessWidget {
  final Color color;
  final String label;
  const _MapLegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(AppConfig.TEXT_PRIMARY),
          ),
        ),
      ],
    );
  }
}

// ─── Status Section ──────────────────────────────────────────

class _StatusSection extends StatelessWidget {
  final OrderModel order;
  const _StatusSection({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
          // Current status
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: order.statusColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  order.statusIcon,
                  size: 22,
                  color: order.statusColor,
                ),
              ),
              const SizedBox(width: 12),
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
            ],
          ),
          const SizedBox(height: 20),

          // Simplified status steps
          _StatusSteps(currentStatus: order.status),
        ],
      ),
    );
  }
}

// ─── Status Steps (simplified horizontal) ──────────────────

class _StatusSteps extends StatelessWidget {
  final String currentStatus;
  const _StatusSteps({required this.currentStatus});

  @override
  Widget build(BuildContext context) {
    final steps = [
      _StepData('Confirmed', Icons.check_circle_rounded),
      _StepData('Preparing', Icons.restaurant_rounded),
      _StepData('On the Way', Icons.delivery_dining_rounded),
      _StepData('Delivered', Icons.home_rounded),
    ];

    final currentIndex = _getCurrentStepIndex();

    return Row(
      children: steps.asMap().entries.map((entry) {
        final index = entry.key;
        final step = entry.value;
        final isCompleted = index < currentIndex;
        final isCurrent = index == currentIndex;
        final isLast = index == steps.length - 1;

        return Expanded(
          child: Row(
            children: [
              // Step dot
              Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: isCurrent ? 32 : 24,
                    height: isCurrent ? 32 : 24,
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? const Color(AppConfig.SUCCESS_COLOR)
                          : isCurrent
                              ? const Color(AppConfig.PRIMARY_COLOR)
                              : const Color(AppConfig.DIVIDER_COLOR),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isCompleted
                          ? Icons.check_rounded
                          : step.icon,
                      size: isCurrent ? 16 : 12,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    step.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight:
                          isCurrent ? FontWeight.w700 : FontWeight.w500,
                      color: isCompleted || isCurrent
                          ? const Color(AppConfig.TEXT_PRIMARY)
                          : const Color(AppConfig.TEXT_HINT),
                    ),
                  ),
                ],
              ),
              // Connector line
              if (!isLast)
                Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.only(bottom: 20),
                    color: isCompleted
                        ? const Color(AppConfig.SUCCESS_COLOR)
                        : const Color(AppConfig.DIVIDER_COLOR),
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  int _getCurrentStepIndex() {
    switch (currentStatus) {
      case 'pending':
        return 0;
      case 'processing':
        return 1;
      case 'courier-assignment':
      case 'courier-assigned':
      case 'rider-accepted':
        return 1;
      case 'rider-picked-up':
      case 'rider-on-the-way':
        return 2;
      case 'completed':
      case 'delivered':
        return 3;
      default:
        return 0;
    }
  }
}

class _StepData {
  final String label;
  final IconData icon;
  _StepData(this.label, this.icon);
}

// ─── Rider Info Card ──────────────────────────────────────

class _RiderInfoCard extends StatelessWidget {
  final OrderModel order;
  const _RiderInfoCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
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
      child: Row(
        children: [
          // Avatar
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(AppConfig.PRIMARY_COLOR).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.directions_bike_rounded,
              size: 24,
              color: Color(AppConfig.PRIMARY_COLOR),
            ),
          ),
          const SizedBox(width: 12),

          // Name & phone
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.riderName ?? 'Rider',
                  style: const TextStyle(
                    fontSize: AppConfig.FONT_SIZE_LARGE,
                    fontWeight: FontWeight.w700,
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

          // Call button
          if (order.riderPhone != null)
            _ActionButton(
              icon: Icons.call_rounded,
              label: 'Call',
              color: const Color(AppConfig.SUCCESS_COLOR),
              onTap: () => _callRider(order.riderPhone!),
            ),

          const SizedBox(width: 8),

          // Message button
          if (order.riderPhone != null)
            _ActionButton(
              icon: Icons.message_rounded,
              label: 'SMS',
              color: const Color(0xFF2196F3),
              onTap: () => _messageRider(order.riderPhone!),
            ),
        ],
      ),
    );
  }

  Future<void> _callRider(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _messageRider(String phone) async {
    final uri = Uri.parse('sms:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppConfig.RADIUS_MD),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── ETA Section ──────────────────────────────────────

class _ETASection extends StatelessWidget {
  final OrderModel order;
  final Map<String, dynamic>? trackingData;

  const _ETASection({
    required this.order,
    this.trackingData,
  });

  @override
  Widget build(BuildContext context) {
    final eta = trackingData?['eta'] as String? ?? '15-20 min';
    final distance = trackingData?['distance'] as String?;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
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
          Row(
            children: [
              const Icon(Icons.access_time_rounded,
                  size: 18, color: Color(AppConfig.PRIMARY_COLOR)),
              const SizedBox(width: 8),
              const Text(
                'Estimated Arrival',
                style: TextStyle(
                  fontSize: AppConfig.FONT_SIZE_LARGE,
                  fontWeight: FontWeight.w700,
                  color: Color(AppConfig.TEXT_PRIMARY),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                eta,
                style: const TextStyle(
                  fontSize: AppConfig.FONT_SIZE_TITLE,
                  fontWeight: FontWeight.w800,
                  color: Color(AppConfig.PRIMARY_COLOR),
                ),
              ),
              if (distance != null) ...[
                const SizedBox(width: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(AppConfig.BACKGROUND_COLOR),
                    borderRadius: BorderRadius.circular(AppConfig.RADIUS_ROUND),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.straighten_rounded,
                          size: 14, color: Color(AppConfig.TEXT_SECONDARY)),
                      const SizedBox(width: 4),
                      Text(
                        distance,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(AppConfig.TEXT_SECONDARY),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Updates automatically as the rider moves',
            style: TextStyle(
              fontSize: AppConfig.FONT_SIZE_SMALL,
              color: Color(AppConfig.TEXT_HINT),
            ),
          ),
        ],
      ),
    );
  }
}
