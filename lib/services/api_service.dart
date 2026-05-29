/// Centralized API service for all KilifiHub Customer WordPress backend communication
///
/// Follows the same pattern as the rider app's ApiService:
/// - Singleton pattern
/// - Dio instance with browser-like User-Agent
/// - Connectivity check interceptor
/// - Anti-bot detection interceptor (for free hosting providers)
/// - Auth token interceptor with 401 retry
/// - PrettyDioLogger in debug mode

import 'package:dio/dio.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../config/api_config.dart';
import '../models/category_model.dart';
import '../models/store_model.dart';
import '../models/product_model.dart';
import '../models/cart_model.dart';
import '../models/order_model.dart';
import '../models/address_model.dart';
import '../models/user_model.dart';
import 'storage_service.dart';

class ApiService {
  static ApiService? _instance;
  late final Dio _dio;
  final StorageService _storage = StorageService.instance;

  ApiService._() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConfig.BASE_URL,
      connectTimeout:
          Duration(milliseconds: ApiConfig.CONNECT_TIMEOUT),
      receiveTimeout:
          Duration(milliseconds: ApiConfig.RECEIVE_TIMEOUT),
      sendTimeout:
          Duration(milliseconds: ApiConfig.SEND_TIMEOUT),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        // Browser-like User-Agent helps with some hosting providers
        // that block requests without a standard browser UA
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      },
      followRedirects: true,
      maxRedirects: 5,
    ));

    // ── Connectivity check interceptor ──
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final connectivityResult =
            await Connectivity().checkConnectivity();
        if (connectivityResult.contains(ConnectivityResult.none)) {
          return handler.reject(DioException(
            requestOptions: options,
            error:
                'No internet connection. Please check your network settings.',
            type: DioExceptionType.connectionError,
          ));
        }
        handler.next(options);
      },
    ));

    // ── Anti-bot / hosting protection detection interceptor ──
    _dio.interceptors.add(InterceptorsWrapper(
      onResponse: (response, handler) {
        final data = response.data;
        if (data is String &&
            data.contains('__test') &&
            data.contains('slowAES')) {
          return handler.reject(DioException(
            requestOptions: response.requestOptions,
            error: 'Server protection detected. Your hosting provider '
                'is blocking API requests. Please switch to a hosting '
                'provider that allows direct API access, or enable '
                '"Direct Access" in your hosting control panel.',
            type: DioExceptionType.badResponse,
            response: response,
          ));
        }
        handler.next(response);
      },
    ));

    // ── Auth token interceptor with 401 retry ──
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.getAuthToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          // Token expired — try re-authenticating with stored credentials
          final refreshed = await _attemptTokenRefresh();
          if (refreshed) {
            final token = await _storage.getAuthToken();
            error.requestOptions.headers['Authorization'] =
                'Bearer $token';
            try {
              final response =
                  await _dio.fetch(error.requestOptions);
              return handler.resolve(response);
            } catch (_) {
              // Retry failed, fall through
            }
          }
        }
        handler.next(error);
      },
    ));

    // ── Logging in debug mode ──
    if (kDebugMode) {
      _dio.interceptors.add(PrettyDioLogger(
        requestHeader: true,
        requestBody: true,
        responseHeader: false,
        compact: true,
      ));
    }
  }

  static ApiService get instance {
    _instance ??= ApiService._();
    return _instance!;
  }

  Dio get dio => _dio;

  /// Attempt to refresh the auth token.
  ///
  /// Unlike the rider app (which has a dedicated refresh-token endpoint),
  /// the customer API uses simple token-based auth stored in user meta.
  /// If the token expires, the user must re-login.
  Future<bool> _attemptTokenRefresh() async {
    // Customer API does not have a refresh-token endpoint.
    // Token expiry requires re-login. Return false to trigger logout.
    return false;
  }

  // ============================================================
  // CATEGORIES
  // ============================================================

  /// GET /categories — List all active store categories
  Future<List<CategoryModel>> getCategories() async {
    final response = await _dio.get(ApiConfig.CATEGORIES);
    final data = response.data as Map<String, dynamic>;
    final rawCategories = data['categories'] as List<dynamic>? ?? [];
    return rawCategories
        .map((e) =>
            CategoryModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ============================================================
  // STORES
  // ============================================================

  /// GET /stores — List stores filtered by category
  Future<List<StoreModel>> getStores(
    String category, {
    int page = 1,
    String? search,
    double? lat,
    double? lng,
  }) async {
    final response = await _dio.get(
      ApiConfig.STORES,
      queryParameters: {
        'category': category,
        'page': page,
        if (search != null) 'search': search,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
      },
    );
    final data = response.data as Map<String, dynamic>;
    final rawStores = data['stores'] as List<dynamic>? ?? [];
    return rawStores
        .map((e) =>
            StoreModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /stores/{id} — Single store detail
  Future<Map<String, dynamic>> getStoreDetail(int vendorId) async {
    final response =
        await _dio.get('${ApiConfig.STORE_DETAIL}/$vendorId');
    return response.data as Map<String, dynamic>;
  }

  /// GET /stores/{id}/products — Store products with pagination
  Future<List<ProductModel>> getStoreProducts(
    int vendorId, {
    int page = 1,
    String? search,
  }) async {
    final response = await _dio.get(
      '${ApiConfig.STORE_PRODUCTS}/$vendorId/products',
      queryParameters: {
        'page': page,
        if (search != null) 'search': search,
      },
    );
    final data = response.data as Map<String, dynamic>;
    final rawProducts = data['products'] as List<dynamic>? ?? [];
    return rawProducts
        .map((e) =>
            ProductModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ============================================================
  // AUTH
  // ============================================================

  /// POST /customer/register — Register new customer
  Future<UserModel> register(
    String username,
    String email,
    String phone,
    String password,
    String firstName,
    String lastName,
  ) async {
    final response = await _dio.post(
      ApiConfig.REGISTER,
      data: {
        'username': username,
        'email': email,
        'phone': phone,
        'password': password,
        'first_name': firstName,
        'last_name': lastName,
      },
    );
    return UserModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// POST /customer/login — Login with username/password
  Future<UserModel> login(String username, String password) async {
    final response = await _dio.post(
      ApiConfig.LOGIN,
      data: {
        'username': username,
        'password': password,
      },
    );
    return UserModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// POST /customer/login-phone — Request OTP for phone login
  Future<Map<String, dynamic>> loginPhone(String phone) async {
    final response = await _dio.post(
      ApiConfig.LOGIN_PHONE,
      data: {'phone': phone},
    );
    return response.data as Map<String, dynamic>;
  }

  /// POST /customer/verify-otp — Verify OTP and authenticate
  Future<UserModel> verifyOtp(String phone, String otp) async {
    final response = await _dio.post(
      ApiConfig.VERIFY_OTP,
      data: {'phone': phone, 'otp': otp},
    );
    return UserModel.fromJson(response.data as Map<String, dynamic>);
  }

  // ============================================================
  // PROFILE
  // ============================================================

  /// GET /customer/profile — Get authenticated customer profile
  Future<UserModel> getProfile() async {
    final response = await _dio.get(ApiConfig.PROFILE);
    return UserModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// PUT /customer/profile — Update customer profile
  Future<UserModel> updateProfile({
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
  }) async {
    final response = await _dio.put(
      ApiConfig.UPDATE_PROFILE,
      data: {
        if (firstName != null) 'first_name': firstName,
        if (lastName != null) 'last_name': lastName,
        if (email != null) 'email': email,
        if (phone != null) 'phone': phone,
      },
    );
    return UserModel.fromJson(response.data as Map<String, dynamic>);
  }

  // ============================================================
  // DEVICE TOKEN
  // ============================================================

  /// POST /customer/device-token — Register FCM device token
  Future<Map<String, dynamic>> registerDeviceToken(
      String token) async {
    final response = await _dio.post(
      ApiConfig.DEVICE_TOKEN,
      data: {
        'device_token': token,
        'platform': 'android',
      },
    );
    return response.data as Map<String, dynamic>;
  }

  // ============================================================
  // ADDRESSES
  // ============================================================

  /// GET /customer/addresses — List saved delivery addresses
  Future<List<AddressModel>> getAddresses() async {
    final response = await _dio.get(ApiConfig.ADDRESSES);
    final data = response.data;
    if (data is List) {
      return data
          .map((e) =>
              AddressModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    // Some APIs wrap in an object
    if (data is Map<String, dynamic>) {
      final rawAddresses =
          data['addresses'] as List<dynamic>? ?? [];
      return rawAddresses
          .map((e) =>
              AddressModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// POST /customer/addresses — Add a new delivery address
  Future<AddressModel> addAddress(
    String label,
    String address,
    double? lat,
    double? lng,
    bool isDefault,
  ) async {
    final response = await _dio.post(
      ApiConfig.ADD_ADDRESS,
      data: {
        'label': label,
        'address': address,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        'is_default': isDefault,
      },
    );
    return AddressModel.fromJson(
        response.data as Map<String, dynamic>);
  }

  // ============================================================
  // CART
  // ============================================================

  /// POST /cart/add — Add item to cart
  Future<CartModel> addToCart(int productId, int quantity) async {
    final response = await _dio.post(
      ApiConfig.CART_ADD,
      data: {
        'product_id': productId,
        'quantity': quantity,
      },
    );
    return CartModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// GET /cart — Get current cart
  Future<CartModel> getCart() async {
    final response = await _dio.get(ApiConfig.CART_GET);
    return CartModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// POST /cart/remove — Remove item from cart
  Future<CartModel> removeFromCart(String cartItemKey) async {
    final response = await _dio.post(
      ApiConfig.CART_REMOVE,
      data: {'cart_item_key': cartItemKey},
    );
    return CartModel.fromJson(response.data as Map<String, dynamic>);
  }

  // ============================================================
  // CHECKOUT
  // ============================================================

  /// POST /checkout — Place an order
  Future<Map<String, dynamic>> checkout({
    required String paymentMethod,
    String? mpesaPhone,
    String? deliveryAddress,
    double? deliveryLat,
    double? deliveryLng,
    String? deliveryNotes,
    String? prescriptionImage,
    bool? ageConfirmed,
    Map<String, dynamic>? packageDetails,
  }) async {
    final response = await _dio.post(
      ApiConfig.CHECKOUT,
      data: {
        'payment_method': paymentMethod,
        if (mpesaPhone != null) 'mpesa_phone': mpesaPhone,
        if (deliveryAddress != null)
          'delivery_address': deliveryAddress,
        if (deliveryLat != null) 'delivery_lat': deliveryLat,
        if (deliveryLng != null) 'delivery_lng': deliveryLng,
        if (deliveryNotes != null)
          'delivery_notes': deliveryNotes,
        if (prescriptionImage != null)
          'prescription_image': prescriptionImage,
        if (ageConfirmed != null) 'age_confirmed': ageConfirmed,
        if (packageDetails != null)
          'package_details': packageDetails,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  // ============================================================
  // ORDERS
  // ============================================================

  /// GET /orders — List customer orders
  Future<List<OrderModel>> getOrders({
    int page = 1,
    String? status,
  }) async {
    final response = await _dio.get(
      ApiConfig.ORDERS,
      queryParameters: {
        'page': page,
        if (status != null) 'status': status,
      },
    );
    final data = response.data;
    if (data is List) {
      return data
          .map((e) =>
              OrderModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    if (data is Map<String, dynamic>) {
      final rawOrders =
          data['orders'] as List<dynamic>? ?? [];
      return rawOrders
          .map((e) =>
              OrderModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// GET /orders/{id} — Single order detail
  Future<OrderModel> getOrderDetail(int orderId) async {
    final response =
        await _dio.get('${ApiConfig.ORDER_DETAIL}/$orderId');
    return OrderModel.fromJson(
        response.data as Map<String, dynamic>);
  }

  /// GET /orders/{id}/track — Track order with rider location
  Future<Map<String, dynamic>> trackOrder(int orderId) async {
    final response =
        await _dio.get('${ApiConfig.ORDER_TRACK}/$orderId/track');
    return response.data as Map<String, dynamic>;
  }

  // ============================================================
  // M-PESA
  // ============================================================

  /// POST /mpesa/stk-status — Check STK push status
  Future<Map<String, dynamic>> checkMpesaStatus(
      int orderId) async {
    final response = await _dio.post(
      ApiConfig.MPESA_STK_STATUS,
      data: {'order_id': orderId},
    );
    return response.data as Map<String, dynamic>;
  }

  /// POST /mpesa/retry-stk — Retry STK push
  Future<Map<String, dynamic>> retryStk(int orderId) async {
    final response = await _dio.post(
      ApiConfig.MPESA_RETRY_STK,
      data: {'order_id': orderId},
    );
    return response.data as Map<String, dynamic>;
  }

  // ============================================================
  // SEARCH
  // ============================================================

  /// GET /search — Global search across stores and products
  Future<Map<String, dynamic>> search(
    String q, {
    String? category,
  }) async {
    final response = await _dio.get(
      ApiConfig.SEARCH,
      queryParameters: {
        'q': q,
        if (category != null) 'category': category,
      },
    );
    return response.data as Map<String, dynamic>;
  }
}
