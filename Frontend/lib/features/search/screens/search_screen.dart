// lib/features/search/screens/search_results_screen.dart
//

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../app/app_constants.dart';
import '../../../common/widgets/app_bar_primary.dart';
import '../../../common/widgets/empty_state.dart';
import '../../../common/widgets/text_field.dart';
import '../../home/widgets/product_card.dart';
import '../../categories/widgets/filter_sheet.dart';

class SearchResultsScreen extends StatefulWidget {
  const SearchResultsScreen({
    super.key,
    required this.initialQuery,
    this.initialFilters = CategoryFilters.empty,
    this.title,
  });

  /// Query to start with when the screen opens.
  final String initialQuery;

  /// Optional initial filters (maps to backend supported params).
  final CategoryFilters initialFilters;

  /// Optional title; defaults to 'Search results'.
  final String? title;

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  // Controllers
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  // Debounce for typing
  Timer? _debounce;

  // Results
  final List<ProductCardItem> _items = [];

  // Loading flags
  bool _initialLoading = false; // true during first fetch
  bool _loadingMore = false;
  bool _refreshing = false;
  bool _hasMore = true;
  String? _error;

  // Paging + filters + sort
  int _page = 1;
  final int _perPage = 20;
  String _sortKey = 'latest'; // 'latest' | 'price' | '-price' | 'name' | '-name'
  late CategoryFilters _filters;

  // Filter metadata
  bool _loadingFilterData = false;
  List<String> _itemTypes = const [];
  List<KeyLabel> _skinTypes = const [];
  List<KeyLabel> _concerns = const [];

  // Request token to drop stale responses
  int _reqCounter = 0;

  @override
  void initState() {
    super.initState();
    _filters = widget.initialFilters;
    _searchCtrl.text = widget.initialQuery;
    _scrollCtrl.addListener(_onScroll);
    _searchCtrl.addListener(_onQueryChanged);
    _loadFilterMetadata();

    // Kick off initial search after first frame to avoid init races
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _fetch(reset: true);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollCtrl.dispose();
    _searchCtrl.removeListener(_onQueryChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Base URL
  // ---------------------------------------------------------------------------

  String get _baseUrl {
    const fromEnv = String.fromEnvironment(Api.envBaseUrlKey, defaultValue: '');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (Platform.isIOS || Platform.isMacOS) {
      return Api.defaultBaseUrlIosSimulator; // http://localhost:5000
    }
    return Api.defaultBaseUrlAndroidEmulator; // http://10.0.2.2:5000
  }

  // ---------------------------------------------------------------------------
  // Networking: Search
  // ---------------------------------------------------------------------------

  Future<void> _fetch({bool reset = false}) async {
    final q = _searchCtrl.text.trim();
    final int rid = ++_reqCounter; // capture request id for this call

    if (q.isEmpty) {
      setState(() {
        _items.clear();
        _error = null;
        _initialLoading = false;
        _loadingMore = false;
        _refreshing = false;
        _hasMore = true;
        _page = 1;
      });
      return;
    }

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
      'q': q,
      'page': '$_page',
      'per_page': '$_perPage',
    };

    final sortParam = _backendSortFromKey(_sortKey);
    if (sortParam != null && sortParam.isNotEmpty) {
      params['sort'] = sortParam;
    }

    // Backend-supported filters — strip empties so "clear filters" truly clears
    final fq = Map<String, String>.from(_filters.toQuery());
    fq.removeWhere((_, v) => v.trim().isEmpty);
    if (fq.isNotEmpty) {
      params.addAll(fq);
    }

    final uri = Uri.parse('$_baseUrl${Api.products}').replace(
      queryParameters: params,
    );

    final client = HttpClient();

    try {
      if (!reset && !_refreshing) {
        if (mounted) setState(() => _loadingMore = true);
      }

      final req = await client.getUrl(uri);
      req.headers.set('Accept', 'application/json');
      final resp = await req.close();
      final body = await resp.transform(utf8.decoder).join();

      if (!mounted || rid != _reqCounter) return; // ignore stale responses

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final map = (jsonDecode(body) as Map).cast<String, dynamic>();
        final list = (map['items'] as List? ?? [])
            .whereType<Map>()
            .map((m) => ProductCardItem.fromApi(m.cast<String, dynamic>()))
            .toList();

        setState(() {
          _items.addAll(list);
          _hasMore = list.length >= _perPage;
          _page += 1;
          _error = null;
        });
      } else {
        setState(() {
          _error = 'Search failed. Please try again.';
          _hasMore = false;
        });
      }
    } catch (_) {
      if (!mounted || rid != _reqCounter) return; // also guard in error path
      setState(() {
        _error = 'Network problem. Please check your connection.';
        _hasMore = false;
      });
    } finally {
      client.close(force: true);
      if (!mounted || rid != _reqCounter) return; // guard in finally
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

  // ---------------------------------------------------------------------------
  // Networking: Filter metadata
  // ---------------------------------------------------------------------------

  Future<void> _loadFilterMetadata() async {
    setState(() => _loadingFilterData = true);

    final client = HttpClient();

    try {
      // Categories -> unique item_types
      final catsUri = Uri.parse('$_baseUrl${Api.categories}');
      final catsReq = await client.getUrl(catsUri);
      catsReq.headers.set('Accept', 'application/json');
      final catsResp = await catsReq.close();
      final catsBody = await catsResp.transform(utf8.decoder).join();

      final types = <String>{};
      if (catsResp.statusCode >= 200 && catsResp.statusCode < 300) {
        final map = (jsonDecode(catsBody) as Map).cast<String, dynamic>();
        final items = (map['items'] as List? ?? []).whereType<Map>();
        for (final m in items) {
          final list = m['item_types'];
          if (list is List) {
            for (final t in list) {
              if (t is String && t.trim().isNotEmpty) types.add(t);
            }
          }
        }
      }

      // Attributes -> skin_types, concerns
      final attrsUri = Uri.parse('$_baseUrl${Api.attributes}');
      final attrsReq = await client.getUrl(attrsUri);
      attrsReq.headers.set('Accept', 'application/json');
      final attrsResp = await attrsReq.close();
      final attrsBody = await attrsResp.transform(utf8.decoder).join();

      final skin = <KeyLabel>[];
      final cons = <KeyLabel>[];

      if (attrsResp.statusCode >= 200 && attrsResp.statusCode < 300) {
        final map = (jsonDecode(attrsBody) as Map).cast<String, dynamic>();

        final sk = map['skin_types'];
        if (sk is List) {
          for (final v in sk) {
            if (v is Map) {
              final key = (v['key'] ?? '').toString();
              final label = (v['label'] ?? '').toString();
              if (key.isNotEmpty && label.isNotEmpty) {
                skin.add(KeyLabel(key: key, label: label));
              }
            }
          }
        }

        final co = map['concerns'];
        if (co is List) {
          for (final v in co) {
            if (v is Map) {
              final key = (v['key'] ?? '').toString();
              final label = (v['label'] ?? '').toString();
              if (key.isNotEmpty && label.isNotEmpty) {
                cons.add(KeyLabel(key: key, label: label));
              }
            }
          }
        }
      }

      if (!mounted) return;

      setState(() {
        _itemTypes = types.toList()..sort();
        _skinTypes = skin;
        _concerns = cons;
        _loadingFilterData = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingFilterData = false;
      });
    } finally {
      client.close(force: true);
    }
  }

  // ---------------------------------------------------------------------------
  // Handlers
  // ---------------------------------------------------------------------------

  void _onQueryChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 420), () {
      _fetch(reset: true);
    });
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

  void _openFilters() async {
    if (_loadingFilterData) {
      return;
    }
    final result = await showCategoryFilterSheet(
      context,
      initial: _filters,
      itemTypes: _itemTypes,
      skinTypes: _skinTypes,
      concerns: _concerns,
    );
    if (!mounted) return;

    // Treat null (sheet dismissed / clear button) or empty filters as "clear".
    if (result == null || result.isEmpty) {
      if (!_filters.isEmpty) {
        setState(() => _filters = CategoryFilters.empty);
        _fetch(reset: true);
      }
      return;
    }

    setState(() => _filters = result);
    _fetch(reset: true);
  }

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
        return null; // backend default (-created_at)
    }
  }

  void _onTapProduct(ProductCardItem p) {
    // Navigate to product details; expects a named route like `/product/:id`.
    Navigator.of(context).pushNamed('/product/${p.id}', arguments: p);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final title = widget.title ?? 'Search results';

    return Scaffold(
      appBar: AppBarPrimary(
        title: title,
        actions: [
          IconButton(
            tooltip: 'Filters',
            onPressed: _openFilters,
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search + sort + filter buttons row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: AppTextField.search(
                      controller: _searchCtrl,
                      hint: 'Search products',
                      showClearButton: true,
                      onSubmitted: (_) => _fetch(reset: true),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _SortButton(
                    value: _sortKey,
                    onChanged: (v) {
                      setState(() => _sortKey = v);
                      _fetch(reset: true);
                    },
                  ),
                  const SizedBox(width: 10),
                  _FilterButton(
                    loading: _loadingFilterData,
                    hasActive: !_filters.isEmpty,
                    onPressed: _openFilters,
                  ),
                ],
              ),
            ),

            // Results
            Expanded(
              child: RefreshIndicator(
                color: cs.primary,
                onRefresh: _refresh,
                child: _buildBody(theme),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_searchCtrl.text.trim().isEmpty) {
      return ListView(
        controller: _scrollCtrl,
        padding: const EdgeInsets.all(16),
        children: const [
          EmptyState(
            icon: Icons.search_rounded,
            title: 'Start typing to search',
            message: 'Find products by name, brand or keywords.',
          ),
        ],
      );
    }

    if (_initialLoading) {
      // Keep scrollable to support RefreshIndicator
      return ListView(
        controller: _scrollCtrl,
        padding: const EdgeInsets.symmetric(vertical: 32),
        children: const [
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    if (_error != null && _items.isEmpty) {
      return ListView(
        controller: _scrollCtrl,
        padding: const EdgeInsets.all(16),
        children: [
          EmptyState(
            icon: Icons.search_off_rounded,
            title: 'Search error',
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
          const SizedBox(height: 8),
          EmptyState(
            icon: Icons.inbox_rounded,
            title: 'No results',
            message: 'Try a different keyword or adjust filters.',
            primaryActionLabel: 'Clear filters',
            onPrimaryAction: () {
              setState(() => _filters = CategoryFilters.empty);
              _fetch(reset: true);
            },
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

        // Loading more
        SliverToBoxAdapter(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _loadingMore
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(strokeWidth: 2),
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
// Sort control
// -----------------------------------------------------------------------------

class _SortButton extends StatelessWidget {
  const _SortButton({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    const items = <DropdownMenuItem<String>>[
      DropdownMenuItem(value: 'latest', child: Text('Latest')),
      DropdownMenuItem(value: 'price', child: Text('Price: Low → High')),
      DropdownMenuItem(value: '-price', child: Text('Price: High → Low')),
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
          items: items,
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
          borderRadius: BorderRadius.circular(12),
          icon: const Icon(Icons.sort_rounded),
          style: theme.textTheme.bodyMedium,
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Filter button (with active indicator)
// -----------------------------------------------------------------------------

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.loading,
    required this.hasActive,
    required this.onPressed,
  });

  final bool loading;
  final bool hasActive;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(
          height: 48,
          width: 48,
          child: OutlinedButton(
            onPressed: loading ? null : onPressed,
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.tune_rounded),
          ),
        ),
        if (hasActive)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: cs.primary,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: cs.surface, width: 1.5),
              ),
            ),
          ),
      ],
    );
  }
}
