/// Authentication service for the KilifiHub Customer App
///
/// Manages the customer's authentication state using ChangeNotifier.
/// Supports three login methods:
/// 1. Username + password (traditional)
/// 2. Phone + password
/// 3. Phone + OTP (passwordless)
///
/// Plus customer registration.

import 'package:flutter/foundation.dart';

import '../models/user_model.dart';
import 'api_service.dart';
import 'storage_service.dart';

class AuthService extends ChangeNotifier {
  final ApiService _api = ApiService.instance;
  final StorageService _storage = StorageService.instance;

  UserModel? _user;
  bool _isLoggedIn = false;
  bool _isLoading = false;
  String? _error;

  // ── Getters ──

  /// Whether the user is currently authenticated
  bool get isLoggedIn => _isLoggedIn;

  /// The currently logged-in user
  UserModel? get currentUser => _user;

  /// Whether an auth operation is in progress
  bool get isLoading => _isLoading;

  /// Last error message, if any
  String? get error => _error;

  /// Whether the user has completed registration
  bool get isRegistered => _user != null;

  // ── Login: Username / Password ──

  /// Login with username and password
  ///
  /// Returns `true` on success, `false` on failure.
  /// Check [error] for the failure reason.
  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final user = await _api.login(username, password);

      // Save token and user data
      await _storage.saveAuthToken(user.token);
      await _storage.saveUserData(user);

      _user = user;
      _isLoggedIn = true;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = _extractError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ── Login: Phone OTP ──

  /// Request an OTP for phone login
  ///
  /// Returns `true` if OTP was sent successfully.
  Future<bool> loginWithPhone(String phone) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.loginPhone(phone);

      if (response['otp_sent'] == true) {
        await _storage.savePhone(phone);
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = response['message'] ?? 'Failed to send OTP';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = _extractError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Verify the OTP and complete login
  ///
  /// Returns `true` if verification succeeded.
  Future<bool> verifyOtp(String phone, String otp) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final user = await _api.verifyOtp(phone, otp);

      // Save token and user data
      await _storage.saveAuthToken(user.token);
      await _storage.saveUserData(user);
      await _storage.savePhone(phone);

      _user = user;
      _isLoggedIn = true;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = _extractError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ── Registration ──

  /// Register a new customer account
  ///
  /// Returns `true` on success (auto-logs in).
  Future<bool> register(
    String username,
    String email,
    String phone,
    String password,
    String firstName,
    String lastName,
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final user = await _api.register(
        username,
        email,
        phone,
        password,
        firstName,
        lastName,
      );

      // Save token and user data
      await _storage.saveAuthToken(user.token);
      await _storage.saveUserData(user);
      if (phone.isNotEmpty) {
        await _storage.savePhone(phone);
      }

      _user = user;
      _isLoggedIn = true;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = _extractError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ── Session Check ──

  /// Check for an existing session on app startup
  ///
  /// Validates the stored token by fetching the profile from the API.
  Future<void> checkSession() async {
    _isLoading = true;
    notifyListeners();

    try {
      final token = await _storage.getAuthToken();
      if (token != null && token.isNotEmpty) {
        // Validate token by fetching profile
        final profile = await _api.getProfile();
        _user = profile;
        _isLoggedIn = true;
        await _storage.saveUserData(_user!);
      }
    } catch (e) {
      // Token expired or invalid — clear session
      await _storage.clearTokens();
      _isLoggedIn = false;
      _user = null;
    }

    _isLoading = false;
    notifyListeners();
  }

  // ── Logout ──

  /// Logout and clear all stored data
  Future<void> logout() async {
    _user = null;
    _isLoggedIn = false;
    await _storage.clearAll();
    notifyListeners();
  }

  // ── Profile Update ──

  /// Update the user's profile
  ///
  /// Returns `true` on success.
  Future<bool> updateProfile({
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final updatedUser = await _api.updateProfile(
        firstName: firstName,
        lastName: lastName,
        email: email,
        phone: phone,
      );

      _user = updatedUser;
      await _storage.saveUserData(_user!);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = _extractError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ── Error Handling ──

  /// Extract a user-friendly error message from an exception
  String _extractError(dynamic e) {
    final errorStr = e.toString();

    if (e is Exception) {
      if (errorStr.contains('DioException') ||
          errorStr.contains('DioError')) {
        if (errorStr.contains('404')) {
          return 'API endpoint not found. Please ensure the '
              'KilifiHub Customer plugin is installed and activated.';
        }
        if (errorStr.contains('403')) {
          return 'Access denied. Your account may not be approved yet.';
        }
        if (errorStr.contains('500')) {
          return 'Server error. Please try again later.';
        }
        if (errorStr.contains('401')) {
          return 'Invalid credentials. Please try again.';
        }
        if (errorStr.contains('409')) {
          // Parse conflict errors (duplicate username/email/phone)
          if (errorStr.contains('username_exists')) {
            return 'Username already exists. Please choose another.';
          }
          if (errorStr.contains('email_exists')) {
            return 'Email already registered. Please log in instead.';
          }
          if (errorStr.contains('phone_exists')) {
            return 'Phone number already registered. Please log in instead.';
          }
          return 'Account already exists. Please log in instead.';
        }
        if (errorStr.contains('429')) {
          return 'Too many attempts. Please wait a few minutes and try again.';
        }
        if (errorStr.contains('SocketException') ||
            errorStr.contains('Failed host lookup') ||
            errorStr.contains('No address associated with hostname')) {
          return 'No internet connection. Please check your network settings.';
        }
        if (errorStr.contains('Connection timed out') ||
            errorStr.contains('TimeoutException')) {
          return 'Connection timed out. Please try again.';
        }
        if (errorStr.contains('kilifi_invalid_otp') ||
            errorStr.contains('Invalid or expired OTP')) {
          return 'Invalid or expired OTP. Please request a new code.';
        }
        if (errorStr.contains('kilifi_invalid_credentials')) {
          return 'Invalid credentials. Please try again.';
        }
        return 'Connection error. Please check your internet and try again.';
      }

      if (errorStr.contains('SocketException')) {
        return 'No internet connection. Please check your network settings.';
      }
      if (errorStr.contains('TimeoutException')) {
        return 'Connection timed out. Please try again.';
      }
    }

    return 'Something went wrong. Please try again.';
  }
}
