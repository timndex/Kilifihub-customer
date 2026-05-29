/// Checkout screen for KilifiHub Customer App
///
/// Handles the complete checkout flow including:
/// - Delivery address selection
/// - Delivery notes
/// - Order summary grouped by store
/// - Category-specific sections (pharmacy prescription, alcohol age verification,
///   package delivery form, supermarket minimum order)
/// - Payment method selection (M-Pesa / Cash on Delivery)
/// - Order placement with loading state

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../models/cart_model.dart';
import '../models/address_model.dart';
import '../models/category_model.dart';
import '../providers/cart_provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/prescription_upload.dart';
import 'mpesa_payment_screen.dart';
import 'order_confirmation_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  // ── State ──
  AddressModel? _selectedAddress;
  final _deliveryNotesController = TextEditingController();
  String _paymentMethod = 'mpesa'; // 'mpesa' or 'cod'
  final _mpesaPhoneController = TextEditingController();
  String? _prescriptionImage;
  bool _ageConfirmed = false;

  // Package delivery fields
  final _packageDescController = TextEditingController();
  final _pickupNameController = TextEditingController();
  final _pickupPhoneController = TextEditingController();
  String _packageSize = 'medium';
  final _specialInstructionsController = TextEditingController();

  bool _isPlacingOrder = false;
  List<AddressModel> _addresses = [];
  List<CategoryModel> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _deliveryNotesController.dispose();
    _mpesaPhoneController.dispose();
    _packageDescController.dispose();
    _pickupNameController.dispose();
    _pickupPhoneController.dispose();
    _specialInstructionsController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final api = ApiService.instance;
      final addresses = await api.getAddresses();
      final categories = await api.getCategories();

      if (mounted) {
        setState(() {
          _addresses = addresses;
          _categories = categories;
          // Select default address
          _selectedAddress = addresses.where((a) => a.isDefault).firstOrNull ??
              addresses.firstOrNull;
        });

        // Pre-fill M-Pesa phone from user profile
        final user = context.read<AuthService>().currentUser;
        if (user != null && user.phone.isNotEmpty) {
          _mpesaPhoneController.text = user.phone;
        }
      }
    } catch (e) {
      // Silently fail — user can still proceed
      final user = context.read<AuthService>().currentUser;
      if (user != null && user.phone.isNotEmpty) {
        _mpesaPhoneController.text = user.phone;
      }
    }
  }

  /// Get categories present in cart items
  Set<String> get _cartCategories {
    final cart = context.read<CartProvider>().cart;
    if (cart == null) return {};
    // We derive from store names or use placeholder categories
    // In a real app, cart items would include store category
    return {'general'}; // Placeholder — enhanced by store data
  }

  bool get _hasPharmacy => _cartCategories.contains('pharmacy');
  bool get _hasAlcohol => _cartCategories.contains('alcohol');
  bool get _hasPackageDelivery => _cartCategories.contains('package');
  bool get _hasSupermarket => _cartCategories.contains('supermarket');

  bool get _canPlaceOrder {
    if (_selectedAddress == null) return false;
    if (_paymentMethod == 'mpesa' && _mpesaPhoneController.text.trim().isEmpty) {
      return false;
    }
    if (_hasPharmacy && _prescriptionImage == null) return false;
    if (_hasAlcohol && !_ageConfirmed) return false;
    if (_hasPackageDelivery) {
      if (_packageDescController.text.trim().isEmpty) return false;
      if (_pickupNameController.text.trim().isEmpty) return false;
      if (_pickupPhoneController.text.trim().isEmpty) return false;
    }
    return true;
  }

  Future<void> _placeOrder() async {
    if (!_canPlaceOrder || _isPlacingOrder) return;

    setState(() => _isPlacingOrder = true);

    try {
      final api = ApiService.instance;

      Map<String, dynamic>? packageDetails;
      if (_hasPackageDelivery) {
        packageDetails = {
          'description': _packageDescController.text.trim(),
          'pickup_contact_name': _pickupNameController.text.trim(),
          'pickup_contact_phone': _pickupPhoneController.text.trim(),
          'package_size': _packageSize,
          'special_instructions': _specialInstructionsController.text.trim(),
        };
      }

      final result = await api.checkout(
        paymentMethod: _paymentMethod,
        mpesaPhone: _paymentMethod == 'mpesa'
            ? _mpesaPhoneController.text.trim()
            : null,
        deliveryAddress: _selectedAddress!.address,
        deliveryLat: _selectedAddress!.lat,
        deliveryLng: _selectedAddress!.lng,
        deliveryNotes: _deliveryNotesController.text.trim().isEmpty
            ? null
            : _deliveryNotesController.text.trim(),
        prescriptionImage: _prescriptionImage,
        ageConfirmed: _hasAlcohol ? _ageConfirmed : null,
        packageDetails: packageDetails,
      );

      if (!mounted) return;

      // Clear the cart after successful order
      context.read<CartProvider>().clearCart();

      final orderId = result['order_id'] as int? ?? 0;
      final orderNumber = result['order_number']?.toString() ?? '$orderId';

      if (_paymentMethod == 'mpesa') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => MpesaPaymentScreen(
              orderId: orderId,
              orderNumber: orderNumber,
              phone: _mpesaPhoneController.text.trim(),
            ),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => OrderConfirmationScreen(
              orderId: orderId,
              orderNumber: orderNumber,
              isMpesa: false,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPlacingOrder = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to place order: ${_extractError(e)}'),
            backgroundColor: const Color(AppConfig.ERROR_COLOR),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  String _extractError(dynamic e) {
    final str = e.toString();
    if (str.contains('401')) return 'Please log in again.';
    if (str.contains('SocketException')) return 'No internet connection.';
    if (str.contains('TimeoutException')) return 'Connection timed out.';
    return 'Please try again.';
  }

  void _showAddressPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppConfig.RADIUS_XL),
        ),
      ),
      builder: (context) => _AddressPickerSheet(
        addresses: _addresses,
        selectedAddress: _selectedAddress,
        onSelected: (address) {
          setState(() => _selectedAddress = address);
          Navigator.pop(context);
        },
        onAddNew: () {
          Navigator.pop(context);
          Navigator.pushNamed(context, '/addresses');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppConfig.BACKGROUND_COLOR),
      appBar: AppBar(
        title: const Text('Checkout'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Consumer<CartProvider>(
        builder: (context, cartProvider, _) {
          final cart = cartProvider.cart;
          if (cart == null || cart.isEmpty) {
            return const Center(
              child: Text('Your cart is empty'),
            );
          }

          return Stack(
            children: [
              // Scrollable content
              ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                children: [
                  // Delivery address
                  _SectionCard(
                    child: _AddressSection(
                      selectedAddress: _selectedAddress,
                      onChange: _showAddressPicker,
                      onAdd: () => Navigator.pushNamed(context, '/addresses'),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Delivery notes
                  _SectionCard(
                    child: _DeliveryNotesSection(
                      controller: _deliveryNotesController,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Order summary
                  _SectionCard(
                    child: _OrderSummarySection(cart: cart),
                  ),
                  const SizedBox(height: 12),

                  // Category-specific sections
                  ..._buildCategorySections(),

                  // Payment method
                  _SectionCard(
                    child: _PaymentMethodSection(
                      paymentMethod: _paymentMethod,
                      mpesaPhoneController: _mpesaPhoneController,
                      onPaymentChanged: (v) =>
                          setState(() => _paymentMethod = v),
                    ),
                  ),
                ],
              ),

              // Sticky place order button
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _PlaceOrderButton(
                  total: cart.displayTotal,
                  canPlace: _canPlaceOrder,
                  isPlacing: _isPlacingOrder,
                  onPlace: _placeOrder,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildCategorySections() {
    final sections = <Widget>[];

    // Pharmacy: prescription upload
    if (_hasPharmacy) {
      sections.add(
        _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PrescriptionUpload(
                onChanged: (base64) {
                  setState(() => _prescriptionImage = base64);
                },
                initialImage: _prescriptionImage,
              ),
            ],
          ),
        ),
      );
      sections.add(const SizedBox(height: 12));
    }

    // Alcohol: age verification
    if (_hasAlcohol) {
      sections.add(
        _SectionCard(
          child: _AgeVerificationSection(
            confirmed: _ageConfirmed,
            onChanged: (v) => setState(() => _ageConfirmed = v),
          ),
        ),
      );
      sections.add(const SizedBox(height: 12));
    }

    // Package delivery: form
    if (_hasPackageDelivery) {
      sections.add(
        _SectionCard(
          child: _PackageDeliverySection(
            descController: _packageDescController,
            nameController: _pickupNameController,
            phoneController: _pickupPhoneController,
            instructionsController: _specialInstructionsController,
            packageSize: _packageSize,
            onSizeChanged: (v) => setState(() => _packageSize = v),
          ),
        ),
      );
      sections.add(const SizedBox(height: 12));
    }

    // Supermarket: minimum order notice
    if (_hasSupermarket) {
      final cart = context.read<CartProvider>().cart;
      if (cart != null && cart.subtotal < 500) {
        sections.add(
          _SectionCard(
            child: _MinOrderNotice(
              current: cart.subtotal,
              minimum: 500,
            ),
          ),
        );
        sections.add(const SizedBox(height: 12));
      }
    }

    return sections;
  }
}

// ─── Section Card ──────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConfig.SPACING_MD),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConfig.RADIUS_LG),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ─── Section Header ──────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(AppConfig.PRIMARY_COLOR)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: AppConfig.FONT_SIZE_LARGE,
            fontWeight: FontWeight.w700,
            color: Color(AppConfig.TEXT_PRIMARY),
          ),
        ),
      ],
    );
  }
}

// ─── Address Section ──────────────────────────────────────

class _AddressSection extends StatelessWidget {
  final AddressModel? selectedAddress;
  final VoidCallback onChange;
  final VoidCallback onAdd;

  const _AddressSection({
    required this.selectedAddress,
    required this.onChange,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const _SectionHeader(title: 'Delivery Address', icon: Icons.location_on_rounded),
            if (selectedAddress != null)
              TextButton(
                onPressed: onChange,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(AppConfig.PRIMARY_COLOR),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Change',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (selectedAddress != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(AppConfig.BACKGROUND_COLOR),
              borderRadius: BorderRadius.circular(AppConfig.RADIUS_MD),
            ),
            child: Row(
              children: [
                Icon(
                  selectedAddress!.iconLabel == 'home'
                      ? Icons.home_rounded
                      : selectedAddress!.iconLabel == 'work'
                          ? Icons.work_rounded
                          : Icons.place_rounded,
                  size: 20,
                  color: const Color(AppConfig.PRIMARY_COLOR),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            selectedAddress!.displayLabel,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(AppConfig.TEXT_PRIMARY),
                            ),
                          ),
                          if (selectedAddress!.isDefault) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(AppConfig.SUCCESS_COLOR)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Default',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: Color(AppConfig.SUCCESS_COLOR),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        selectedAddress!.address,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(AppConfig.TEXT_SECONDARY),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          // No address saved
          GestureDetector(
            onTap: onAdd,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(AppConfig.PRIMARY_COLOR).withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(AppConfig.RADIUS_MD),
                border: Border.all(
                  color: const Color(AppConfig.PRIMARY_COLOR).withValues(alpha: 0.2),
                  style: BorderStyle.solid,
                ),
              ),
              child: const Column(
                children: [
                  Icon(Icons.add_location_rounded,
                      size: 32, color: Color(AppConfig.PRIMARY_COLOR)),
                  SizedBox(height: 8),
                  Text(
                    'Add Delivery Address',
                    style: TextStyle(
                      fontSize: AppConfig.FONT_SIZE_MEDIUM,
                      fontWeight: FontWeight.w700,
                      color: Color(AppConfig.PRIMARY_COLOR),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Address Picker Sheet ──────────────────────────────

class _AddressPickerSheet extends StatelessWidget {
  final List<AddressModel> addresses;
  final AddressModel? selectedAddress;
  final ValueChanged<AddressModel> onSelected;
  final VoidCallback onAddNew;

  const _AddressPickerSheet({
    required this.addresses,
    this.selectedAddress,
    required this.onSelected,
    required this.onAddNew,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppConfig.SPACING_MD),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(AppConfig.DIVIDER_COLOR),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Select Delivery Address',
              style: TextStyle(
                fontSize: AppConfig.FONT_SIZE_XLARGE,
                fontWeight: FontWeight.w700,
                color: Color(AppConfig.TEXT_PRIMARY),
              ),
            ),
            const SizedBox(height: 16),
            ...addresses.map((addr) => ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  leading: Icon(
                    addr.iconLabel == 'home'
                        ? Icons.home_rounded
                        : addr.iconLabel == 'work'
                            ? Icons.work_rounded
                            : Icons.place_rounded,
                    color: addr.id == selectedAddress?.id
                        ? const Color(AppConfig.PRIMARY_COLOR)
                        : const Color(AppConfig.TEXT_SECONDARY),
                  ),
                  title: Text(
                    addr.displayLabel,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    addr.address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: addr.id == selectedAddress?.id
                      ? const Icon(Icons.check_circle_rounded,
                          color: Color(AppConfig.PRIMARY_COLOR))
                      : null,
                  selected: addr.id == selectedAddress?.id,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppConfig.RADIUS_MD),
                  ),
                  onTap: () => onSelected(addr),
                )),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onAddNew,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add New Address'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(AppConfig.PRIMARY_COLOR),
                  side: const BorderSide(color: Color(AppConfig.PRIMARY_COLOR)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppConfig.RADIUS_MD),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ─── Delivery Notes Section ────────────────────────────

class _DeliveryNotesSection extends StatelessWidget {
  final TextEditingController controller;
  const _DeliveryNotesSection({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'Delivery Notes', icon: Icons.note_rounded),
        const SizedBox(height: 4),
        const Text(
          'Optional — e.g., "Gate code 1234"',
          style: TextStyle(
            fontSize: AppConfig.FONT_SIZE_SMALL,
            color: Color(AppConfig.TEXT_HINT),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          maxLines: 2,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            hintText: 'Add delivery instructions...',
            hintStyle: const TextStyle(
                color: Color(AppConfig.TEXT_HINT), fontSize: 14),
            filled: true,
            fillColor: const Color(AppConfig.BACKGROUND_COLOR),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConfig.RADIUS_MD),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
      ],
    );
  }
}

// ─── Order Summary Section ──────────────────────────────

class _OrderSummarySection extends StatelessWidget {
  final CartModel cart;
  const _OrderSummarySection({required this.cart});

  @override
  Widget build(BuildContext context) {
    // Group items by store
    final grouped = <int, List<CartItem>>{};
    for (final item in cart.items) {
      grouped.putIfAbsent(item.storeId, () => []).add(item);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
            title: 'Order Summary', icon: Icons.receipt_long_rounded),
        const SizedBox(height: 12),
        ...grouped.entries.map((entry) {
          final storeName = entry.value.first.storeName;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  storeName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(AppConfig.TEXT_PRIMARY),
                  ),
                ),
              ),
              ...entry.value.map((item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${item.name} x${item.quantity}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(AppConfig.TEXT_SECONDARY),
                            ),
                          ),
                        ),
                        Text(
                          item.displayLineTotal,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(AppConfig.TEXT_PRIMARY),
                          ),
                        ),
                      ],
                    ),
                  )),
              const Divider(height: 16),
            ],
          );
        }),
        const SizedBox(height: 4),
        _SummaryRow(label: 'Subtotal', value: cart.displaySubtotal),
        const SizedBox(height: 6),
        _SummaryRow(
          label: 'Delivery Fee',
          value: cart.deliveryFee == 0 ? 'Free' : cart.displayDeliveryFee,
          valueColor: cart.deliveryFee == 0
              ? const Color(AppConfig.SUCCESS_COLOR)
              : null,
        ),
        const SizedBox(height: 8),
        const Divider(height: 1),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Total',
              style: TextStyle(
                fontSize: AppConfig.FONT_SIZE_LARGE,
                fontWeight: FontWeight.w700,
                color: Color(AppConfig.TEXT_PRIMARY),
              ),
            ),
            Text(
              cart.displayTotal,
              style: const TextStyle(
                fontSize: AppConfig.FONT_SIZE_LARGE,
                fontWeight: FontWeight.w800,
                color: Color(AppConfig.PRIMARY_COLOR),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Age Verification Section ────────────────────────────

class _AgeVerificationSection extends StatelessWidget {
  final bool confirmed;
  final ValueChanged<bool> onChanged;
  const _AgeVerificationSection({
    required this.confirmed,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
            title: 'Age Verification', icon: Icons.verified_user_rounded),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(AppConfig.ACCENT_COLOR).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppConfig.RADIUS_MD),
            border: Border.all(
              color: const Color(AppConfig.ACCENT_COLOR).withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.wine_bar_rounded,
                  size: 24, color: const Color(AppConfig.ACCENT_COLOR)),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Alcohol items require age verification',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(AppConfig.TEXT_SECONDARY),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        CheckboxListTile(
          value: confirmed,
          onChanged: (v) => onChanged(v ?? false),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          activeColor: const Color(AppConfig.PRIMARY_COLOR),
          title: const Text(
            'I confirm I am 18 years or older',
            style: TextStyle(
              fontSize: AppConfig.FONT_SIZE_MEDIUM,
              fontWeight: FontWeight.w600,
              color: Color(AppConfig.TEXT_PRIMARY),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Package Delivery Section ────────────────────────────

class _PackageDeliverySection extends StatelessWidget {
  final TextEditingController descController;
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController instructionsController;
  final String packageSize;
  final ValueChanged<String> onSizeChanged;

  const _PackageDeliverySection({
    required this.descController,
    required this.nameController,
    required this.phoneController,
    required this.instructionsController,
    required this.packageSize,
    required this.onSizeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
            title: 'Package Details', icon: Icons.inventory_2_rounded),
        const SizedBox(height: 12),
        _buildField('Package Description', descController, 'Describe the package'),
        const SizedBox(height: 10),
        _buildField('Pickup Contact Name', nameController, 'Name of contact person'),
        const SizedBox(height: 10),
        _buildField('Pickup Contact Phone', phoneController, '0712 XXX XXX',
            keyboardType: TextInputType.phone),
        const SizedBox(height: 10),
        const Text(
          'Package Size',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(AppConfig.TEXT_PRIMARY),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _SizeChip(
              label: 'Small',
              value: 'small',
              selected: packageSize == 'small',
              onSelected: onSizeChanged,
            ),
            const SizedBox(width: 8),
            _SizeChip(
              label: 'Medium',
              value: 'medium',
              selected: packageSize == 'medium',
              onSelected: onSizeChanged,
            ),
            const SizedBox(width: 8),
            _SizeChip(
              label: 'Large',
              value: 'large',
              selected: packageSize == 'large',
              onSelected: onSizeChanged,
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildField('Special Instructions', instructionsController, 'Any special handling instructions', maxLines: 2),
      ],
    );
  }

  Widget _buildField(
    String label,
    TextEditingController controller,
    String hint, {
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(AppConfig.TEXT_PRIMARY),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                const TextStyle(color: Color(AppConfig.TEXT_HINT), fontSize: 14),
            filled: true,
            fillColor: const Color(AppConfig.BACKGROUND_COLOR),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConfig.RADIUS_MD),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
      ],
    );
  }
}

// ─── Size Chip ────────────────────────────────────────────

class _SizeChip extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final ValueChanged<String> onSelected;

  const _SizeChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(value),
      selectedColor: const Color(AppConfig.PRIMARY_COLOR).withValues(alpha: 0.15),
      backgroundColor: const Color(AppConfig.BACKGROUND_COLOR),
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: selected
            ? const Color(AppConfig.PRIMARY_COLOR)
            : const Color(AppConfig.TEXT_SECONDARY),
      ),
      side: BorderSide(
        color: selected
            ? const Color(AppConfig.PRIMARY_COLOR)
            : const Color(AppConfig.DIVIDER_COLOR),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConfig.RADIUS_MD),
      ),
    );
  }
}

// ─── Min Order Notice ────────────────────────────────────

class _MinOrderNotice extends StatelessWidget {
  final double current;
  final double minimum;

  const _MinOrderNotice({required this.current, required this.minimum});

  @override
  Widget build(BuildContext context) {
    final diff = minimum - current;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(AppConfig.WARNING_COLOR).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppConfig.RADIUS_MD),
        border: Border.all(
          color: const Color(AppConfig.WARNING_COLOR).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 20, color: Color(AppConfig.WARNING_COLOR)),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                    fontSize: 13, color: Color(AppConfig.TEXT_SECONDARY)),
                children: [
                  const TextSpan(text: 'Minimum order is '),
                  TextSpan(
                    text: 'KSh ${minimum.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const TextSpan(text: '. Add '),
                  TextSpan(
                    text: 'KSh ${diff.toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(AppConfig.WARNING_COLOR)),
                  ),
                  const TextSpan(text: ' more to proceed.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Payment Method Section ──────────────────────────────

class _PaymentMethodSection extends StatelessWidget {
  final String paymentMethod;
  final TextEditingController mpesaPhoneController;
  final ValueChanged<String> onPaymentChanged;

  const _PaymentMethodSection({
    required this.paymentMethod,
    required this.mpesaPhoneController,
    required this.onPaymentChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
            title: 'Payment Method', icon: Icons.payment_rounded),
        const SizedBox(height: 12),

        // M-Pesa option
        GestureDetector(
          onTap: () => onPaymentChanged('mpesa'),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: paymentMethod == 'mpesa'
                  ? const Color(AppConfig.PRIMARY_COLOR).withValues(alpha: 0.05)
                  : const Color(AppConfig.BACKGROUND_COLOR),
              borderRadius: BorderRadius.circular(AppConfig.RADIUS_MD),
              border: Border.all(
                color: paymentMethod == 'mpesa'
                    ? const Color(AppConfig.PRIMARY_COLOR)
                    : const Color(AppConfig.DIVIDER_COLOR),
                width: paymentMethod == 'mpesa' ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Radio<String>(
                  value: 'mpesa',
                  groupValue: paymentMethod,
                  onChanged: (v) => onPaymentChanged(v ?? 'mpesa'),
                  activeColor: const Color(AppConfig.PRIMARY_COLOR),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 8),
                // M-Pesa icon
                Container(
                  width: 36,
                  height: 24,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Center(
                    child: Text(
                      'M',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'M-Pesa',
                  style: TextStyle(
                    fontSize: AppConfig.FONT_SIZE_LARGE,
                    fontWeight: FontWeight.w600,
                    color: Color(AppConfig.TEXT_PRIMARY),
                  ),
                ),
              ],
            ),
          ),
        ),

        // M-Pesa phone field
        if (paymentMethod == 'mpesa') ...[
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'M-Pesa Phone Number',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(AppConfig.TEXT_SECONDARY),
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: mpesaPhoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    hintText: '0712 XXX XXX',
                    hintStyle: const TextStyle(
                        color: Color(AppConfig.TEXT_HINT), fontSize: 14),
                    filled: true,
                    fillColor: const Color(AppConfig.BACKGROUND_COLOR),
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(left: 12, right: 8),
                      child: Icon(Icons.phone_android_rounded,
                          size: 20,
                          color: Color(AppConfig.TEXT_HINT)),
                    ),
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppConfig.RADIUS_MD),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 10),

        // Cash on Delivery option
        GestureDetector(
          onTap: () => onPaymentChanged('cod'),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: paymentMethod == 'cod'
                  ? const Color(AppConfig.PRIMARY_COLOR).withValues(alpha: 0.05)
                  : const Color(AppConfig.BACKGROUND_COLOR),
              borderRadius: BorderRadius.circular(AppConfig.RADIUS_MD),
              border: Border.all(
                color: paymentMethod == 'cod'
                    ? const Color(AppConfig.PRIMARY_COLOR)
                    : const Color(AppConfig.DIVIDER_COLOR),
                width: paymentMethod == 'cod' ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Radio<String>(
                  value: 'cod',
                  groupValue: paymentMethod,
                  onChanged: (v) => onPaymentChanged(v ?? 'cod'),
                  activeColor: const Color(AppConfig.PRIMARY_COLOR),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 8),
                Container(
                  width: 36,
                  height: 24,
                  decoration: BoxDecoration(
                    color: const Color(AppConfig.ACCENT_COLOR),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(
                    Icons.payments_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Cash on Delivery',
                  style: TextStyle(
                    fontSize: AppConfig.FONT_SIZE_LARGE,
                    fontWeight: FontWeight.w600,
                    color: Color(AppConfig.TEXT_PRIMARY),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Summary Row ──────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Color(AppConfig.TEXT_SECONDARY),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: valueColor ?? const Color(AppConfig.TEXT_PRIMARY),
          ),
        ),
      ],
    );
  }
}

// ─── Place Order Button ──────────────────────────────────

class _PlaceOrderButton extends StatelessWidget {
  final String total;
  final bool canPlace;
  final bool isPlacing;
  final VoidCallback onPlace;

  const _PlaceOrderButton({
    required this.total,
    required this.canPlace,
    required this.isPlacing,
    required this.onPlace,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total',
                  style: TextStyle(
                    fontSize: AppConfig.FONT_SIZE_LARGE,
                    fontWeight: FontWeight.w600,
                    color: Color(AppConfig.TEXT_SECONDARY),
                  ),
                ),
                Text(
                  total,
                  style: const TextStyle(
                    fontSize: AppConfig.FONT_SIZE_XLARGE,
                    fontWeight: FontWeight.w800,
                    color: Color(AppConfig.PRIMARY_COLOR),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: canPlace && !isPlacing ? onPlace : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(AppConfig.PRIMARY_COLOR),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      const Color(AppConfig.TEXT_HINT).withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppConfig.RADIUS_MD),
                  ),
                ),
                child: isPlacing
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Place Order',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
