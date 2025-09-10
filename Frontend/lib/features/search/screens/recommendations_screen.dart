// lib/features/search/screens/recommendations_screen.dart
//


import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../app/app_constants.dart';
import '../../../common/utils/snackbar.dart';
import '../../../common/widgets/app_bar_primary.dart';
import '../../../common/widgets/empty_state.dart';
import '../../home/widgets/product_carousel.dart';

class RecommendationsScreen extends StatefulWidget {
  const RecommendationsScreen({super.key});

  @override
  State<RecommendationsScreen> createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen> {
  bool _loading = true;
  String? _error;

  bool _personalized = false;
  List<ProductCarouselItem> _forYou = [];
  List<ProductCarouselItem> _newArrivals = [];
  List<ProductCarouselItem> _topRated = [];

  String get _baseUrl {
    const fromEnv = String.fromEnvironment(Api.envBaseUrlKey, defaultValue: '');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (Platform.isIOS || Platform.isMacOS) {
      return Api.defaultBaseUrlIosSimulator; // http://localhost:5000
    }
    return Api.defaultBaseUrlAndroidEmulator; // http://10.0.2.2:5000
  }

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
      _personalized = false;
      _forYou = [];
      _newArrivals = [];
      _topRated = [];
    });

    final client = HttpClient();
    try {
      final uri = Uri.parse('$_baseUrl${Api.recommendations}');
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
          _loading = false;
        });
      } else {
        setState(() {
          _loading = false;
          _error = 'Could not load recommendations.';
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Network problem. Please check your connection.';
      });
    } finally {
      client.close(force: true);
    }
  }

  void _onTapItem(ProductCarouselItem p) {
    // Wire to product detail route when ready:
    // context.push('${Routes.product}/${p.id}');
    AppSnackbars.info(context, 'Product details coming soon', title: p.name);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: const AppBarPrimary(title: 'Recommendations'),
      body: RefreshIndicator(
        color: cs.primary,
        onRefresh: _fetch,
        child: CustomScrollView(
          slivers: [
            if (_loading)
              const SliverToBoxAdapter(child: _RecsSkeleton())
            else if (_error != null)
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverToBoxAdapter(
                  child: EmptyState(
                    icon: Icons.recommend_outlined,
                    title: 'Can’t load recommendations',
                    message: _error,
                    primaryActionLabel: 'Retry',
                    onPrimaryAction: _fetch,
                  ),
                ),
              )
            else ..._buildContent(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildContent() {
    final widgets = <Widget>[];

    if (_personalized) {
      if (_forYou.isNotEmpty) {
        widgets.add(
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ProductCarousel(
                title: 'For you',
                items: _forYou,
                onTapItem: _onTapItem,
                onSeeAll: () => AppSnackbars.info(context, 'Personalized list coming soon'),
              ),
            ),
          ),
        );
      }
    } else {
      if (_newArrivals.isNotEmpty) {
        widgets.add(
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ProductCarousel(
                title: 'New arrivals',
                items: _newArrivals,
                onTapItem: _onTapItem,
                onSeeAll: () => AppSnackbars.info(context, 'New arrivals coming soon'),
              ),
            ),
          ),
        );
      }
      if (_topRated.isNotEmpty) {
        widgets.add(
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ProductCarousel(
                title: 'Top rated',
                items: _topRated,
                onTapItem: _onTapItem,
                onSeeAll: () => AppSnackbars.info(context, 'Top rated coming soon'),
              ),
            ),
          ),
        );
      }
    }

    if (widgets.isEmpty) {
      widgets.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: EmptyState(
              icon: Icons.explore_outlined,
              title: 'No suggestions',
              message: 'Try refreshing or searching for products you like.',
              primaryActionLabel: 'Refresh',
              onPrimaryAction: _fetch,
            ),
          ),
        ),
      );
    }

    return widgets;
  }
}

// -----------------------------------------------------------------------------
// Skeleton
// -----------------------------------------------------------------------------

class _RecsSkeleton extends StatelessWidget {
  const _RecsSkeleton();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: List.generate(2, (i) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                // Title placeholder
                Container(
                  width: 160,
                  height: 18,
                  margin: const EdgeInsets.fromLTRB(4, 4, 4, 12),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                // Horizontal item placeholders
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
