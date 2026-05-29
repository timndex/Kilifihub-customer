/// Profile screen for KilifiHub Customer App
///
/// Displays user profile header and menu items for navigation
/// to orders, addresses, notifications, help, about, and logout.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import 'orders_screen.dart';
import 'addresses_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppConfig.BACKGROUND_COLOR),
      appBar: AppBar(
        title: const Text('Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Consumer<AuthService>(
        builder: (context, authService, _) {
          final user = authService.currentUser;

          if (user == null) {
            return const Center(
              child: Text('Please log in to view your profile.'),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Profile header
                _ProfileHeader(user: user),
                const SizedBox(height: 24),

                // Menu items
                _MenuSection(user: user),
                const SizedBox(height: 24),

                // Logout button
                _LogoutButton(authService: authService),
                const SizedBox(height: 16),

                // App version
                const Text(
                  'KilifiHub v${AppConfig.APP_VERSION}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(AppConfig.TEXT_HINT),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── Profile Header ──────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  final UserModel user;
  const _ProfileHeader({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConfig.RADIUS_LG),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar
              user.hasAvatar
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: CachedNetworkImage(
                        imageUrl: user.avatar,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => _InitialsAvatar(initials: user.initials),
                        errorWidget: (_, __, ___) => _InitialsAvatar(initials: user.initials),
                      ),
                    )
                  : _InitialsAvatar(initials: user.initials),

              const SizedBox(width: 16),

              // Name, email, phone
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: AppConfig.FONT_SIZE_XLARGE,
                        fontWeight: FontWeight.w800,
                        color: Color(AppConfig.TEXT_PRIMARY),
                      ),
                    ),
                    if (user.email.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        user.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: AppConfig.FONT_SIZE_SMALL,
                          color: Color(AppConfig.TEXT_SECONDARY),
                        ),
                      ),
                    ],
                    if (user.phone.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        user.phone,
                        style: const TextStyle(
                          fontSize: AppConfig.FONT_SIZE_SMALL,
                          color: Color(AppConfig.TEXT_SECONDARY),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Edit button
              Container(
                decoration: BoxDecoration(
                  color: const Color(AppConfig.PRIMARY_COLOR).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppConfig.RADIUS_MD),
                ),
                child: IconButton(
                  onPressed: () {
                    _showEditProfileDialog(context, user);
                  },
                  icon: const Icon(
                    Icons.edit_rounded,
                    size: 20,
                    color: Color(AppConfig.PRIMARY_COLOR),
                  ),
                  tooltip: 'Edit Profile',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context, UserModel user) {
    final firstNameCtrl = TextEditingController(text: user.firstName);
    final lastNameCtrl = TextEditingController(text: user.lastName);
    final emailCtrl = TextEditingController(text: user.email);
    final phoneCtrl = TextEditingController(text: user.phone);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConfig.RADIUS_LG),
        ),
        title: const Text('Edit Profile'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: firstNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'First Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: lastNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Last Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final authService = context.read<AuthService>();
              await authService.updateProfile(
                firstName: firstNameCtrl.text.trim(),
                lastName: lastNameCtrl.text.trim(),
                email: emailCtrl.text.trim(),
                phone: phoneCtrl.text.trim(),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

// ─── Initials Avatar ──────────────────────────────────────

class _InitialsAvatar extends StatelessWidget {
  final String initials;
  const _InitialsAvatar({required this.initials});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(AppConfig.PRIMARY_COLOR), Color(0xFFC62828)],
        ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

// ─── Menu Section ──────────────────────────────────────

class _MenuSection extends StatelessWidget {
  final UserModel user;
  const _MenuSection({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConfig.RADIUS_LG),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _MenuItem(
            icon: Icons.receipt_long_rounded,
            iconColor: const Color(AppConfig.PRIMARY_COLOR),
            title: 'My Orders',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OrdersScreen()),
              );
            },
          ),
          const _MenuDivider(),
          _MenuItem(
            icon: Icons.location_on_rounded,
            iconColor: const Color(0xFF2196F3),
            title: 'Delivery Addresses',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddressesScreen()),
              );
            },
          ),
          const _MenuDivider(),
          _MenuItem(
            icon: Icons.notifications_outlined,
            iconColor: const Color(AppConfig.ACCENT_COLOR),
            title: 'Notifications',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Notification settings coming soon'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          const _MenuDivider(),
          _MenuItem(
            icon: Icons.help_outline_rounded,
            iconColor: const Color(0xFF4CAF50),
            title: 'Help & Support',
            onTap: () async {
              // Open WhatsApp
              final uri = Uri.parse('https://wa.me/254700000000');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),
          const _MenuDivider(),
          _MenuItem(
            icon: Icons.info_outline_rounded,
            iconColor: const Color(0xFF9C27B0),
            title: 'About KilifiHub',
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: AppConfig.APP_NAME,
                applicationVersion: AppConfig.APP_VERSION,
                applicationIcon: Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: Color(AppConfig.PRIMARY_COLOR),
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                  child: const Center(
                    child: Text(
                      'K',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                children: [
                  const Text(
                    'KilifiHub — Order food, medicine, groceries, and more '
                    'from local stores with fast delivery in Kilifi, Kenya.',
                  ),
                ],
              );
            },
          ),
          const _MenuDivider(),
          _MenuItem(
            icon: Icons.star_outline_rounded,
            iconColor: const Color(AppConfig.ACCENT_COLOR),
            title: 'Rate the App',
            onTap: () async {
              final uri = Uri.parse(
                'https://play.google.com/store/apps/details?id=com.kilifihub.customer',
              );
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),
        ],
      ),
    );
  }
}

// ─── Menu Item ──────────────────────────────────────────

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppConfig.RADIUS_MD),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppConfig.RADIUS_MD),
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: AppConfig.FONT_SIZE_LARGE,
                  fontWeight: FontWeight.w600,
                  color: Color(AppConfig.TEXT_PRIMARY),
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: Color(AppConfig.TEXT_HINT),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Menu Divider ──────────────────────────────────────

class _MenuDivider extends StatelessWidget {
  const _MenuDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Divider(height: 1, thickness: 0.5),
    );
  }
}

// ─── Logout Button ──────────────────────────────────────

class _LogoutButton extends StatelessWidget {
  final AuthService authService;
  const _LogoutButton({required this.authService});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () => _showLogoutConfirmation(context),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(AppConfig.ERROR_COLOR),
          side: const BorderSide(color: Color(AppConfig.ERROR_COLOR)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConfig.RADIUS_MD),
          ),
        ),
        child: const Text(
          'Log Out',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConfig.RADIUS_LG),
        ),
        title: const Text('Log Out?'),
        content: const Text(
          'Are you sure you want to log out? You\'ll need to sign in again to place orders.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await authService.logout();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/login',
                  (route) => false,
                );
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: const Color(AppConfig.ERROR_COLOR),
            ),
            child: const Text(
              'Log Out',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
