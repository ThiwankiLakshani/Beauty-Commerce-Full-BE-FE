// lib/features/search/screens/discover_screen.dart
//


import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_constants.dart';
import '../../../common/widgets/app_bar_primary.dart';
import '../../../common/widgets/empty_state.dart';
import '../../../common/widgets/text_field.dart';
import '../../home/widgets/product_card.dart';
import '../../home/widgets/product_carousel.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  // --- Recommendations state ---
  bool _loadingRecs = true;
  String? _recsError;
  bool _personalized = false;
  List<ProductCarouselItem> _forYou = [];
  List<ProductCarouselItem> _newArrivals = [];
  List<ProductCarouselItem> _topRated = [];

  // --- Search state ---
  bool _searching = false;
  String? _searchError;
  List<ProductCardItem> _results = [];

  @override
  void initState() {
    super.initState();
    _fetchRecommendations();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  String get _baseUrl {
    const fromEnv = String.fromEnvironment(Api.envBaseUrlKey, defaultValue: '');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (Platform.isIOS || Platform.isMacOS) {
      return Api.defaultBaseUrlIosSimulator; // http://localhost:5000
    }
    return Api.defaultBaseUrlAndroidEmulator; // http://10.0.2.2:5000
  }

  // =============================================================================
  // Networking
  // =============================================================================

  Future<void> _fetchRecommendations() async {
    setState(() {
      _loadingRecs = true;
      _recsError = null;
      _personalized = false;
      _forYou.clear();
      _newArrivals.clear();
      _topRated.clear();
    });

    final uri = Uri.parse('$_baseUrl${Api.recommendations}');
    final client = HttpClient();

    try {
      final req = await client.getUrl(uri);
      req.headers.set('Accept', 'application/json');
      final resp = await req.close();
      final body = await resp.transform(utf8.decoder).join();

      if (!mounted) return;

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final map = (jsonDecode(body) as Map).cast<String, dynamic>();
        final personalized = (map['personalized'] == true);

        List<ProductCarouselItem> _parseCarList(dynamic v) {
          if (v is List) {
            return v
                .whereType<Map>()
                .map((m) => ProductCarouselItem.fromApi(m.cast<String, dynamic>()))
                .toList();
          }
          return [];
        }

        setState(() {
          _personalized = personalized;
          if (personalized) {
            _forYou = _parseCarList(map['items']);
          } else {
            _newArrivals = _parseCarList(map['new_arrivals']);
            _topRated = _parseCarList(map['top_rated']);
          }
          _loadingRecs = false;
          _recsError = null;
        });
      } else {
        setState(() {
          _recsError = 'Could not load recommendations.';
          _loadingRecs = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _recsError = 'Network problem. Please check your connection.';
        _loadingRecs = false;
      });
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _results.clear();
        _searchError = null;
        _searching = false;
      });
      return;
    }

    setState(() {
      _searching = true;
      _searchError = null;
    });

    final uri = Uri.parse('$_baseUrl${Api.search}')
        .replace(queryParameters: {'q': query.trim()});
    final client = HttpClient();

    try {
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
          _results = list;
          _searching = false;
        });
      } else {
        setState(() {
          _results = [];
          _searchError = 'Search failed. Please try again.';
          _searching = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _results = [];
        _searchError = 'Network problem. Please check your connection.';
        _searching = false;
      });
    } finally {
      client.close(force: true);
    }
  }

  // =============================================================================
  // Search handling
  // =============================================================================

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 420), () {
      _performSearch(_searchCtrl.text);
    });
  }

  Future<void> _onRefresh() async {
    if (_searchCtrl.text.trim().isNotEmpty) {
      await _performSearch(_searchCtrl.text);
    } else {
      await _fetchRecommendations();
    }
  }

  // =============================================================================
  // UI helpers
  // =============================================================================

  void _onTapProductCard(ProductCardItem p) {
    // go_router path style: /product/:id
    context.push('/product/${p.id}', extra: p);
  }

  void _onTapCarouselItem(ProductCarouselItem p) {
    context.push('/product/${p.id}', extra: p);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBarPrimary(
        title: 'Discover',
        actions: [
          IconButton(
            tooltip: 'Cart',
            onPressed: () => context.push('/cart'),
            icon: const Icon(Icons.shopping_cart_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: cs.primary,
        onRefresh: _onRefresh,
        child: CustomScrollView(
          slivers: [
            // Search bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: AppTextField.search(
                  controller: _searchCtrl,
                  hint: 'Search products',
                  showClearButton: true,
                  onSubmitted: (q) => _performSearch(q ?? ''),
                ),
              ),
            ),

            // Content changes based on whether there is a query
            if (_searchCtrl.text.trim().isEmpty)
              ..._buildRecommendSlivers()
            else
              ..._buildSearchSlivers(),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Recommendations view
  // ---------------------------------------------------------------------------

  List<Widget> _buildRecommendSlivers() {
    if (_loadingRecs) {
      return const [
        SliverToBoxAdapter(child: _RecsSkeleton()),
      ];
    }

    if (_recsError != null) {
      return [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverToBoxAdapter(
            child: EmptyState(
              icon: Icons.recommend_outlined,
              title: 'Can’t load recommendations',
              message: _recsError,
              primaryActionLabel: 'Retry',
              onPrimaryAction: _fetchRecommendations,
            ),
          ),
        ),
      ];
    }

    final slivers = <Widget>[];

    if (_personalized && _forYou.isNotEmpty) {
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ProductCarousel(
              title: 'For you',
              items: _forYou,
              onTapItem: _onTapCarouselItem,
              // Intentionally omit onSeeAll navigation until a dedicated route exists.
            ),
          ),
        ),
      );
    } else {
      if (_newArrivals.isNotEmpty) {
        slivers.add(
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ProductCarousel(
                title: 'New arrivals',
                items: _newArrivals,
                onTapItem: _onTapCarouselItem,
              ),
            ),
          ),
        );
      }
      if (_topRated.isNotEmpty) {
        slivers.add(
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ProductCarousel(
                title: 'Top rated',
                items: _topRated,
                onTapItem: _onTapCarouselItem,
              ),
            ),
          ),
        );
      }
    }

    if (slivers.isEmpty) {
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: EmptyState(
              icon: Icons.explore_outlined,
              title: 'No suggestions yet',
              message: 'Try searching for products or refreshing.',
              primaryActionLabel: 'Refresh',
              onPrimaryAction: _fetchRecommendations,
            ),
          ),
        ),
      );
    }

    return slivers;
  }

  // ---------------------------------------------------------------------------
  // Search results view
  // ---------------------------------------------------------------------------

  List<Widget> _buildSearchSlivers() {
    if (_searching) {
      return const [
        SliverToBoxAdapter(child: _SearchSkeleton()),
      ];
    }

    if (_searchError != null && _results.isEmpty) {
      return [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverToBoxAdapter(
            child: EmptyState(
              icon: Icons.search_off_rounded,
              title: 'Search error',
              message: _searchError,
              primaryActionLabel: 'Retry',
              onPrimaryAction: () => _performSearch(_searchCtrl.text),
            ),
          ),
        ),
      ];
    }

    if (_results.isEmpty) {
      return [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverToBoxAdapter(
            child: EmptyState(
              icon: Icons.inbox_rounded,
              title: 'No results',
              message: 'Try a different keyword.',
              primaryActionLabel: 'Clear search',
              onPrimaryAction: () {
                _searchCtrl.clear();
              },
            ),
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        sliver: SliverGrid(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final item = _results[index];
              return ProductCard(
                item: item,
                onTap: () => _onTapProductCard(item),
              );
            },
            childCount: _results.length,
          ),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.68,
          ),
        ),
      ),
    ];
  }
}

// =============================================================================
// Skeletons
// =============================================================================

class _RecsSkeleton extends StatelessWidget {
  const _RecsSkeleton();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: List.generate(2, (section) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                // Title bar
                Container(
                  width: 160,
                  height: 18,
                  margin: const EdgeInsets.fromLTRB(4, 4, 4, 12),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                // Horizontal list
                SizedBox(
                  height: 250,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: 4,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (_, __) {
                      return Container(
                        width: 160,
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: cs.outlineVariant),
                        ),
                        child: Column(
                          children: [
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
                            Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                children: [
                                  _bar(cs, 120, 12),
                                  const SizedBox(height: 8),
                                  _bar(cs, 80, 12),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _bar(ColorScheme cs, double w, double h) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}

class _SearchSkeleton extends StatelessWidget {
  const _SearchSkeleton();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
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
              children: [
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
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    children: [
                      _bar(cs, 120, 12),
                      const SizedBox(height: 8),
                      _bar(cs, 80, 12),
                      const SizedBox(height: 14),
                      _bar(cs, 60, 14),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _bar(ColorScheme cs, double w, double h) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}
