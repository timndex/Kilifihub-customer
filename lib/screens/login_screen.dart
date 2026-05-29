import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_config.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneFormKey = GlobalKey<FormState>();
  final _emailFormKey = GlobalKey<FormState>();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (!_phoneFormKey.currentState!.validate()) return;

    final phone = '+254${_phoneController.text.trim()}';
    final authService = context.read<AuthService>();
    final success = await authService.loginWithPhone(phone);

    if (!mounted) return;

    if (success) {
      Navigator.pushNamed(
        context,
        '/otp-verification',
        arguments: phone,
      );
    } else if (authService.error != null) {
      _showError(authService.error!);
    }
  }

  Future<void> _loginWithEmail() async {
    if (!_emailFormKey.currentState!.validate()) return;

    final authService = context.read<AuthService>();
    final success = await authService.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;

    if (!success && authService.error != null) {
      _showError(authService.error!);
    }
    // On success, AuthWrapper will handle navigation
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

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 60),
              // ── Branding ──
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(AppConfig.PRIMARY_COLOR).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  size: 36,
                  color: Color(AppConfig.PRIMARY_COLOR),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                AppConfig.APP_NAME,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(AppConfig.PRIMARY_COLOR),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Order from your favorite local stores',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(AppConfig.TEXT_SECONDARY),
                ),
              ),
              const SizedBox(height: 40),

              // ── Tab Bar ──
              Container(
                decoration: BoxDecoration(
                  color: const Color(AppConfig.BACKGROUND_COLOR),
                  borderRadius: BorderRadius.circular(AppConfig.RADIUS_MD),
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: Colors.white,
                  unselectedLabelColor:
                      const Color(AppConfig.TEXT_SECONDARY),
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    color: const Color(AppConfig.PRIMARY_COLOR),
                    borderRadius:
                        BorderRadius.circular(AppConfig.RADIUS_MD),
                  ),
                  dividerColor: Colors.transparent,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                  tabs: const [
                    Tab(text: 'Phone'),
                    Tab(text: 'Email'),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Tab Views ──
              SizedBox(
                height: 260,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPhoneTab(authService.isLoading),
                    _buildEmailTab(authService.isLoading),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Sign Up Link ──
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Don't have an account? ",
                    style: TextStyle(
                      color: Color(AppConfig.TEXT_SECONDARY),
                      fontSize: 14,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/register'),
                    child: const Text(
                      'Sign Up',
                      style: TextStyle(
                        color: Color(AppConfig.PRIMARY_COLOR),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneTab(bool isLoading) {
    return Form(
      key: _phoneFormKey,
      child: Column(
        children: [
          // Phone field
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Enter phone number';
              if (v.trim().length < 9) return 'Enter valid phone number';
              return null;
            },
            decoration: InputDecoration(
              labelText: 'Phone Number',
              prefixText: '+254 ',
              prefixStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(AppConfig.TEXT_PRIMARY),
              ),
              border: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(AppConfig.RADIUS_MD),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(AppConfig.RADIUS_MD),
                borderSide: const BorderSide(
                    color: Color(AppConfig.DIVIDER_COLOR)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(AppConfig.RADIUS_MD),
                borderSide: const BorderSide(
                    color: Color(AppConfig.PRIMARY_COLOR), width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: isLoading ? null : _sendOtp,
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
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Send OTP',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailTab(bool isLoading) {
    return Form(
      key: _emailFormKey,
      child: Column(
        children: [
          // Email / Username field
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Enter username or email';
              }
              return null;
            },
            decoration: InputDecoration(
              labelText: 'Username or Email',
              prefixIcon: const Icon(Icons.person_outline, size: 20),
              border: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(AppConfig.RADIUS_MD),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(AppConfig.RADIUS_MD),
                borderSide: const BorderSide(
                    color: Color(AppConfig.DIVIDER_COLOR)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(AppConfig.RADIUS_MD),
                borderSide: const BorderSide(
                    color: Color(AppConfig.PRIMARY_COLOR), width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Password field
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Enter password';
              if (v.length < 6) return 'Password too short';
              return null;
            },
            onFieldSubmitted: (_) => _loginWithEmail(),
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline, size: 20),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
              border: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(AppConfig.RADIUS_MD),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(AppConfig.RADIUS_MD),
                borderSide: const BorderSide(
                    color: Color(AppConfig.DIVIDER_COLOR)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(AppConfig.RADIUS_MD),
                borderSide: const BorderSide(
                    color: Color(AppConfig.PRIMARY_COLOR), width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: isLoading ? null : _loginWithEmail,
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
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Login',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
