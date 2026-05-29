/// App-wide configuration and constants for KilifiHub Customer App
class AppConfig {
  // App Info
  static const String APP_NAME = 'KilifiHub';
  static const String APP_VERSION = '1.0.0';

  // Colors — same scheme as rider app
  static const int PRIMARY_COLOR = 0xFFE23744; // KilifiHub red
  static const int SECONDARY_COLOR = 0xFF2D2D2D;
  static const int ACCENT_COLOR = 0xFFFFB800;
  static const int SUCCESS_COLOR = 0xFF4CAF50;
  static const int WARNING_COLOR = 0xFFFF9800;
  static const int ERROR_COLOR = 0xFFE23744;
  static const int BACKGROUND_COLOR = 0xFFF5F5F5;
  static const int CARD_COLOR = 0xFFFFFFFF;
  static const int TEXT_PRIMARY = 0xFF2D2D2D;
  static const int TEXT_SECONDARY = 0xFF757575;
  static const int TEXT_HINT = 0xFFBDBDBD;
  static const int DIVIDER_COLOR = 0xFFEEEEEE;

  // Category Colors — matching the WordPress backend category config
  static const Map<String, int> CATEGORY_COLORS = {
    'hotel': 0xFFFF6B35,
    'pharmacy': 0xFF00A082,
    'supermarket': 0xFF4A90D9,
    'groceries': 0xFF2ECC71,
    'shops': 0xFF9B59B6,
    'package': 0xFFE67E22,
    'alcohol': 0xFF8E44AD,
  };

  // Typography
  static const String FONT_FAMILY = 'Poppins';
  static const double FONT_SIZE_SMALL = 12.0;
  static const double FONT_SIZE_MEDIUM = 14.0;
  static const double FONT_SIZE_LARGE = 16.0;
  static const double FONT_SIZE_XLARGE = 20.0;
  static const double FONT_SIZE_XXLARGE = 24.0;
  static const double FONT_SIZE_TITLE = 28.0;

  // Spacing
  static const double SPACING_XS = 4.0;
  static const double SPACING_SM = 8.0;
  static const double SPACING_MD = 16.0;
  static const double SPACING_LG = 24.0;
  static const double SPACING_XL = 32.0;

  // Border Radius
  static const double RADIUS_SM = 4.0;
  static const double RADIUS_MD = 8.0;
  static const double RADIUS_LG = 12.0;
  static const double RADIUS_XL = 16.0;
  static const double RADIUS_ROUND = 50.0;

  // Elevation
  static const double ELEVATION_SM = 2.0;
  static const double ELEVATION_MD = 4.0;
  static const double ELEVATION_LG = 8.0;

  // Icon Sizes
  static const double ICON_SIZE_SM = 16.0;
  static const double ICON_SIZE_MD = 24.0;
  static const double ICON_SIZE_LG = 32.0;
  static const double ICON_SIZE_XL = 48.0;

  // Animation Durations (milliseconds)
  static const int ANIM_FAST = 200;
  static const int ANIM_NORMAL = 300;
  static const int ANIM_SLOW = 500;

  // Notification Channel
  static const String NOTIFICATION_CHANNEL_ID = 'kilifihub_customer_orders';
  static const String NOTIFICATION_CHANNEL_NAME = 'Order Updates';
  static const String NOTIFICATION_CHANNEL_DESC =
      'Notifications for order status updates and deliveries';

  // Currency
  static const String CURRENCY_SYMBOL = 'KSh';
  static const String CURRENCY_CODE = 'KES';

  // Delivery
  static const double DEFAULT_DELIVERY_FEE = 150.0;
  static const int ORDER_TRACKING_INTERVAL_SECONDS = 5;

  // Pagination
  static const int DEFAULT_PAGE_SIZE = 20;

  /// Get category color value, returns [PRIMARY_COLOR] if not found
  static int getCategoryColor(String slug) {
    return CATEGORY_COLORS[slug] ?? PRIMARY_COLOR;
  }
}
