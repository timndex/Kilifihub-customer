/// M-Pesa payment waiting screen for KilifiHub Customer App
///
/// Displays a polished waiting screen with animations while
/// the customer completes the M-Pesa STK push payment.
/// Features auto-polling every 3 seconds, elapsed timer,
/// retry on failure, and smooth status transitions.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_config.dart';
import '../services/api_service.dart';
import 'order_confirmation_screen.dart';
import 'order_tracking_screen.dart';

enum MpesaStatus { waiting, processing, success, failed }

class MpesaPaymentScreen extends StatefulWidget {
  final int orderId;
  final String orderNumber;
  final String phone;

  const MpesaPaymentScreen({
    super.key,
    required this.orderId,
    required this.orderNumber,
    required this.phone,
  });

  @override
  State<MpesaPaymentScreen> createState() => _MpesaPaymentScreenState();
}

class _MpesaPaymentScreenState extends State<MpesaPaymentScreen>
    with TickerProviderStateMixin {
  MpesaStatus _status = MpesaStatus.waiting;
  String? _errorMessage;
  Timer? _pollTimer;
  Timer? _elapsedTimer;
  int _elapsedSeconds = 0;
  static const int _timeoutSeconds = 120; // 2 min timeout

  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _successController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _successScaleAnimation;

  @override
  void initState() {
    super.initState();

    // Pulse animation for the M-Pesa icon
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Success checkmark animation
    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _successScaleAnimation = CurvedAnimation(
      parent: _successController,
      curve: Curves.elasticOut,
    );

    _startPolling();
    _startElapsedTimer();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _elapsedTimer?.cancel();
    _pulseController.dispose();
    _successController.dispose();
    super.dispose();
  }

  void _startPolling() {
    // Initial check after 3 seconds
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      await _checkStatus();
    });
  }

  void _startElapsedTimer() {
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsedSeconds++);

      if (_elapsedSeconds >= _timeoutSeconds && _status == MpesaStatus.waiting) {
        _updateStatus(MpesaStatus.failed);
        _errorMessage = 'Payment timed out. Please try again.';
      }
    });
  }

  Future<void> _checkStatus() async {
    if (_status == MpesaStatus.success || _status == MpesaStatus.failed) {
      return;
    }

    try {
      final api = ApiService.instance;
      final result = await api.checkMpesaStatus(widget.orderId);
      final status = result['status'] as String? ?? '';

      if (status == 'completed' || status == 'success') {
        _updateStatus(MpesaStatus.success);
      } else if (status == 'processing') {
        _updateStatus(MpesaStatus.processing);
      } else if (status == 'failed' || status == 'cancelled') {
        _updateStatus(MpesaStatus.failed);
        _errorMessage =
            result['message'] as String? ?? 'Payment was not completed.';
      }
      // 'pending' or 'waiting' → stay in current state
    } catch (e) {
      // Silently ignore polling errors — will retry next cycle
    }
  }

  void _updateStatus(MpesaStatus newStatus) {
    if (!mounted) return;
    setState(() => _status = newStatus);

    if (newStatus == MpesaStatus.success) {
      _pollTimer?.cancel();
      _elapsedTimer?.cancel();
      _pulseController.stop();
      _successController.forward();

      // Auto-navigate after showing success
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => OrderConfirmationScreen(
                orderId: widget.orderId,
                orderNumber: widget.orderNumber,
                isMpesa: true,
              ),
            ),
          );
        }
      });
    } else if (newStatus == MpesaStatus.failed) {
      _pollTimer?.cancel();
      _pulseController.stop();
    } else if (newStatus == MpesaStatus.processing) {
      // Continue polling
    }
  }

  Future<void> _retryPayment() async {
    setState(() {
      _status = MpesaStatus.waiting;
      _errorMessage = null;
      _elapsedSeconds = 0;
    });

    _pulseController.repeat(reverse: true);

    try {
      final api = ApiService.instance;
      await api.retryStk(widget.orderId);
      _startPolling();
    } catch (e) {
      setState(() {
        _status = MpesaStatus.failed;
        _errorMessage = 'Could not retry payment. Please try again.';
      });
    }
  }

  String _getMaskedPhone() {
    final phone = widget.phone;
    if (phone.length >= 8) {
      return '${phone.substring(0, 4)}XXXX${phone.substring(phone.length - 3)}';
    }
    return 'XXXX';
  }

  String _formatElapsed() {
    final mins = _elapsedSeconds ~/ 60;
    final secs = _elapsedSeconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _status == MpesaStatus.failed,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 20),

                // Timer display
                Align(
                  alignment: Alignment.topRight,
                  child: _buildTimerChip(),
                ),

                const Spacer(flex: 1),

                // Animated M-Pesa icon
                _buildMpesaIcon(),

                const SizedBox(height: 32),

                // Title & subtitle
                _buildStatusText(),

                const SizedBox(height: 24),

                // Status indicator
                _buildStatusIndicator(),

                const Spacer(flex: 2),

                // Action buttons
                _buildActions(),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimerChip() {
    if (_status == MpesaStatus.success || _status == MpesaStatus.failed) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _elapsedSeconds > 90
            ? const Color(AppConfig.ERROR_COLOR).withValues(alpha: 0.1)
            : const Color(AppConfig.BACKGROUND_COLOR),
        borderRadius: BorderRadius.circular(AppConfig.RADIUS_ROUND),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer_outlined,
            size: 16,
            color: _elapsedSeconds > 90
                ? const Color(AppConfig.ERROR_COLOR)
                : const Color(AppConfig.TEXT_SECONDARY),
          ),
          const SizedBox(width: 4),
          Text(
            _formatElapsed(),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _elapsedSeconds > 90
                  ? const Color(AppConfig.ERROR_COLOR)
                  : const Color(AppConfig.TEXT_SECONDARY),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMpesaIcon() {
    if (_status == MpesaStatus.success) {
      return ScaleTransition(
        scale: _successScaleAnimation,
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: const Color(AppConfig.SUCCESS_COLOR).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle_rounded,
            size: 72,
            color: Color(AppConfig.SUCCESS_COLOR),
          ),
        ),
      );
    }

    if (_status == MpesaStatus.failed) {
      return Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: const Color(AppConfig.ERROR_COLOR).withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.error_outline_rounded,
          size: 72,
          color: Color(AppConfig.ERROR_COLOR),
        ),
      );
    }

    // Waiting / Processing — animated pulse
    return ScaleTransition(
      scale: _pulseAnimation,
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4CAF50).withValues(alpha: 0.3),
              blurRadius: 24,
              spreadRadius: 4,
            ),
          ],
        ),
        child: const Center(
          child: Text(
            'M',
            style: TextStyle(
              color: Colors.white,
              fontSize: 52,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusText() {
    String title;
    String subtitle;

    switch (_status) {
      case MpesaStatus.waiting:
        title = 'Waiting for M-Pesa Payment';
        subtitle =
            'We\'ve sent an M-Pesa prompt to ${_getMaskedPhone()}.\nPlease enter your PIN to complete payment.';
        break;
      case MpesaStatus.processing:
        title = 'Processing Payment...';
        subtitle = 'Your M-Pesa payment is being processed.\nThis usually takes a few seconds.';
        break;
      case MpesaStatus.success:
        title = 'Payment Successful!';
        subtitle = 'Your payment has been confirmed.\nRedirecting to order confirmation...';
        break;
      case MpesaStatus.failed:
        title = 'Payment Failed';
        subtitle = _errorMessage ?? 'The payment was not completed. Please try again.';
        break;
    }

    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: AppConfig.FONT_SIZE_XXLARGE,
            fontWeight: FontWeight.w800,
            color: Color(AppConfig.TEXT_PRIMARY),
            height: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: AppConfig.FONT_SIZE_MEDIUM,
            color: Color(AppConfig.TEXT_SECONDARY),
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusIndicator() {
    Color dotColor;
    String label;
    IconData icon;

    switch (_status) {
      case MpesaStatus.waiting:
        dotColor = const Color(AppConfig.WARNING_COLOR);
        label = 'Waiting...';
        icon = Icons.more_horiz_rounded;
        break;
      case MpesaStatus.processing:
        dotColor = const Color(0xFF2196F3);
        label = 'Processing...';
        icon = Icons.sync_rounded;
        break;
      case MpesaStatus.success:
        dotColor = const Color(AppConfig.SUCCESS_COLOR);
        label = 'Success!';
        icon = Icons.check_rounded;
        break;
      case MpesaStatus.failed:
        dotColor = const Color(AppConfig.ERROR_COLOR);
        label = 'Failed';
        icon = Icons.close_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: dotColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppConfig.RADIUS_ROUND),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_status == MpesaStatus.waiting || _status == MpesaStatus.processing)
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: dotColor,
              ),
            )
          else
            Icon(icon, size: 16, color: dotColor),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: dotColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    if (_status == MpesaStatus.success) {
      return const SizedBox.shrink();
    }

    if (_status == MpesaStatus.failed) {
      return Column(
        children: [
          // Retry button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _retryPayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(AppConfig.PRIMARY_COLOR),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConfig.RADIUS_MD),
                ),
              ),
              child: const Text(
                'Retry Payment',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Pay with different number
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton(
              onPressed: () {
                // Go back to checkout to change number
                Navigator.pop(context);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(AppConfig.PRIMARY_COLOR),
                side: const BorderSide(color: Color(AppConfig.PRIMARY_COLOR)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConfig.RADIUS_MD),
                ),
              ),
              child: const Text(
                'Pay with Different Number',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => OrderConfirmationScreen(
                    orderId: widget.orderId,
                    orderNumber: widget.orderNumber,
                    isMpesa: false,
                  ),
                ),
              );
            },
            child: const Text(
              'Cancel Payment',
              style: TextStyle(
                color: Color(AppConfig.TEXT_SECONDARY),
                fontSize: 14,
              ),
            ),
          ),
        ],
      );
    }

    // Waiting / Processing — show helpful tips
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(AppConfig.BACKGROUND_COLOR),
            borderRadius: BorderRadius.circular(AppConfig.RADIUS_MD),
          ),
          child: const Column(
            children: [
              Row(
                children: [
                  Icon(Icons.lightbulb_outline_rounded,
                      size: 18, color: Color(AppConfig.ACCENT_COLOR)),
                  SizedBox(width: 8),
                  Text(
                    'Tips',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(AppConfig.TEXT_PRIMARY),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              _TipItem(text: 'Check your phone for the M-Pesa pop-up'),
              _TipItem(text: 'Enter your M-Pesa PIN when prompted'),
              _TipItem(text: 'Don\'t close this screen until payment is done'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () {
            _pollTimer?.cancel();
            _elapsedTimer?.cancel();
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => OrderConfirmationScreen(
                  orderId: widget.orderId,
                  orderNumber: widget.orderNumber,
                  isMpesa: false,
                ),
              ),
            );
          },
          child: const Text(
            'Cancel Payment',
            style: TextStyle(
              color: Color(AppConfig.TEXT_HINT),
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}

class _TipItem extends StatelessWidget {
  final String text;
  const _TipItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '•  ',
            style: TextStyle(
              fontSize: 12,
              color: Color(AppConfig.TEXT_SECONDARY),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                color: Color(AppConfig.TEXT_SECONDARY),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
