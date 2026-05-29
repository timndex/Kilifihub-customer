/// API Configuration for KilifiHub Customer WordPress Backend
///
/// All endpoints map to the WordPress REST API routes registered
/// in `kilifihub-customer-api.php` under the `kilifi/v1` namespace.
class ApiConfig {
  // ============================================================
  // IMPORTANT: Change this to match your WordPress site URL
  // ============================================================
  static const String BASE_URL = 'http://ats.unaux.com';

  // REST API prefix
  static const String API_PREFIX = '/wp-json/kilifi/v1';

  // ============================================================
  // Browse Endpoints (public)
  // ============================================================

  /// GET /categories — List all active store categories
  static const String CATEGORIES = '$API_PREFIX/categories';

  /// GET /stores — List stores filtered by category
  /// Query: category (required), page, per_page, search, lat, lng
  static const String STORES = '$API_PREFIX/stores';

  /// GET /stores/{id} — Single store detail with products
  static const String STORE_DETAIL = '$API_PREFIX/stores';

  /// GET /stores/{id}/products — Store products with pagination
  /// Query: page, per_page, category, search
  static const String STORE_PRODUCTS = '$API_PREFIX/stores';

  // ============================================================
  // Auth Endpoints (public)
  // ============================================================

  /// POST /customer/register — Register new customer
  /// Body: username, email, phone, password, first_name, last_name
  static const String REGISTER = '$API_PREFIX/customer/register';

  /// POST /customer/login — Login with username/password
  /// Body: username, password (or phone, password)
  static const String LOGIN = '$API_PREFIX/customer/login';

  /// POST /customer/login-phone — Request OTP for phone login
  /// Body: phone
  static const String LOGIN_PHONE = '$API_PREFIX/customer/login-phone';

  /// POST /customer/verify-otp — Verify OTP and authenticate
  /// Body: phone, otp
  static const String VERIFY_OTP = '$API_PREFIX/customer/verify-otp';

  // ============================================================
  // Customer Profile Endpoints (auth required)
  // ============================================================

  /// GET /customer/profile — Get authenticated customer profile
  static const String PROFILE = '$API_PREFIX/customer/profile';

  /// PUT /customer/profile — Update customer profile
  /// Body: first_name, last_name, email, phone
  static const String UPDATE_PROFILE = '$API_PREFIX/customer/profile';

  /// POST /customer/device-token — Register FCM device token
  /// Body: device_token, platform
  static const String DEVICE_TOKEN = '$API_PREFIX/customer/device-token';

  // ============================================================
  // Address Endpoints (auth required)
  // ============================================================

  /// GET /customer/addresses — List saved delivery addresses
  static const String ADDRESSES = '$API_PREFIX/customer/addresses';

  /// POST /customer/addresses — Add a new delivery address
  /// Body: label, address, lat, lng, is_default
  static const String ADD_ADDRESS = '$API_PREFIX/customer/addresses';

  // ============================================================
  // Cart Endpoints (auth required)
  // ============================================================

  /// POST /cart/add — Add item to cart
  /// Body: product_id, quantity
  static const String CART_ADD = '$API_PREFIX/cart/add';

  /// GET /cart — Get current cart
  static const String CART_GET = '$API_PREFIX/cart';

  /// POST /cart/remove — Remove item from cart
  /// Body: cart_item_key
  static const String CART_REMOVE = '$API_PREFIX/cart/remove';

  // ============================================================
  // Checkout Endpoints (auth required)
  // ============================================================

  /// POST /checkout — Place an order
  /// Body: payment_method, mpesa_phone, delivery_address,
  ///       delivery_lat, delivery_lng, delivery_notes,
  ///       prescription_image, age_confirmed, package_details
  static const String CHECKOUT = '$API_PREFIX/checkout';

  // ============================================================
  // Order Endpoints (auth required)
  // ============================================================

  /// GET /orders — List customer orders
  /// Query: page, status
  static const String ORDERS = '$API_PREFIX/orders';

  /// GET /orders/{id} — Single order detail
  static const String ORDER_DETAIL = '$API_PREFIX/orders';

  /// GET /orders/{id}/track — Track order with rider location
  static const String ORDER_TRACK = '$API_PREFIX/orders';

  // ============================================================
  // M-Pesa Endpoints (auth required)
  // ============================================================

  /// POST /mpesa/stk-status — Check STK push status
  /// Body: order_id
  static const String MPESA_STK_STATUS = '$API_PREFIX/mpesa/stk-status';

  /// POST /mpesa/retry-stk — Retry STK push
  /// Body: order_id
  static const String MPESA_RETRY_STK = '$API_PREFIX/mpesa/retry-stk';

  // ============================================================
  // Search Endpoint (public)
  // ============================================================

  /// GET /search — Global search across stores and products
  /// Query: q, category
  static const String SEARCH = '$API_PREFIX/search';

  // ============================================================
  // Timeout Settings (milliseconds)
  // ============================================================
  static const int CONNECT_TIMEOUT = 15000;
  static const int RECEIVE_TIMEOUT = 15000;
  static const int SEND_TIMEOUT = 10000;

  // ============================================================
  // Helper
  // ============================================================

  /// Build full URL from an endpoint path
  static String fullUrl(String endpoint) => '$BASE_URL$endpoint';
}
