import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_config.dart';
import '../services/auth_service.dart';

class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({super.key});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  Timer? _resendTimer;
  int _resendSeconds = 30;
  bool _canResend = false;
  String _phone = '';

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    // Auto-focus first digit
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startResendTimer() {
    _canResend = false;
    _resendSeconds = 30;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _resendSeconds--;
        if (_resendSeconds <= 0) {
          _canResend = true;
          timer.cancel();
        }
      });
    });
  }

  String get _otpCode =>
      _controllers.map((c) => c.text).join();

  void _onDigitChanged(int index, String value) {
    if (value.isNotEmpty && index < 5) {
      // Auto-advance to next field
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      // Go back to previous field
      _focusNodes[index - 1].requestFocus();
    }

    // Auto-verify when all 6 digits are entered
    if (_otpCode.length == 6) {
      _verify();
    }
  }

  Future<void> _verify() async {
    final code = _otpCode;
    if (code.length < 6) {
      _showError('Please enter all 6 digits');
      return;
    }

    final authService = context.read<AuthService>();
    final success = await authService.verifyOtp(_phone, code);

    if (!mounted) return;

    if (!success && authService.error != null) {
      _showError(authService.error!);
      // Clear all fields on error
      for (final c in _controllers) {
        c.clear();
      }
      _focusNodes[0].requestFocus();
    }
    // On success, AuthWrapper handles navigation
  }

  Future<void> _resendOtp() async {
    if (!_canResend) return;

    final authService = context.read<AuthService>();
    final success = await authService.loginWithPhone(_phone);

    if (!mounted) return;

    if (success) {
      _startResendTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('New OTP sent to $_phone'),
          backgroundColor: const Color(AppConfig.SUCCESS_COLOR),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConfig.RADIUS_MD),
          ),
        ),
      );
    } else if (authService.error != null) {
      _showError(authService.error!);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(AppConfig.ERROR_COLOR),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConfig.RADIUS_MD),
        ),
      ),
    );
  }

  /// Mask phone number for display (e.g., +254XXXXXX89)
  String _maskPhone(String phone) {
    if (phone.length > 4) {
      final lastTwo = phone.substring(phone.length - 2);
      final masked = 'X' * (phone.length - 6);
      return phone.substring(0, 4) + masked + lastTwo;
    }
    return phone;
  }

  @override
  Widget build(BuildContext context) {
    // Get phone from route arguments
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String && _phone.isEmpty) {
      _phone = args;
    }

    final authService = context.watch<AuthService>();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 20),

              // ── Phone Icon ──
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: const Color(AppConfig.PRIMARY_COLOR).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.phone_android_rounded,
                  size: 44,
                  color: Color(AppConfig.PRIMARY_COLOR),
                ),
              ),
              const SizedBox(height: 28),

              // ── Title ──
              const Text(
                'Verify Your Phone',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Color(AppConfig.TEXT_PRIMARY),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'We sent a code to ${_maskPhone(_phone)}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(AppConfig.TEXT_SECONDARY),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 40),

              // ── OTP Digits ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) {
                  return SizedBox(
                    width: 48,
                    child: TextField(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      maxLength: 1,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Color(AppConfig.TEXT_PRIMARY),
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                              AppConfig.RADIUS_MD),
                          borderSide: const BorderSide(
                            color: Color(AppConfig.DIVIDER_COLOR),
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                              AppConfig.RADIUS_MD),
                          borderSide: const BorderSide(
                            color: Color(AppConfig.PRIMARY_COLOR),
                            width: 2,
                          ),
                        ),
                        filled: true,
                        fillColor: const Color(AppConfig.BACKGROUND_COLOR),
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 14),
                      ),
                      onChanged: (value) => _onDigitChanged(index, value),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 32),

              // ── Verify Button ──
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: authService.isLoading ? null : _verify,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(AppConfig.PRIMARY_COLOR),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        const Color(AppConfig.PRIMARY_COLOR).withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppConfig.RADIUS_MD),
                    ),
                  ),
                  child: authService.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Verify',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),

              // ── Resend Code ──
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Didn't receive the code? ",
                    style: TextStyle(
                      color: Color(AppConfig.TEXT_SECONDARY),
                      fontSize: 14,
                    ),
                  ),
                  _canResend
                      ? GestureDetector(
                          onTap: _resendOtp,
                          child: const Text(
                            'Resend Code',
                            style: TextStyle(
                              color: Color(AppConfig.PRIMARY_COLOR),
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                      : Text(
                          'Resend in ${_resendSeconds}s',
                          style: const TextStyle(
                            color: Color(AppConfig.TEXT_HINT),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Back to login ──
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Text(
                  'Back to Login',
                  style: TextStyle(
                    color: Color(AppConfig.TEXT_SECONDARY),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
