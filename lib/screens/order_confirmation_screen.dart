/// Order confirmation screen for KilifiHub Customer App
///
/// Shown after successful order placement (COD or after M-Pesa success).
/// Features a green checkmark animation, order details, and auto-redirect.

import 'dart:async';
import 'package:flutter/material.dart';

import '../config/app_config.dart';
import 'order_tracking_screen.dart';
import 'order_detail_screen.dart';

class OrderConfirmationScreen extends StatefulWidget {
  final int orderId;
  final String orderNumber;
  final bool isMpesa;

  const OrderConfirmationScreen({
    super.key,
    required this.orderId,
    required this.orderNumber,
    this.isMpesa = false,
  });

  @override
  State<OrderConfirmationScreen> createState() =>
      _OrderConfirmationScreenState();
}

class _OrderConfirmationScreenState extends State<OrderConfirmationScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _checkController;
  late Animation<double> _checkScaleAnimation;
  late Animation<double> _fadeInAnimation;
  Timer? _redirectTimer;

  @override
  void initState() {
    super.initState();

    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _checkScaleAnimation = CurvedAnimation(
      parent: _checkController,
      curve: Curves.elasticOut,
    );

    _fadeInAnimation = CurvedAnimation(
      parent: _checkController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    );

    _checkController.forward();

    // Auto-redirect to order tracking after 3 seconds
    _redirectTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => OrderTrackingScreen(orderId: widget.orderId),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _redirectTimer?.cancel();
    _checkController.dispose();
    super.dispose();
  }

  void _navigateToTracking() {
    _redirectTimer?.cancel();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => OrderTrackingScreen(orderId: widget.orderId),
      ),
    );
  }

  void _navigateToDetail() {
    _redirectTimer?.cancel();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => OrderDetailScreen(orderId: widget.orderId),
      ),
    );
  }

  void _continueShopping() {
    _redirectTimer?.cancel();
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/home',
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 40),

                // Animated checkmark
                ScaleTransition(
                  scale: _checkScaleAnimation,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color:
                          const Color(AppConfig.SUCCESS_COLOR).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      size: 80,
                      color: Color(AppConfig.SUCCESS_COLOR),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Title
                FadeTransition(
                  opacity: _fadeInAnimation,
                  child: const Text(
                    'Order Placed Successfully!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: AppConfig.FONT_SIZE_XXLARGE,
                      fontWeight: FontWeight.w800,
                      color: Color(AppConfig.TEXT_PRIMARY),
                      height: 1.2,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Order number
                FadeTransition(
                  opacity: _fadeInAnimation,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(AppConfig.BACKGROUND_COLOR),
                      borderRadius: BorderRadius.circular(AppConfig.RADIUS_ROUND),
                    ),
                    child: Text(
                      'Order #${widget.orderNumber}',
                      style: const TextStyle(
                        fontSize: AppConfig.FONT_SIZE_LARGE,
                        fontWeight: FontWeight.w700,
                        color: Color(AppConfig.TEXT_PRIMARY),
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Estimated delivery
                FadeTransition(
                  opacity: _fadeInAnimation,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.access_time_rounded,
                        size: 18,
                        color: Color(AppConfig.TEXT_SECONDARY),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        widget.isMpesa
                            ? 'Estimated delivery: 25-40 min'
                            : 'Estimated delivery: 30-45 min',
                        style: const TextStyle(
                          fontSize: AppConfig.FONT_SIZE_MEDIUM,
                          color: Color(AppConfig.TEXT_SECONDARY),
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Action buttons
                FadeTransition(
                  opacity: _fadeInAnimation,
                  child: Column(
                    children: [
                      // Track Order (primary)
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _navigateToTracking,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color(AppConfig.PRIMARY_COLOR),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppConfig.RADIUS_MD),
                            ),
                          ),
                          child: const Text(
                            'Track Order',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // View Order Details (secondary)
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton(
                          onPressed: _navigateToDetail,
                          style: OutlinedButton.styleFrom(
                            foregroundColor:
                                const Color(AppConfig.PRIMARY_COLOR),
                            side: const BorderSide(
                                color: Color(AppConfig.PRIMARY_COLOR)),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppConfig.RADIUS_MD),
                            ),
                          ),
                          child: const Text(
                            'View Order Details',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Continue Shopping
                      TextButton(
                        onPressed: _continueShopping,
                        child: const Text(
                          'Continue Shopping',
                          style: TextStyle(
                            color: Color(AppConfig.TEXT_SECONDARY),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Auto-redirect notice
                FadeTransition(
                  opacity: _fadeInAnimation,
                  child: const Text(
                    'Redirecting to order tracking...',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(AppConfig.TEXT_HINT),
                    ),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
