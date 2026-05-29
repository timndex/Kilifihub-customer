import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../config/app_config.dart';
import '../models/store_model.dart';
import '../models/product_model.dart';
import '../models/category_model.dart';
import '../services/api_service.dart';
import '../widgets/store_card.dart';
import '../widgets/product_card.dart';
import '../widgets/loading_widget.dart';
import '../widgets/empty_state.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final ApiService _api = ApiService.instance;
  late TabController _tabController;

  List<StoreModel> _storeResults = [];
  List<ProductModel> _productResults = [];
  bool _isSearching = false;
  bool _hasSearched = false;
  String _searchQuery = '';

  // Recent searches
  List<String> _recentSearches = [];
  static const _recentSearchesKey = 'recent_searches';

  // Category filter
  String? _selectedCategory;
  final List<Map<String, String>> _categoryFilters = [
    {'slug': '', 'label': 'All'},
    {'slug': 'hotel', 'label': '🏨 Hotels'},
    {'slug': 'pharmacy', 'label': '💊 Pharmacy'},
    {'slug': 'supermarket', 'label': '🛒 Supermarket'},
    {'slug': 'groceries', 'label': '🥬 Groceries'},
    {'slug': 'shops', 'label': '🛍️ Shops'},
    {'slug': 'package', 'label': '📦 Package'},
    {'slug': 'alcohol', 'label': '🍷 Alcohol'},
  ];

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadRecentSearches();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_recentSearchesKey);
    if (data != null) {
      final list = jsonDecode(data) as List<dynamic>;
      setState(() {
        _recentSearches = list.cast<String>();
      });
    }
  }

  Future<void> _saveRecentSearch(String query) async {
    if (query.trim().isEmpty) return;

    _recentSearches = [
      query,
      ..._recentSearches.where((s) => s != query),
    ].take(10).toList();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _recentSearchesKey,
      jsonEncode(_recentSearches),
    );
  }

  Future<void> _clearRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recentSearchesKey);
    setState(() => _recentSearches = []);
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isSearching = true;
      _hasSearched = true;
      _searchQuery = query.trim();
    });

    await _saveRecentSearch(query.trim());

    try {
      final results = await _api.search(
        query.trim(),
        category: _selectedCategory?.isNotEmpty == true
            ? _selectedCategory
            : null,
      );

      if (mounted) {
        final storesRaw = results['stores'] as List<dynamic>? ?? [];
        final productsRaw = results['products'] as List<dynamic>? ?? [];

        setState(() {
          _storeResults = storesRaw
              .map((e) => StoreModel.fromJson(e as Map<String, dynamic>))
              .toList();
          _productResults = productsRaw
              .map((e) => ProductModel.fromJson(e as Map<String, dynamic>))
              .toList();
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length >= 2) {
      _debounce = Timer(const Duration(milliseconds: 500), () {
        _performSearch(query);
      });
    } else if (query.isEmpty) {
      setState(() {
        _hasSearched = false;
        _storeResults = [];
        _productResults = [];
      });
    }
  }

  void _onRecentSearchTap(String query) {
    _searchController.text = query;
    _performSearch(query);
  }

  @override
  Widget build(BuildContext context) {
    // Check if category slug was passed as argument
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String && _selectedCategory == null && args.isNotEmpty) {
      _selectedCategory = args;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Search',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        children: [
          // ── Search Field ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onSubmitted: _performSearch,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search stores, products...',
                hintStyle: const TextStyle(
                  fontSize: 14,
                  color: Color(AppConfig.TEXT_HINT),
                ),
                prefixIcon: const Icon(Icons.search, size: 22),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _hasSearched = false;
                            _storeResults = [];
                            _productResults = [];
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(AppConfig.BACKGROUND_COLOR),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppConfig.RADIUS_XL),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

          // ── Category Filter Chips ──
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categoryFilters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final filter = _categoryFilters[index];
                final isSelected =
                    (_selectedCategory ?? '') == filter['slug'];
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedCategory =
                          filter['slug']!.isEmpty ? null : filter['slug'];
                    });
                    if (_searchQuery.isNotEmpty) {
                      _performSearch(_searchQuery);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(AppConfig.PRIMARY_COLOR)
                          : const Color(AppConfig.BACKGROUND_COLOR),
                      borderRadius:
                          BorderRadius.circular(AppConfig.RADIUS_ROUND),
                      border: Border.all(
                        color: isSelected
                            ? const Color(AppConfig.PRIMARY_COLOR)
                            : const Color(AppConfig.DIVIDER_COLOR),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        filter['label']!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : const Color(AppConfig.TEXT_SECONDARY),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          // ── Results Tabs ──
          if (_hasSearched) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(AppConfig.BACKGROUND_COLOR),
                borderRadius: BorderRadius.circular(AppConfig.RADIUS_MD),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: Colors.white,
                unselectedLabelColor: const Color(AppConfig.TEXT_SECONDARY),
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: const Color(AppConfig.PRIMARY_COLOR),
                  borderRadius: BorderRadius.circular(AppConfig.RADIUS_MD),
                ),
                dividerColor: Colors.transparent,
                tabs: [
                  Tab(text: 'Stores (${_storeResults.length})'),
                  Tab(text: 'Products (${_productResults.length})'),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ── Content ──
          Expanded(
            child: _isSearching
                ? const LoadingWidget()
                : !_hasSearched
                    ? _buildRecentSearches()
                    : _storeResults.isEmpty && _productResults.isEmpty
                        ? EmptyState.noSearchResults(query: _searchQuery)
                        : TabBarView(
                            controller: _tabController,
                            children: [
                              _buildStoreResults(),
                              _buildProductResults(),
                            ],
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentSearches() {
    if (_recentSearches.isEmpty) {
      return Center(
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
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Searches',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(AppConfig.TEXT_PRIMARY),
              ),
            ),
            GestureDetector(
              onTap: _clearRecentSearches,
              child: const Text(
                'Clear',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(AppConfig.PRIMARY_COLOR),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._recentSearches.map((query) => ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 0),
              leading: const Icon(
                Icons.history,
                color: Color(AppConfig.TEXT_HINT),
                size: 20,
              ),
              title: Text(
                query,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(AppConfig.TEXT_PRIMARY),
                ),
              ),
              trailing: const Icon(
                Icons.north_west,
                size: 16,
                color: Color(AppConfig.TEXT_HINT),
              ),
              onTap: () => _onRecentSearchTap(query),
            )),
      ],
    );
  }

  Widget _buildStoreResults() {
    if (_storeResults.isEmpty) {
      return const Center(
        child: EmptyState(
          icon: Icons.store_outlined,
          title: 'No Stores Found',
          subtitle: 'No stores match your search.',
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.68,
      ),
      itemCount: _storeResults.length,
      itemBuilder: (context, index) {
        final store = _storeResults[index];
        return StoreCard(
          store: store,
          onTap: () {
            Navigator.pushNamed(
              context,
              '/store-detail',
              arguments: store.vendorId,
            );
          },
        );
      },
    );
  }

  Widget _buildProductResults() {
    if (_productResults.isEmpty) {
      return const Center(
        child: EmptyState(
          icon: Icons.shopping_bag_outlined,
          title: 'No Products Found',
          subtitle: 'No products match your search.',
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _productResults.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final product = _productResults[index];
        return GestureDetector(
          onTap: () {
            Navigator.pushNamed(
              context,
              '/product-detail',
              arguments: {
                'productId': product.id,
                'vendorId': 0, // We don't have vendorId in search results
              },
            );
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppConfig.RADIUS_LG),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Product image
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppConfig.RADIUS_MD),
                  child: product.hasImage
                      ? CachedNetworkImage(
                          imageUrl: product.imageUrl,
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              _productImagePlaceholder(),
                        )
                      : _productImagePlaceholder(),
                ),
                const SizedBox(width: 12),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(AppConfig.TEXT_PRIMARY),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            product.displayPrice,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Color(AppConfig.PRIMARY_COLOR),
                            ),
                          ),
                          if (product.isOnSale) ...[
                            const SizedBox(width: 6),
                            Text(
                              product.displayRegularPrice,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(AppConfig.TEXT_HINT),
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Add button
                if (product.inStock)
                  GestureDetector(
                    onTap: () {
                      // Add to cart
                      context.read<CartProvider>().addItem(product.id, 1);
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: Color(AppConfig.PRIMARY_COLOR),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _productImagePlaceholder() {
    return Container(
      width: 64,
      height: 64,
      color: const Color(AppConfig.BACKGROUND_COLOR),
      child: const Icon(
        Icons.shopping_bag_outlined,
        color: Color(AppConfig.TEXT_HINT),
        size: 24,
      ),
    );
  }
}
