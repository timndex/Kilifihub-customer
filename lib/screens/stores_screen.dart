import 'package:flutter/material.dart';
import 'package:pull_to_refresh_flutter3/pull_to_refresh_flutter3.dart';

import '../config/app_config.dart';
import '../models/category_model.dart';
import '../models/store_model.dart';
import '../services/api_service.dart';
import '../widgets/store_card.dart';
import '../widgets/loading_widget.dart';
import '../widgets/empty_state.dart';

class StoresScreen extends StatefulWidget {
  const StoresScreen({super.key});

  @override
  State<StoresScreen> createState() => _StoresScreenState();
}

class _StoresScreenState extends State<StoresScreen> {
  final ApiService _api = ApiService.instance;
  final RefreshController _refreshController = RefreshController();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  CategoryModel? _category;
  List<StoreModel> _stores = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;
  int _currentPage = 1;
  bool _hasMore = true;
  String _searchQuery = '';
  String _activeFilter = 'All';

  final List<String> _filterChips = [
    'All',
    'Open Now',
    'Free Delivery',
    'Top Rated',
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _extractArgs();
      _loadStores();
    });
  }

  @override
  void dispose() {
    _refreshController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _extractArgs() {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is CategoryModel) {
      _category = args;
    } else if (args is String) {
      _category = CategoryModel(slug: args, label: args.toUpperCase());
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore &&
        !_isLoading) {
      _loadMoreStores();
    }
  }

  Future<void> _loadStores() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _currentPage = 1;
      _hasMore = true;
    });

    try {
      final stores = await _api.getStores(
        _category?.slug ?? 'hotel',
        page: 1,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
      );
      if (mounted) {
        setState(() {
          _stores = stores;
          _isLoading = false;
          _hasMore = stores.length >= AppConfig.DEFAULT_PAGE_SIZE;
        });
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

  Future<void> _loadMoreStores() async {
    if (_isLoadingMore) return;
    setState(() => _isLoadingMore = true);

    try {
      final nextPage = _currentPage + 1;
      final stores = await _api.getStores(
        _category?.slug ?? 'hotel',
        page: nextPage,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
      );
      if (mounted) {
        setState(() {
          _currentPage = nextPage;
          _stores.addAll(stores);
          _isLoadingMore = false;
          _hasMore = stores.length >= AppConfig.DEFAULT_PAGE_SIZE;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  Future<void> _onRefresh() async {
    await _loadStores();
    _refreshController.refreshCompleted();
  }

  List<StoreModel> get _filteredStores {
    var filtered = _stores;

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered
          .where((s) =>
              s.storeName.toLowerCase().contains(q) ||
              s.storeAddress.toLowerCase().contains(q))
          .toList();
    }

    // Apply chip filter
    switch (_activeFilter) {
      case 'Open Now':
        filtered = filtered.where((s) => s.isOpen).toList();
        break;
      case 'Free Delivery':
        filtered = filtered.where((s) => s.deliveryTime.contains('Free')).toList();
        break;
      case 'Top Rated':
        filtered = filtered.where((s) => s.rating >= 4.0).toList();
        filtered.sort((a, b) => b.rating.compareTo(a.rating));
        break;
    }

    return filtered;
  }

  Color get _categoryColor {
    if (_category != null) {
      return Color(AppConfig.getCategoryColor(_category!.slug));
    }
    return const Color(AppConfig.PRIMARY_COLOR);
  }

  @override
  Widget build(BuildContext context) {
    final filteredStores = _filteredStores;

    return Scaffold(
      backgroundColor: const Color(AppConfig.BACKGROUND_COLOR),
      appBar: AppBar(
        backgroundColor: _categoryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _category?.label ?? 'Stores',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.pushNamed(context, '/search', arguments: _category?.slug);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Search Bar ──
          Container(
            color: _categoryColor,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppConfig.RADIUS_XL),
              ),
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onSubmitted: (value) {
                  setState(() => _searchQuery = value);
                  _loadStores();
                },
                decoration: InputDecoration(
                  hintText: _category?.searchPlaceholder ?? 'Search stores...',
                  hintStyle: const TextStyle(
                    fontSize: 14,
                    color: Color(AppConfig.TEXT_HINT),
                  ),
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                            _loadStores();
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),

          // ── Filter Chips ──
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filterChips.map((chip) {
                  final isActive = _activeFilter == chip;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _activeFilter = chip);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isActive
                              ? _categoryColor
                              : const Color(AppConfig.BACKGROUND_COLOR),
                          borderRadius:
                              BorderRadius.circular(AppConfig.RADIUS_ROUND),
                          border: Border.all(
                            color: isActive
                                ? _categoryColor
                                : const Color(AppConfig.DIVIDER_COLOR),
                          ),
                        ),
                        child: Text(
                          chip,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isActive
                                ? Colors.white
                                : const Color(AppConfig.TEXT_SECONDARY),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // ── Store Grid ──
          Expanded(
            child: _isLoading
                ? const StoreGridShimmer()
                : _error != null
                    ? EmptyState.error(
                        message: _error,
                        onRetry: _loadStores,
                      )
                    : filteredStores.isEmpty
                        ? EmptyState.noStores(onRetry: _loadStores)
                        : SmartRefresher(
                            controller: _refreshController,
                            enablePullDown: true,
                            onRefresh: _onRefresh,
                            child: GridView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.all(16),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 0.68,
                              ),
                              itemCount: filteredStores.length +
                                  (_isLoadingMore ? 2 : 0),
                              itemBuilder: (context, index) {
                                if (index >= filteredStores.length) {
                                  return const StoreCardShimmer();
                                }
                                final store = filteredStores[index];
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
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
