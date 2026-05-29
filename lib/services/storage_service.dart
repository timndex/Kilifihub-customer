/// Local storage service for persisting customer data
///
/// Follows the same singleton pattern as the rider app's StorageService.
/// Uses SharedPreferences for simple data and flutter_secure_storage
/// for sensitive tokens.

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

import '../models/user_model.dart';
import '../models/cart_model.dart';

class StorageService {
  static StorageService? _instance;
  SharedPreferences? _prefs;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  StorageService._();

  static StorageService get instance {
    _instance ??= StorageService._();
    return _instance!;
  }

  Future<SharedPreferences> get _preferences async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // ============================================================
  // Storage Keys
  // ============================================================
  static const String KEY_AUTH_TOKEN = 'auth_token';
  static const String KEY_REFRESH_TOKEN = 'refresh_token';
  static const String KEY_USER_DATA = 'user_data';
  static const String KEY_USER_PHONE = 'user_phone';
  static const String KEY_FCM_TOKEN = 'fcm_token';
  static const String KEY_CART_DATA = 'cart_data';
  static const String KEY_ONBOARDING_DONE = 'onboarding_done';

  // ============================================================
  // Auth Token (secure storage)
  // ============================================================

  /// Save the authentication token securely
  Future<void> saveAuthToken(String token) async {
    await _secureStorage.write(key: KEY_AUTH_TOKEN, value: token);
  }

  /// Retrieve the authentication token
  Future<String?> getAuthToken() async {
    return await _secureStorage.read(key: KEY_AUTH_TOKEN);
  }

  /// Save refresh token (for future use)
  Future<void> saveRefreshToken(String token) async {
    await _secureStorage.write(
        key: KEY_REFRESH_TOKEN, value: token);
  }

  /// Retrieve refresh token
  Future<String?> getRefreshToken() async {
    return await _secureStorage.read(key: KEY_REFRESH_TOKEN);
  }

  /// Clear auth tokens
  Future<void> clearTokens() async {
    await _secureStorage.delete(key: KEY_AUTH_TOKEN);
    await _secureStorage.delete(key: KEY_REFRESH_TOKEN);
  }

  // ============================================================
  // User Data
  // ============================================================

  /// Save the full user profile data
  Future<void> saveUserData(UserModel user) async {
    final prefs = await _preferences;
    await prefs.setString(KEY_USER_DATA, jsonEncode(user.toJson()));
  }

  /// Retrieve the saved user profile data
  Future<UserModel?> getUserData() async {
    final prefs = await _preferences;
    final data = prefs.getString(KEY_USER_DATA);
    if (data != null) {
      return UserModel.fromJson(
          jsonDecode(data) as Map<String, dynamic>);
    }
    return null;
  }

  // ============================================================
  // User Phone (for auto-login / OTP flow)
  // ============================================================

  /// Save the user's phone number
  Future<void> savePhone(String phone) async {
    final prefs = await _preferences;
    await prefs.setString(KEY_USER_PHONE, phone);
  }

  /// Retrieve the saved phone number
  Future<String?> getPhone() async {
    final prefs = await _preferences;
    return prefs.getString(KEY_USER_PHONE);
  }

  // ============================================================
  // FCM Token
  // ============================================================

  /// Save the Firebase Cloud Messaging token
  Future<void> saveFcmToken(String token) async {
    final prefs = await _preferences;
    await prefs.setString(KEY_FCM_TOKEN, token);
  }

  /// Retrieve the saved FCM token
  Future<String?> getFcmToken() async {
    final prefs = await _preferences;
    return prefs.getString(KEY_FCM_TOKEN);
  }

  // ============================================================
  // Cart Data (offline cache)
  // ============================================================

  /// Save cart data for offline access
  Future<void> saveCartData(CartModel cart) async {
    final prefs = await _preferences;
    await prefs.setString(KEY_CART_DATA, jsonEncode(cart.toJson()));
  }

  /// Retrieve cached cart data
  Future<CartModel?> getCartData() async {
    final prefs = await _preferences;
    final data = prefs.getString(KEY_CART_DATA);
    if (data != null) {
      return CartModel.fromJson(
          jsonDecode(data) as Map<String, dynamic>);
    }
    return null;
  }

  // ============================================================
  // Onboarding
  // ============================================================

  /// Mark the onboarding flow as completed
  Future<void> setOnboardingDone() async {
    final prefs = await _preferences;
    await prefs.setBool(KEY_ONBOARDING_DONE, true);
  }

  /// Check if onboarding has been completed
  Future<bool> isOnboardingDone() async {
    final prefs = await _preferences;
    return prefs.getBool(KEY_ONBOARDING_DONE) ?? false;
  }

  // ============================================================
  // Clear All (Logout)
  // ============================================================

  /// Clear all stored data, preserving onboarding status
  Future<void> clearAll() async {
    final prefs = await _preferences;

    // Preserve onboarding flag
    final onboardingDone =
        prefs.getBool(KEY_ONBOARDING_DONE) ?? false;

    // Clear SharedPreferences
    await prefs.clear();

    // Clear secure storage
    await _secureStorage.deleteAll();

    // Restore onboarding flag
    if (onboardingDone) {
      await prefs.setBool(KEY_ONBOARDING_DONE, true);
    }
  }
}
