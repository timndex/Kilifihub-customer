import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh_flutter3/pull_to_refresh_flutter3.dart';

import '../config/app_config.dart';
import '../models/store_model.dart';
import '../models/product_model.dart';
import '../services/api_service.dart';
import '../providers/cart_provider.dart';
import '../widgets/product_card.dart';
import '../widgets/loading_widget.dart';
import '../widgets/empty_state.dart';

class StoreDetailScreen extends StatefulWidget {
  const StoreDetailScreen({super.key});

  @override
  State<StoreDetailScreen> createState() => _StoreDetailScreenState();
}

class _StoreDetailScreenState extends State<StoreDetailScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService.instance;
  final RefreshController _refreshController = RefreshController();

  int _vendorId = 0;
  StoreModel? _store;
  List<ProductModel> _products = [];
  List<String> _productCategories = [];
  bool _isLoading = true;
  bool _isLoadingProducts = false;
  String? _error;

  TabController? _tabController;
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _extractArgs();
      _loadStoreDetail();
    });
  }

  @override
  void dispose() {
    _refreshController.dispose();
    _tabController?.dispose();
    super.dispose();
  }

  void _extractArgs() {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is int) {
      _vendorId = args;
    } else if (args is Map<String, dynamic>) {
      _vendorId = args['vendorId'] as int? ?? 0;
    }
  }

  Future<void> _loadStoreDetail() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await _api.getStoreDetail(_vendorId);
      _store = StoreModel.fromJson(data['store'] as Map<String, dynamic>? ?? data);

      final rawProducts = data['products'] as List<dynamic>? ?? [];
      _products = rawProducts
          .map((e) => ProductModel.fromJson(e as Map<String, dynamic>))
          .toList();

      // Extract unique product categories
      final categorySet = <String>{};
      for (final p in _products) {
        categorySet.addAll(p.categories);
      }
      _productCategories = ['All', ...categorySet.toList()];

      // Setup tab controller
      _tabController?.dispose();
      _tabController = TabController(
        length: _productCategories.length,
        vsync: this,
      );
      _tabController!.addListener(() {
        if (!_tabController!.indexIsChanging) {
          setState(() => _currentTab = _tabController!.index);
        }
      });

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

  Future<void> _onRefresh() async {
    await _loadStoreDetail();
    _refreshController.refreshCompleted();
  }

  List<ProductModel> get _filteredProducts {
    if (_currentTab == 0 || _productCategories.isEmpty) return _products;
    final category = _productCategories[_currentTab];
    return _products.where((p) => p.categories.contains(category)).toList();
  }

  /// Category-specific label for the product list header
  String get _productListLabel {
    if (_store == null) return 'Products';
    switch (_store!.category) {
      case 'hotel':
        return 'Menu';
      case 'pharmacy':
        return 'Medicines & Products';
      case 'supermarket':
        return 'Products';
      case 'groceries':
        return 'Fresh Items';
      default:
        return 'Products';
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

    if (_error != null || _store == null) {
      return Scaffold(
        appBar: AppBar(backgroundColor: Colors.white, elevation: 0),
        body: EmptyState.error(
          message: _error ?? 'Store not found',
          onRetry: _loadStoreDetail,
        ),
      );
    }

    final cartProvider = context.watch<CartProvider>();

    return Scaffold(
      backgroundColor: const Color(AppConfig.BACKGROUND_COLOR),
      body: SmartRefresher(
        controller: _refreshController,
        enablePullDown: true,
        onRefresh: _onRefresh,
        child: CustomScrollView(
          slivers: [
            // ── App Bar ──
            SliverAppBar(
              expandedHeight: 180,
              pinned: true,
              backgroundColor: _categoryColor,
              foregroundColor: Colors.white,
              actions: [
                IconButton(
                  icon: const Icon(Icons.share_outlined),
                  onPressed: () {
                    // TODO: Share store
                  },
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: _store!.hasBanner
                    ? CachedNetworkImage(
                        imageUrl: _store!.storeBanner,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) =>
                            _bannerPlaceholder(),
                      )
                    : _bannerPlaceholder(),
              ),
            ),

            // ── Store Info Section ──
            SliverToBoxAdapter(child: _buildStoreInfo()),

            // ── Product Category Label ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Text(
                  _productListLabel,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(AppConfig.TEXT_PRIMARY),
                  ),
                ),
              ),
            ),

            // ── Category Tabs ──
            if (_productCategories.length > 1)
              SliverToBoxAdapter(
                child: _buildCategoryTabs(),
              ),

            // ── Products Grid ──
            _filteredProducts.isEmpty
                ? SliverToBoxAdapter(
                    child: SizedBox(
                      height: 300,
                      child: EmptyState(
                        icon: Icons.inventory_2_outlined,
                        title: 'No Products',
                        subtitle: 'This store hasn\'t added products yet.',
                      ),
                    ),
                  )
                : SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.62,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final product = _filteredProducts[index];
                          return ProductCard(
                            product: product,
                            vendorId: _vendorId,
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                '/product-detail',
                                arguments: {
                                  'productId': product.id,
                                  'vendorId': _vendorId,
                                },
                              );
                            },
                          );
                        },
                        childCount: _filteredProducts.length,
                      ),
                    ),
                  ),

            // Bottom padding for floating cart button
            const SliverToBoxAdapter(
              child: SizedBox(height: 80),
            ),
          ],
        ),
      ),
      // ── Floating Cart Button ──
      floatingActionButton: cartProvider.isNotEmpty
          ? _buildCartButton(cartProvider)
          : null,
    );
  }

  Widget _bannerPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _categoryColor.withValues(alpha: 0.8),
            _categoryColor.withValues(alpha: 0.4),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.storefront_rounded,
          size: 56,
          color: Colors.white.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Widget _buildStoreInfo() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 28,
                backgroundColor: _categoryColor.withValues(alpha: 0.15),
                backgroundImage: _store!.hasAvatar
                    ? CachedNetworkImageProvider(_store!.storeAvatar)
                    : null,
                child: !_store!.hasAvatar
                    ? Text(
                        _store!.storeName.isNotEmpty
                            ? _store!.storeName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: _categoryColor,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 14),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _store!.storeName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(AppConfig.TEXT_PRIMARY),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        // Rating
                        Row(
                          children: [
                            const Icon(Icons.star,
                                size: 16, color: Color(AppConfig.ACCENT_COLOR)),
                            const SizedBox(width: 2),
                            Text(
                              _store!.ratingDisplay,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        // Delivery time
                        const Icon(Icons.access_time,
                            size: 14, color: Color(AppConfig.TEXT_SECONDARY)),
                        const SizedBox(width: 2),
                        Text(
                          _store!.deliveryTime,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(AppConfig.TEXT_SECONDARY),
                          ),
                        ),
                      ],
                    ),
                    if (_store!.minOrder > 0) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Min order: ${_store!.minOrderDisplay}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(AppConfig.TEXT_HINT),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Open / Closed
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _store!.isOpen
                      ? const Color(AppConfig.SUCCESS_COLOR).withValues(alpha: 0.1)
                      : const Color(AppConfig.ERROR_COLOR).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppConfig.RADIUS_ROUND),
                ),
                child: Text(
                  _store!.isOpen ? 'Open' : 'Closed',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _store!.isOpen
                        ? const Color(AppConfig.SUCCESS_COLOR)
                        : const Color(AppConfig.ERROR_COLOR),
                  ),
                ),
              ),
            ],
          ),
          if (_store!.storeAddress.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 14, color: Color(AppConfig.TEXT_HINT)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _store!.storeAddress,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(AppConfig.TEXT_HINT),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryTabs() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: _categoryColor,
        unselectedLabelColor: const Color(AppConfig.TEXT_SECONDARY),
        indicatorColor: _categoryColor,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
        tabAlignment: TabAlignment.start,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        tabs: _productCategories
            .map((cat) => Tab(text: cat))
            .toList(),
      ),
    );
  }

  Widget _buildCartButton(CartProvider cartProvider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushNamed(context, '/cart');
        },
        backgroundColor: const Color(AppConfig.PRIMARY_COLOR),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.shopping_cart_rounded, size: 20),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${cartProvider.itemCount} item${cartProvider.itemCount != 1 ? 's' : ''}',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 1,
              height: 16,
              color: Colors.white38,
            ),
            const SizedBox(width: 8),
            Text(
              cartProvider.displayTotal,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
