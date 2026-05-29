import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../models/product_model.dart';
import '../models/store_model.dart';
import '../services/api_service.dart';
import '../providers/cart_provider.dart';
import '../widgets/loading_widget.dart';
import '../widgets/empty_state.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final ApiService _api = ApiService.instance;

  int _productId = 0;
  int _vendorId = 0;
  ProductModel? _product;
  StoreModel? _store;
  bool _isLoading = true;
  String? _error;
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _extractArgs();
      _loadProductDetail();
    });
  }

  void _extractArgs() {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      _productId = args['productId'] as int? ?? 0;
      _vendorId = args['vendorId'] as int? ?? 0;
    } else if (args is int) {
      _productId = args;
    }
  }

  Future<void> _loadProductDetail() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load store detail which includes products
      final data = await _api.getStoreDetail(_vendorId);
      _store = StoreModel.fromJson(
          data['store'] as Map<String, dynamic>? ?? data);

      final rawProducts = data['products'] as List<dynamic>? ?? [];
      final products = rawProducts
          .map((e) => ProductModel.fromJson(e as Map<String, dynamic>))
          .toList();

      _product = products.where((p) => p.id == _productId).firstOrNull;

      if (_product != null) {
        // Check if already in cart
        final cartProvider = context.read<CartProvider>();
        final existingQty = cartProvider.getProductQuantity(_productId);
        if (existingQty > 0) {
          _quantity = existingQty;
        }
      }

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _addToCart() async {
    if (_product == null) return;

    final cartProvider = context.read<CartProvider>();
    final success = await cartProvider.addItem(_product!.id, _quantity);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_product!.name} added to cart'),
          backgroundColor: const Color(AppConfig.SUCCESS_COLOR),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'View Cart',
            textColor: Colors.white,
            onPressed: () => Navigator.pushNamed(context, '/cart'),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConfig.RADIUS_MD),
          ),
        ),
      );
    } else if (cartProvider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(cartProvider.error!),
          backgroundColor: const Color(AppConfig.ERROR_COLOR),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConfig.RADIUS_MD),
          ),
        ),
      );
    }
  }

  Color get _categoryColor {
    if (_store != null) {
      return Color(AppConfig.getCategoryColor(_store!.category));
    }
    return const Color(AppConfig.PRIMARY_COLOR);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(backgroundColor: Colors.white, elevation: 0),
        body: const LoadingWidget(),
      );
    }

    if (_error != null || _product == null) {
      return Scaffold(
        appBar: AppBar(backgroundColor: Colors.white, elevation: 0),
        body: EmptyState.error(
          message: _error ?? 'Product not found',
          onRetry: _loadProductDetail,
        ),
      );
    }

    final cartProvider = context.watch<CartProvider>();
    final inCartQty = cartProvider.getProductQuantity(_product!.id);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Product Image ──
            Stack(
              children: [
                _product!.hasImage
                    ? CachedNetworkImage(
                        imageUrl: _product!.imageUrl,
                        width: double.infinity,
                        height: 300,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => _imagePlaceholder(),
                        errorWidget: (_, __, ___) => _imagePlaceholder(),
                      )
                    : _imagePlaceholder(),

                // Back button
                Positioned(
                  top: 12,
                  left: 12,
                  child: CircleAvatar(
                    backgroundColor: Colors.white.withValues(alpha: 0.9),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),

                // Sale badge
                if (_product!.isOnSale)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(AppConfig.PRIMARY_COLOR),
                        borderRadius:
                            BorderRadius.circular(AppConfig.RADIUS_MD),
                      ),
                      child: const Text(
                        'SALE',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            // ── Store Info Card ──
            if (_store != null)
              GestureDetector(
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    '/store-detail',
                    arguments: _vendorId,
                  );
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _categoryColor.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(AppConfig.RADIUS_MD),
                    border: Border.all(
                      color: _categoryColor.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: _categoryColor.withValues(alpha: 0.15),
                        backgroundImage: _store!.hasAvatar
                            ? CachedNetworkImageProvider(_store!.storeAvatar)
                            : null,
                        child: !_store!.hasAvatar
                            ? Text(
                                _store!.storeName[0].toUpperCase(),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: _categoryColor,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _store!.storeName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _categoryColor,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: _categoryColor,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),

            // ── Product Info ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name
                  Text(
                    _product!.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(AppConfig.TEXT_PRIMARY),
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Price
                  Row(
                    children: [
                      Text(
                        _product!.displayPrice,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(AppConfig.PRIMARY_COLOR),
                        ),
                      ),
                      if (_product!.isOnSale) ...[
                        const SizedBox(width: 10),
                        Text(
                          _product!.displayRegularPrice,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color(AppConfig.TEXT_HINT),
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                    ],
                  ),

                  // In stock / Out of stock
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _product!.inStock
                          ? const Color(AppConfig.SUCCESS_COLOR).withValues(alpha: 0.1)
                          : const Color(AppConfig.ERROR_COLOR).withValues(alpha: 0.1),
                      borderRadius:
                          BorderRadius.circular(AppConfig.RADIUS_SM),
                    ),
                    child: Text(
                      _product!.inStock ? 'In Stock' : 'Out of Stock',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _product!.inStock
                            ? const Color(AppConfig.SUCCESS_COLOR)
                            : const Color(AppConfig.ERROR_COLOR),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Short Description ──
                  if (_product!.shortDescription.isNotEmpty) ...[
                    const Text(
                      'About',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(AppConfig.TEXT_PRIMARY),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _product!.shortDescription,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(AppConfig.TEXT_SECONDARY),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── Quantity Selector ──
                  const Text(
                    'Quantity',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(AppConfig.TEXT_PRIMARY),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: const Color(AppConfig.DIVIDER_COLOR)),
                      borderRadius:
                          BorderRadius.circular(AppConfig.RADIUS_MD),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _qtyButton(
                          icon: Icons.remove_rounded,
                          onTap: _quantity > 1
                              ? () => setState(() => _quantity--)
                              : null,
                        ),
                        Container(
                          width: 48,
                          alignment: Alignment.center,
                          child: Text(
                            '$_quantity',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(AppConfig.TEXT_PRIMARY),
                            ),
                          ),
                        ),
                        _qtyButton(
                          icon: Icons.add_rounded,
                          onTap: () => setState(() => _quantity++),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Already in cart indicator ──
                  if (inCartQty > 0)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: const Color(AppConfig.PRIMARY_COLOR).withValues(alpha: 0.06),
                        borderRadius:
                            BorderRadius.circular(AppConfig.RADIUS_MD),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.shopping_cart_rounded,
                            size: 18,
                            color: Color(AppConfig.PRIMARY_COLOR),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$inCartQty already in cart',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(AppConfig.PRIMARY_COLOR),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),

      // ── Bottom Add to Cart Button ──
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(AppConfig.TEXT_HINT),
                      ),
                    ),
                    Text(
                      'KSh ${(_product!.priceValue * _quantity).toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(AppConfig.TEXT_PRIMARY),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _product!.inStock ? _addToCart : null,
                  icon: Icon(
                    inCartQty > 0
                        ? Icons.update_rounded
                        : Icons.add_shopping_cart_rounded,
                    size: 20,
                  ),
                  label: Text(
                    inCartQty > 0 ? 'Update Cart' : 'Add to Cart',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(AppConfig.PRIMARY_COLOR),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        const Color(AppConfig.PRIMARY_COLOR).withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppConfig.RADIUS_MD),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _qtyButton({required IconData icon, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        child: Icon(
          icon,
          color: onTap != null
              ? const Color(AppConfig.TEXT_PRIMARY)
              : const Color(AppConfig.TEXT_HINT),
          size: 20,
        ),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      height: 300,
      width: double.infinity,
      color: const Color(AppConfig.BACKGROUND_COLOR),
      child: const Icon(
        Icons.shopping_bag_outlined,
        size: 64,
        color: Color(AppConfig.TEXT_HINT),
      ),
    );
  }
}
