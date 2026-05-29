/// Order provider for the KilifiHub Customer App
///
/// Manages order listing, detail, and real-time tracking state
/// using ChangeNotifier. Includes periodic polling for active
/// order tracking (every 5 seconds).

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/order_model.dart';
import '../config/app_config.dart';
import '../services/api_service.dart';

class OrderProvider extends ChangeNotifier {
  final ApiService _api = ApiService.instance;

  List<OrderModel> _orders = [];
  OrderModel? _currentOrder;
  Map<String, dynamic>? _trackingData;
  bool _isLoading = false;
  String? _error;

  // Timer for periodic order tracking
  Timer? _trackingTimer;
  int? _trackingOrderId;

  // ── Getters ──

  /// List of customer orders
  List<OrderModel> get orders => _orders;

  /// Currently viewed order detail
  OrderModel? get currentOrder => _currentOrder;

  /// Live tracking data (rider location, ETA, etc.)
  Map<String, dynamic>? get trackingData => _trackingData;

  /// Whether an order operation is in progress
  bool get isLoading => _isLoading;

  /// Last error message, if any
  String? get error => _error;

  /// Whether tracking is currently active
  bool get isTracking => _trackingTimer != null &&
      _trackingTimer!.isActive;

  /// Active orders (currently in progress)
  List<OrderModel> get activeOrders =>
      _orders.where((o) => o.isActive).toList();

  /// Past orders (completed, cancelled, etc.)
  List<OrderModel> get pastOrders =>
      _orders.where((o) => !o.isActive).toList();

  // ── Order List ──

  /// Fetch the list of customer orders
  ///
  /// Optionally filter by [status].
  Future<void> fetchOrders({String? status}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _orders = await _api.getOrders(status: status);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = _extractError(e);
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Order Detail ──

  /// Fetch a single order's detail
  Future<void> fetchOrderDetail(int orderId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _currentOrder = await _api.getOrderDetail(orderId);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = _extractError(e);
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Order Tracking ──

  /// Track an order with a single request
  ///
  /// For continuous tracking, use [startTracking] instead.
  Future<void> trackOrder(int orderId) async {
    try {
      _trackingData = await _api.trackOrder(orderId);
      notifyListeners();
    } catch (e) {
      debugPrint('Track order error: $e');
    }
  }

  /// Start periodic tracking of an active order
  ///
  /// Polls the tracking endpoint every 5 seconds while
  /// the order is still active. Automatically stops when
  /// the order is completed or cancelled.
  void startTracking(int orderId) {
    // Stop any existing tracking
    stopTracking();

    _trackingOrderId = orderId;

    // Immediately fetch tracking data
    trackOrder(orderId);

    // Set up periodic polling
    _trackingTimer = Timer.periodic(
      Duration(
          seconds: AppConfig.ORDER_TRACKING_INTERVAL_SECONDS),
      (timer) async {
        try {
          _trackingData =
              await _api.trackOrder(orderId);

          // Also refresh the order detail
          _currentOrder =
              await _api.getOrderDetail(orderId);

          // Stop tracking if order is no longer active
          if (_currentOrder != null &&
              !_currentOrder!.isActive) {
            stopTracking();
          }

          notifyListeners();
        } catch (e) {
          debugPrint('Tracking poll error: $e');
          // Don't stop tracking on transient errors
        }
      },
    );

    notifyListeners();
  }

  /// Stop periodic order tracking
  void stopTracking() {
    _trackingTimer?.cancel();
    _trackingTimer = null;
    _trackingOrderId = null;
    notifyListeners();
  }

  /// Check if a specific order is currently being tracked
  bool isOrderTracked(int orderId) {
    return _trackingOrderId == orderId && isTracking;
  }

  // ── Cleanup ──

  @override
  void dispose() {
    stopTracking();
    super.dispose();
  }

  // ── Error Handling ──

  String _extractError(dynamic e) {
    final errorStr = e.toString();

    if (errorStr.contains('401')) {
      return 'Please log in to view your orders.';
    }
    if (errorStr.contains('404')) {
      return 'Order not found.';
    }
    if (errorStr.contains('SocketException') ||
        errorStr.contains('Failed host lookup')) {
      return 'No internet connection. Please check your network.';
    }
    if (errorStr.contains('TimeoutException') ||
        errorStr.contains('timed out')) {
      return 'Connection timed out. Please try again.';
    }

    return 'Failed to load orders. Please try again.';
  }
}
