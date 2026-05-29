/// Push notification service with Firebase Cloud Messaging (FCM) support
///
/// Handles both remote (FCM) and local notifications:
/// - FCM: Receives push notifications when app is in background/terminated
/// - Local: Shows notifications for in-app events (order updates, etc.)
///
/// Setup:
/// 1. Firebase project configured with Android app
/// 2. google-services.json in android/app/
/// 3. FirebaseMessagingService in AndroidManifest.xml

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../config/app_config.dart';
import 'api_service.dart';
import 'storage_service.dart';

class PushNotificationService {
  static PushNotificationService? _instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final ApiService _api = ApiService.instance;
  final StorageService _storage = StorageService.instance;

  String? _fcmToken;

  /// Callback when a notification is tapped and contains an order_id
  Function(int)? onOrderNotification;

  /// Callback when a notification is tapped and contains a promo/category
  Function(Map<String, dynamic>)? onPromoNotification;

  PushNotificationService._();

  static PushNotificationService get instance {
    _instance ??= PushNotificationService._();
    return _instance!;
  }

  String? get fcmToken => _fcmToken;

  /// Initialize push notifications (FCM + local)
  Future<void> initialize() async {
    // Request notification permission (Android 13+, iOS)
    await _requestPermission();

    // Setup FCM
    await _setupFirebaseMessaging();

    // Setup local notifications
    await _setupLocalNotifications();
  }

  /// Request notification permission
  Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    debugPrint(
        'Notification permission status: ${settings.authorizationStatus}');
  }

  /// Setup Firebase Cloud Messaging
  Future<void> _setupFirebaseMessaging() async {
    // Get FCM token
    _fcmToken = await _messaging.getToken();
    debugPrint('FCM Token: $_fcmToken');

    if (_fcmToken != null) {
      await _storage.saveFcmToken(_fcmToken!);
    }

    // Listen for token refresh
    _messaging.onTokenRefresh.listen((newToken) {
      _fcmToken = newToken;
      _storage.saveFcmToken(newToken);
      // Re-register the token with WordPress
      _registerTokenWithWordPress(newToken);
    });

    // Handle foreground messages (when app is open)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint(
          'FCM foreground message: ${message.messageId}');
      _handleRemoteMessage(message);
    });

    // Handle background messages (when app is in background, not terminated)
    FirebaseMessaging.onMessageOpenedApp
        .listen((RemoteMessage message) {
      debugPrint(
          'FCM message opened app: ${message.messageId}');
      _handleRemoteMessage(message);
    });

    // Check if app was opened from terminated state by a notification
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint(
          'App opened from terminated state via notification');
      _handleRemoteMessage(initialMessage);
    }

    // Set background message handler
    FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler);
  }

  /// Handle incoming FCM message
  void _handleRemoteMessage(RemoteMessage message) {
    final title =
        message.notification?.title ?? 'KilifiHub';
    final body = message.notification?.body ?? '';
    final data = message.data;

    debugPrint('FCM notification: $title - $body');
    debugPrint('FCM data: $data');

    // Show local notification
    showLocalNotification(
      title: title,
      body: body,
      payload: data['order_id']?.toString() ?? '',
    );

    // Handle order-specific notifications
    if (data.containsKey('order_id')) {
      final orderId =
          int.tryParse(data['order_id'].toString());
      if (orderId != null && onOrderNotification != null) {
        onOrderNotification!(orderId);
      }
    }

    // Handle promo / category notifications
    if (data.containsKey('type') &&
        data['type'] == 'promo') {
      if (onPromoNotification != null) {
        onPromoNotification!(data);
      }
    }
  }

  /// Register FCM token with WordPress backend
  Future<void> _registerTokenWithWordPress(String token) async {
    try {
      await _api.registerDeviceToken(token);
      debugPrint('FCM token registered with WordPress');
    } catch (e) {
      debugPrint('Failed to register FCM token: $e');
    }
  }

  /// Setup local notification channel for Android
  Future<void> _setupLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings();

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse:
          (NotificationResponse response) {
        if (response.payload != null &&
            response.payload!.isNotEmpty) {
          try {
            final payload = response.payload!;
            final orderId =
                int.tryParse(payload.replaceAll(
                    RegExp(r'[^0-9]'), ''));
            if (orderId != null &&
                onOrderNotification != null) {
              onOrderNotification!(orderId);
            }
          } catch (e) {
            debugPrint(
                'Notification payload parse error: $e');
          }
        }
      },
    );

    // Create notification channel for Android 8.0+
    const AndroidNotificationChannel channel =
        AndroidNotificationChannel(
      AppConfig.NOTIFICATION_CHANNEL_ID,
      AppConfig.NOTIFICATION_CHANNEL_NAME,
      description: AppConfig.NOTIFICATION_CHANNEL_DESC,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      enableLights: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// Show a local notification (works without Firebase)
  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      AppConfig.NOTIFICATION_CHANNEL_ID,
      AppConfig.NOTIFICATION_CHANNEL_NAME,
      channelDescription: AppConfig.NOTIFICATION_CHANNEL_DESC,
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      color: Color(AppConfig.PRIMARY_COLOR),
      styleInformation: BigTextStyleInformation(body),
    );

    const DarwinNotificationDetails iosDetails =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }
}

/// Top-level background message handler for Firebase
///
/// This MUST be a top-level function (not a class method or closure)
/// because it needs to run in a separate isolate when the app is terminated.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(
    RemoteMessage message) async {
  debugPrint(
      'FCM background message: ${message.messageId}');
}
