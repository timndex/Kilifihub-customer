import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';

import 'config/app_config.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'services/storage_service.dart';
import 'services/push_notification_service.dart';
import 'providers/cart_provider.dart';
import 'providers/order_provider.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/otp_verification_screen.dart';
import 'screens/home_screen.dart';
import 'screens/stores_screen.dart';
import 'screens/store_detail_screen.dart';
import 'screens/product_detail_screen.dart';
import 'screens/search_screen.dart';
import 'screens/cart_screen.dart';
import 'screens/checkout_screen.dart';
import 'screens/orders_screen.dart';
import 'screens/order_detail_screen.dart';
import 'screens/order_tracking_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/addresses_screen.dart';
import 'widgets/loading_widget.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();

  // Initialize SharedPreferences (for StorageService)
  await SharedPreferences.getInstance();

  // Initialize Connectivity (warm up)
  await Connectivity().checkConnectivity();

  runApp(const KilifiHubCustomerApp());
}

class KilifiHubCustomerApp extends StatelessWidget {
  const KilifiHubCustomerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => OrderProvider()),
      ],
      child: MaterialApp(
        title: AppConfig.APP_NAME,
        debugShowCheckedModeBanner: false,

        // ── Theme ──
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: const Color(AppConfig.PRIMARY_COLOR),
          brightness: Brightness.light,

          // Font
          textTheme: GoogleFonts.poppinsTextTheme(
            ThemeData(
              colorSchemeSeed: const Color(AppConfig.PRIMARY_COLOR),
              brightness: Brightness.light,
            ).textTheme,
          ),

          // AppBar
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            foregroundColor: Color(AppConfig.TEXT_PRIMARY),
            elevation: 0,
            centerTitle: false,
            titleTextStyle: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(AppConfig.TEXT_PRIMARY),
            ),
          ),

          // Card
          cardTheme: CardThemeData(
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConfig.RADIUS_LG),
            ),
          ),

          // Elevated Button
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(AppConfig.PRIMARY_COLOR),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConfig.RADIUS_MD),
              ),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),

          // Input Decoration
          inputDecorationTheme: InputDecorationTheme(
            filled: false,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConfig.RADIUS_MD),
            ),
          ),

          // Divider
          dividerTheme: const DividerThemeData(
            color: Color(AppConfig.DIVIDER_COLOR),
            thickness: 1,
          ),

          // Page transitions
          pageTransitionsTheme: const PageTransitionsTheme(
            builders: {
              TargetPlatform.android: CupertinoPageTransitionsBuilder(),
              TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            },
          ),
        ),

        // ── Routes ──
        initialRoute: '/',
        routes: {
          '/': (context) => const AuthWrapper(),
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const RegisterScreen(),
          '/otp-verification': (context) => const OtpVerificationScreen(),
          '/home': (context) => const HomeScreen(),
          '/stores': (context) => const StoresScreen(),
          '/store-detail': (context) => const StoreDetailScreen(),
          '/product-detail': (context) => const ProductDetailScreen(),
          '/search': (context) => const SearchScreen(),
          '/cart': (context) => const CartScreen(),
          '/checkout': (context) => const CheckoutScreen(),
          '/orders': (context) => const OrdersScreen(),
          '/profile': (context) => const ProfileScreen(),
          '/addresses': (context) => const AddressesScreen(),
        },
      ),
    );
  }
}

/// Auth wrapper that checks login state and routes accordingly
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final authService = context.read<AuthService>();
    await authService.checkSession();

    // Load cached cart data
    final cartProvider = context.read<CartProvider>();
    await cartProvider.loadCachedCart();

    // Initialize push notifications if logged in
    if (authService.isLoggedIn) {
      _initNotifications();
    }

    if (mounted) {
      setState(() => _isChecking = false);
    }
  }

  Future<void> _initNotifications() async {
    try {
      final pushService = PushNotificationService.instance;
      await pushService.initialize();

      // Register FCM token with backend
      if (pushService.fcmToken != null) {
        final api = ApiService.instance;
        await api.registerDeviceToken(pushService.fcmToken!);
      }
    } catch (e) {
      debugPrint('Push notification init error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(
        body: Center(
          child: KilifiHubSpinner(size: 48),
        ),
      );
    }

    final authService = context.watch<AuthService>();

    if (authService.isLoggedIn) {
      return const HomeScreen();
    } else {
      return const LoginScreen();
    }
  }
}
