import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:pull_to_refresh_flutter3/pull_to_refresh_flutter3.dart';

import '../config/app_config.dart';
import '../models/category_model.dart';
import '../models/store_model.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../providers/cart_provider.dart';
import '../providers/order_provider.dart';
import '../widgets/category_card.dart';
import '../widgets/store_card.dart';
import '../widgets/cart_badge.dart';
import '../widgets/loading_widget.dart';
import '../widgets/empty_state.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final RefreshController _refreshController = RefreshController();

  // Home tab data
  List<CategoryModel> _categories = [];
  List<StoreModel> _popularStores = [];
  bool _isLoadingCategories = true;
  bool _isLoadingStores = true;
  String? _categoryError;
  String? _storeError;

  // Orders tab data placeholder
  // Profile tab data placeholder

  final ApiService _api = ApiService.instance;

  @override
  void initState() {
    super.initState();
    _loadHomeData();
  }

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }

  Future<void> _loadHomeData() async {
    await Future.wait([
      _loadCategories(),
      _loadPopularStores(),
    ]);
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isLoadingCategories = true;
      _categoryError = null;
    });
    try {
      _categories = await _api.getCategories();
      if (mounted) {
        setState(() => _isLoadingCategories = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingCategories = false;
          _categoryError = e.toString();
        });
      }
    }
  }

  Future<void> _loadPopularStores() async {
    setState(() {
      _isLoadingStores = true;
      _storeError = null;
    });
    try {
      // Load stores from the first active category as "popular"
      if (_categories.isNotEmpty) {
        _popularStores = await _api.getStores(
          _categories.first.slug,
        );
      } else {
        // Try hotel as default
        _popularStores = await _api.getStores('hotel');
      }
      if (mounted) {
        setState(() => _isLoadingStores = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingStores = false;
          _storeError = e.toString();
        });
      }
    }
  }

  Future<void> _onRefresh() async {
    await _loadHomeData();
    _refreshController.refreshCompleted();
  }

  void _navigateToCategory(CategoryModel category) {
    Navigator.pushNamed(
      context,
      '/stores',
      arguments: category,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildHomeTab(),
          _buildSearchTab(),
          _buildOrdersTab(),
          _buildProfileTab(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── Bottom Navigation ──

  Widget _buildBottomNav() {
    return Container(
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
      child: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        backgroundColor: Colors.white,
        indicatorColor: const Color(AppConfig.PRIMARY_COLOR).withValues(alpha: 0.1),
        height: 64,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          const NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search_rounded),
            label: 'Search',
          ),
          NavigationDestination(
            icon: Consumer<CartProvider>(
              builder: (_, cart, __) => CartBadge(
                icon: Icons.receipt_long_outlined,
                iconSize: 24,
                onTap: null,
              ),
            ),
            selectedIcon: const Icon(Icons.receipt_long_rounded),
            label: 'Orders',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  // ── Home Tab ──

  Widget _buildHomeTab() {
    return SmartRefresher(
      controller: _refreshController,
      enablePullDown: true,
      onRefresh: _onRefresh,
      child: CustomScrollView(
        slivers: [
          // ── App Bar ──
          SliverToBoxAdapter(child: _buildAppBar()),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // ── Search Bar ──
          SliverToBoxAdapter(child: _buildSearchBar()),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),

          // ── Categories ──
          SliverToBoxAdapter(
            child: _buildSectionHeader('Categories', onSeeAll: null),
          ),
          _isLoadingCategories
              ? SliverToBoxAdapter(
                  child: _buildCategoryShimmer(),
                )
              : _categoryError != null
                  ? SliverToBoxAdapter(
                      child: EmptyState.error(
                        message: _categoryError,
                        onRetry: _loadCategories,
                      ),
                    )
                  : SliverToBoxAdapter(
                      child: _buildCategoriesList(),
                    ),
          const SliverToBoxAdapter(child: SizedBox(height: 28)),

          // ── Popular Near You ──
          SliverToBoxAdapter(
            child: _buildSectionHeader('Popular Near You'),
          ),
          _isLoadingStores
              ? SliverToBoxAdapter(
                  child: _buildHorizontalShimmer(),
                )
              : _popularStores.isEmpty
                  ? SliverToBoxAdapter(
                      child: SizedBox(
                        height: 180,
                        child: EmptyState.noStores(onRetry: _loadPopularStores),
                      ),
                    )
                  : SliverToBoxAdapter(
                      child: _buildPopularStores(),
                    ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),

          // ── Quick Delivery Banner ──
          SliverToBoxAdapter(child: _buildQuickDeliveryBanner()),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            // Location selector
            GestureDetector(
              onTap: () {
                // TODO: Open location picker
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.location_on_rounded,
                    color: Color(AppConfig.PRIMARY_COLOR),
                    size: 20,
                  ),
                  const SizedBox(width: 4),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Deliver to',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(AppConfig.TEXT_HINT),
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Consumer<AuthService>(
                            builder: (_, auth, __) {
                              return Text(
                                auth.currentUser?.firstName.isNotEmpty == true
                                    ? '${auth.currentUser!.firstName}\'s Location'
                                    : 'Kilifi, Kenya',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(AppConfig.TEXT_PRIMARY),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 2),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 18,
                            color: Color(AppConfig.TEXT_SECONDARY),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Spacer(),
            // App title
            const Text(
              AppConfig.APP_NAME,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(AppConfig.PRIMARY_COLOR),
              ),
            ),
            const Spacer(),
            // Notification bell
            Stack(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.notifications_outlined,
                    size: 24,
                    color: Color(AppConfig.TEXT_PRIMARY),
                  ),
                  onPressed: () {
                    // TODO: Navigate to notifications
                  },
                ),
                // Notification badge dot
                Positioned(
                  top: 10,
                  right: 12,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(AppConfig.PRIMARY_COLOR),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () {
          setState(() => _currentIndex = 1);
        },
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: const Color(AppConfig.BACKGROUND_COLOR),
            borderRadius: BorderRadius.circular(AppConfig.RADIUS_XL),
          ),
          child: Row(
            children: [
              const SizedBox(width: 16),
              const Icon(
                Icons.search,
                color: Color(AppConfig.TEXT_HINT),
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(
                'Search stores, products...',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(AppConfig.TEXT_HINT),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, {VoidCallback? onSeeAll}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(AppConfig.TEXT_PRIMARY),
            ),
          ),
          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              child: const Text(
                'See All',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(AppConfig.PRIMARY_COLOR),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoriesList() {
    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          final category = _categories[index];
          return CategoryCard(
            category: category,
            onTap: () => _navigateToCategory(category),
          );
        },
      ),
    );
  }

  Widget _buildPopularStores() {
    return SizedBox(
      height: 210,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _popularStores.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final store = _popularStores[index];
          return SizedBox(
            width: 180,
            child: StoreCard(
              store: store,
              onTap: () {
                Navigator.pushNamed(
                  context,
                  '/store-detail',
                  arguments: store.vendorId,
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickDeliveryBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(AppConfig.PRIMARY_COLOR), Color(0xFFFF6B6B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppConfig.RADIUS_LG),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Quick Delivery',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Get your orders delivered in 30-45 minutes',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white70,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delivery_dining_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryShimmer() {
    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 7,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (_, __) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(AppConfig.DIVIDER_COLOR),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: 48,
              height: 10,
              decoration: BoxDecoration(
                color: const Color(AppConfig.DIVIDER_COLOR),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHorizontalShimmer() {
    return const HorizontalShimmer();
  }

  // ── Search Tab (redirects to SearchScreen) ──

  Widget _buildSearchTab() {
    // Navigate to search screen inline
    return const _InlineSearchScreen();
  }

  // ── Orders Tab ──

  Widget _buildOrdersTab() {
    return const _OrdersTab();
  }

  // ── Profile Tab ──

  Widget _buildProfileTab() {
    return const _ProfileTab();
  }
}

// ── Orders Tab (placeholder) ──

class _OrdersTab extends StatefulWidget {
  const _OrdersTab();

  @override
  State<_OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<_OrdersTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrderProvider>().fetchOrders();
    });
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = context.watch<OrderProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Orders',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: orderProvider.isLoading
          ? const LoadingWidget(message: 'Loading orders...')
          : orderProvider.orders.isEmpty
              ? EmptyState.noOrders(
                  onBrowse: () {
                    // Switch to home tab - find HomeScreen state
                  },
                )
              : RefreshIndicator(
                  onRefresh: () => orderProvider.fetchOrders(),
                  color: const Color(AppConfig.PRIMARY_COLOR),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: orderProvider.orders.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final order = orderProvider.orders[index];
                      return _buildOrderCard(order);
                    },
                  ),
                ),
    );
  }

  Widget _buildOrderCard(dynamic order) {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          '/order-detail',
          arguments: order.id,
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppConfig.RADIUS_LG),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: order.statusColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                order.statusIcon,
                color: order.statusColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '#${order.orderNumber}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Color(AppConfig.TEXT_PRIMARY),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    order.storeName.isNotEmpty
                        ? order.storeName
                        : '${order.itemCount} items',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(AppConfig.TEXT_SECONDARY),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  order.displayTotal,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(AppConfig.TEXT_PRIMARY),
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: order.statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppConfig.RADIUS_SM),
                  ),
                  child: Text(
                    order.statusLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: order.statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Profile Tab (placeholder) ──

class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final user = authService.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Profile',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // User info card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppConfig.RADIUS_LG),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor:
                        const Color(AppConfig.PRIMARY_COLOR).withValues(alpha: 0.1),
                    backgroundImage: user?.hasAvatar == true
                        ? CachedNetworkImageProvider(user!.avatar)
                        : null,
                    child: user?.hasAvatar != true
                        ? Text(
                            user?.initials ?? '?',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Color(AppConfig.PRIMARY_COLOR),
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.fullName ?? 'Guest',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(AppConfig.TEXT_PRIMARY),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user?.email ?? '',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(AppConfig.TEXT_SECONDARY),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    onPressed: () {
                      Navigator.pushNamed(context, '/profile');
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Menu items
            _buildMenuTile(
              icon: Icons.location_on_outlined,
              title: 'Saved Addresses',
              onTap: () => Navigator.pushNamed(context, '/addresses'),
            ),
            _buildMenuTile(
              icon: Icons.receipt_long_outlined,
              title: 'My Orders',
              onTap: () => Navigator.pushNamed(context, '/orders'),
            ),
            _buildMenuTile(
              icon: Icons.payment_outlined,
              title: 'Payment Methods',
              onTap: () {},
            ),
            _buildMenuTile(
              icon: Icons.help_outline_rounded,
              title: 'Help & Support',
              onTap: () {},
            ),
            _buildMenuTile(
              icon: Icons.info_outline_rounded,
              title: 'About',
              onTap: () {},
            ),
            const SizedBox(height: 24),

            // Logout
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () async {
                  await authService.logout();
                  if (context.mounted) {
                    Navigator.pushNamedAndRemoveUntil(
                        context, '/login', (route) => false);
                  }
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(AppConfig.ERROR_COLOR),
                  side: const BorderSide(color: Color(AppConfig.ERROR_COLOR)),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppConfig.RADIUS_MD),
                  ),
                ),
                child: const Text(
                  'Log Out',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        leading: Icon(icon, color: const Color(AppConfig.TEXT_PRIMARY)),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 15,
            color: Color(AppConfig.TEXT_PRIMARY),
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: Color(AppConfig.TEXT_HINT),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConfig.RADIUS_MD),
        ),
        onTap: onTap,
      ),
    );
  }
}

// ── Inline Search Tab (simplified version of SearchScreen) ──

class _InlineSearchScreen extends StatefulWidget {
  const _InlineSearchScreen();

  @override
  State<_InlineSearchScreen> createState() => _InlineSearchScreenState();
}

class _InlineSearchScreenState extends State<_InlineSearchScreen> {
  final _searchController = TextEditingController();
  final ApiService _api = ApiService.instance;

  List<dynamic> _storeResults = [];
  List<dynamic> _productResults = [];
  bool _isSearching = false;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isSearching = true;
      _hasSearched = true;
    });

    try {
      final results = await _api.search(query.trim());
      if (mounted) {
        setState(() {
          _storeResults = results['stores'] as List<dynamic>? ?? [];
          _productResults = results['products'] as List<dynamic>? ?? [];
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Search',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search field
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onSubmitted: _performSearch,
              decoration: InputDecoration(
                hintText: 'Search stores, products...',
                prefixIcon: const Icon(Icons.search, size: 22),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _storeResults = [];
                            _productResults = [];
                            _hasSearched = false;
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(AppConfig.BACKGROUND_COLOR),
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppConfig.RADIUS_XL),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          // Results
          Expanded(
            child: _isSearching
                ? const LoadingWidget()
                : !_hasSearched
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.search,
                              size: 64,
                              color: Color(AppConfig.TEXT_HINT).withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Search for stores and products',
                              style: TextStyle(
                                color: Color(AppConfig.TEXT_SECONDARY),
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      )
                    : _storeResults.isEmpty && _productResults.isEmpty
                        ? EmptyState.noSearchResults(
                            query: _searchController.text,
                          )
                        : ListView(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            children: [
                              if (_storeResults.isNotEmpty) ...[
                                const Text(
                                  'Stores',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Color(AppConfig.TEXT_PRIMARY),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ..._storeResults.map((store) => ListTile(
                                      leading: const Icon(Icons.store_outlined),
                                      title: Text(store['store_name'] ?? ''),
                                      subtitle: Text(
                                          store['category_label'] ?? ''),
                                      onTap: () {
                                        Navigator.pushNamed(
                                          context,
                                          '/store-detail',
                                          arguments: store['vendor_id'],
                                        );
                                      },
                                    )),
                                const SizedBox(height: 16),
                              ],
                              if (_productResults.isNotEmpty) ...[
                                const Text(
                                  'Products',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Color(AppConfig.TEXT_PRIMARY),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ..._productResults.map((product) => ListTile(
                                      leading:
                                          const Icon(Icons.shopping_bag_outlined),
                                      title: Text(product['name'] ?? ''),
                                      subtitle: Text(
                                          'KSh ${product['price'] ?? '0'}'),
                                      onTap: () {
                                        Navigator.pushNamed(
                                          context,
                                          '/product-detail',
                                          arguments: {
                                            'productId': product['id'],
                                            'vendorId': product['store_id'],
                                          },
                                        );
                                      },
                                    )),
                              ],
                            ],
                          ),
          ),
        ],
      ),
    );
  }
}
