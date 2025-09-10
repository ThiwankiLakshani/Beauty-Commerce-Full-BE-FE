// lib/features/categories/screens/category_listing_screen.dart
//


import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../app/app_constants.dart';
import '../../../common/utils/snackbar.dart';
import '../../../common/widgets/app_bar_primary.dart';
import '../../../common/widgets/empty_state.dart';
import '../../home/widgets/product_card.dart';
import '../../../common/widgets/text_field.dart';

class CategoryListingScreen extends StatefulWidget {
  const CategoryListingScreen({
    super.key,
    required this.categoryId,
    this.title,
    this.initialQuery,
    this.initialSort, // 'latest' | 'price' | '-price' | 'name' | '-name'
    this.perPage = 20,
  });

  /// Category ID from `/api/categories` (the "id" field).
  final String categoryId;

  /// Optional title for AppBar. If null, shows 'Category'.
  final String? title;

  /// Optional initial text search within this category.
  final String? initialQuery;

  /// Optional initial sort key (maps to backend sort).
  final String? initialSort;

  /// Page size (backend allows up to 100).
  final int perPage;

  @override
  State<CategoryListingScreen> createState() => _CategoryListingScreenState();
}

class _CategoryListingScreenState extends State<CategoryListingScreen> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  // Data
  final List<ProductCardItem> _items = [];

  // Loading flags
  bool _initialLoading = true;
  bool _loadingMore = false;
  bool _refreshing = false;
  bool _hasMore = true;
  String? _error;

  // Paging + filters
  int _page = 1;
  late String _sort; // backend sort param
  String get _query => _searchCtrl.text.trim();

  @override
  void initState() {
    super.initState();
    _sort = widget.initialSort ?? 'latest';
    if ((widget.initialQuery ?? '').isNotEmpty) {
      _searchCtrl.text = widget.initialQuery!;
    }
    _fetch(reset: true);
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Networking
  // ---------------------------------------------------------------------------

  String get _baseUrl {
    const fromEnv = String.fromEnvironment(Api.envBaseUrlKey, defaultValue: '');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (Platform.isIOS || Platform.isMacOS) {
      return Api.defaultBaseUrlIosSimulator; // http://localhost:5000
    }
    return Api.defaultBaseUrlAndroidEmulator; // http://10.0.2.2:5000
  }

  Future<void> _fetch({bool reset = false}) async {
    if (reset) {
      setState(() {
        _initialLoading = true;
        _loadingMore = false;
        _refreshing = false;
        _error = null;
        _items.clear();
        _page = 1;
        _hasMore = true;
      });
    }

    if (!_hasMore && !reset) return;

    final params = <String, String>{
      'category': widget.categoryId,
      'page': '$_page',
      'per_page': '${widget.perPage}',
    };

    final sortParam = _backendSortFromKey(_sort);
    if (sortParam != null && sortParam.isNotEmpty) {
      params['sort'] = sortParam;
    }
    if (_query.isNotEmpty) {
      params['q'] = _query;
    }

    final uri = Uri.parse('$_baseUrl${Api.products}')
        .replace(queryParameters: params);

    final client = HttpClient();

    try {
      if (reset) {
        // first load
        setState(() {
          _initialLoading = true;
          _error = null;
        });
      } else if (_refreshing) {
        // do nothing extra
      } else {
        setState(() {
          _loadingMore = true;
        });
      }

      final req = await client.getUrl(uri);
      req.headers.set('Accept', 'application/json');
      final resp = await req.close();

      final body = await resp.transform(utf8.decoder).join();

      if (!mounted) return;

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final map = (jsonDecode(body) as Map).cast<String, dynamic>();
        final list = (map['items'] as List? ?? [])
            .whereType<Map>()
            .map((m) => ProductCardItem.fromApi(m.cast<String, dynamic>()))
            .toList();

        setState(() {
          _items.addAll(list);
          _hasMore = list.length >= widget.perPage;
          _page += 1;
          _error = null;
        });
      } else {
        setState(() {
          _error = 'Failed to load products. Please try again.';
          _hasMore = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Network problem. Please check your connection.';
        _hasMore = false;
      });
    } finally {
      client.close(force: true);
      if (!mounted) return;
      setState(() {
        _initialLoading = false;
        _loadingMore = false;
        _refreshing = false;
      });
    }
  }

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    await _fetch(reset: true);
  }

  void _onScroll() {
    if (_loadingMore || _initialLoading || !_hasMore) return;
    if (!_scrollCtrl.hasClients) return;
    final max = _scrollCtrl.position.maxScrollExtent;
    final offset = _scrollCtrl.offset;
    if (max - offset < 180) {
      _fetch();
    }
  }

  // ---------------------------------------------------------------------------
  // UI actions
  // ---------------------------------------------------------------------------

  void _applySearch() => _fetch(reset: true);

  void _clearSearch() {
    _searchCtrl.clear();
    _fetch(reset: true);
  }

  void _onTapProduct(ProductCardItem p) {
    // Wire to product detail route when ready:
    // context.push('${Routes.product}/${p.id}');
    AppSnackbars.info(context, 'Product details coming soon', title: p.name);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Maps friendly keys to backend sort params.
  /// Keys: 'latest' | 'price' | '-price' | 'name' | '-name'
  String? _backendSortFromKey(String key) {
    switch (key) {
      case 'price':
        return 'price';
      case '-price':
        return '-price';
      case 'name':
        return 'name';
      case '-name':
        return '-name';
      case 'latest':
      default:
        // Backend default is -created_at, we can omit sort param.
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = widget.title ?? 'Category';

    return Scaffold(
      appBar: AppBarPrimary(title: title),
      body: SafeArea(
        child: Column(
          children: [
            // Search + Sort Row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  // Search field
                  Expanded(
                    child: AppTextField.search(
                      controller: _searchCtrl,
                      hint: 'Search in $title',
                      onSubmitted: (_) => _applySearch(),
                      showClearButton: true,
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Sort dropdown
                  _SortButton(
                    value: _sort,
                    onChanged: (v) {
                      setState(() => _sort = v);
                      _fetch(reset: true);
                    },
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                color: theme.colorScheme.primary,
                child: _buildBody(theme),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    final cs = theme.colorScheme;

    if (_initialLoading) {
      return ListView(
        controller: _scrollCtrl,
        padding: const EdgeInsets.all(16),
        children: const [
          _GridSkeleton(),
        ],
      );
    }

    if (_error != null && _items.isEmpty) {
      return ListView(
        controller: _scrollCtrl,
        padding: const EdgeInsets.all(16),
        children: [
          EmptyState(
            icon: Icons.storefront_rounded,
            title: 'Can’t load products',
            message: _error,
            primaryActionLabel: 'Retry',
            onPrimaryAction: () => _fetch(reset: true),
          ),
        ],
      );
    }

    if (_items.isEmpty) {
      return ListView(
        controller: _scrollCtrl,
        padding: const EdgeInsets.all(16),
        children: [
          EmptyState(
            icon: Icons.inbox_rounded,
            title: 'No products found',
            message:
                _query.isEmpty ? 'This category is empty.' : 'Try a different search.',
            primaryActionLabel: _query.isNotEmpty ? 'Clear search' : 'Refresh',
            onPrimaryAction: _query.isNotEmpty ? _clearSearch : () => _fetch(reset: true),
          ),
        ],
      );
    }

    return CustomScrollView(
      controller: _scrollCtrl,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final item = _items[index];
                return ProductCard(
                  item: item,
                  onTap: () => _onTapProduct(item),
                );
              },
              childCount: _items.length,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.68,
            ),
          ),
        ),

        // Loading more indicator
        SliverToBoxAdapter(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _loadingMore
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: cs.primary,
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Sort button (Dropdown)
// -----------------------------------------------------------------------------

class _SortButton extends StatelessWidget {
  const _SortButton({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    const entries = <DropdownMenuItem<String>>[
      DropdownMenuItem(value: 'latest', child: Text('Latest')),
      DropdownMenuItem(value: 'price', child: Text('Price: Low to High')),
      DropdownMenuItem(value: '-price', child: Text('Price: High to Low')),
      DropdownMenuItem(value: 'name', child: Text('Name: A → Z')),
      DropdownMenuItem(value: '-name', child: Text('Name: Z → A')),
    ];

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: theme.inputDecorationTheme.fillColor ?? cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          items: entries,
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
          borderRadius: BorderRadius.circular(12),
          icon: const Icon(Icons.expand_more_rounded),
          style: theme.textTheme.bodyMedium,
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Skeleton grid
// -----------------------------------------------------------------------------

class _GridSkeleton extends StatelessWidget {
  const _GridSkeleton();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: 6,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.68,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
      ),
      itemBuilder: (_, __) {
        return Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image placeholder
              Container(
                height: 160,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14),
                    topRight: Radius.circular(14),
                  ),
                ),
              ),
              // Lines
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: [
                    _bar(cs, width: 120, height: 12),
                    const SizedBox(height: 8),
                    _bar(cs, width: 80, height: 12),
                    const SizedBox(height: 14),
                    _bar(cs, width: 60, height: 14),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _bar(ColorScheme cs, {double width = 100, double height = 12}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}
