// lib/features/home/screens/home_screen.dart
//

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_constants.dart';
import '../../../common/utils/formatters.dart';
import '../../../common/widgets/app_bar_primary.dart';
import '../../../common/widgets/empty_state.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.accessToken,
  });

  /// Optional JWT token (only used if your `/api/home` requires auth).
  final String? accessToken;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _loading = true;
  String? _error;

  late List<ProductItem> _newArrivals = [];
  late List<ProductItem> _topRated = [];
  late List<ProductItem> _budgetPicks = [];

  @override
  void initState() {
    super.initState();
    _fetchHome();
  }

  String get _baseUrl {
    const fromEnv = String.fromEnvironment(Api.envBaseUrlKey, defaultValue: '');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (Platform.isIOS || Platform.isMacOS) {
      return Api.defaultBaseUrlIosSimulator; // http://localhost:5000
    }
    return Api.defaultBaseUrlAndroidEmulator; // http://10.0.2.2:5000
  }

  Future<void> _fetchHome() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final uri = Uri.parse('$_baseUrl${Api.home}');
    final client = HttpClient();

    try {
      final req = await client.getUrl(uri);
      req.headers.set('Accept', 'application/json');
      final token = (widget.accessToken ?? '').trim();
      if (token.isNotEmpty) {
        req.headers.set('Authorization', 'Bearer $token');
      }
      final resp = await req.close();

      final body = await resp.transform(utf8.decoder).join();

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final map = (jsonDecode(body) as Map).cast<String, dynamic>();

        List<ProductItem> _parseList(String key) {
          final raw = map[key];
          if (raw is List) {
            return raw
                .whereType<Map>()
                .map((m) => ProductItem.fromJson(m.cast<String, dynamic>()))
                .toList();
          }
          return [];
        }

        setState(() {
          _newArrivals = _parseList('new_arrivals');
          _topRated = _parseList('top_rated');
          _budgetPicks = _parseList('budget_picks');
          _loading = false;
          _error = null;
        });
      } else {
        setState(() {
          _error = 'Could not load home feed. Try again.';
          _loading = false;
        });
      }
    } catch (_) {
      setState(() {
        _error = 'Network problem. Please check your connection.';
        _loading = false;
      });
    } finally {
      client.close(force: true);
    }
  }

  void _onTapProduct(ProductItem p) {
    // Navigate to product details using route NAME and path parameter.
    context.pushNamed(
      'product_detail',
      pathParameters: {'idOrSlug': p.id},
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBarPrimary(
        title: AppInfo.appName,
        actions: [
          IconButton(
            tooltip: 'Search',
            onPressed: () => context.pushNamed('search'),
            icon: const Icon(Icons.search_rounded),
          ),
          IconButton(
            tooltip: 'Cart',
            onPressed: () => context.pushNamed('cart'),
            icon: const Icon(Icons.shopping_cart_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchHome,
        color: cs.primary,
        child: _buildBody(theme),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_loading) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _SectionSkeleton(title: 'New arrivals'),
          SizedBox(height: 16),
          _SectionSkeleton(title: 'Top rated'),
          SizedBox(height: 16),
          _SectionSkeleton(title: 'Budget picks'),
        ],
      );
    }

    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          EmptyState(
            icon: Icons.wifi_off_rounded,
            title: 'Can’t load home',
            message: _error,
            primaryActionLabel: 'Retry',
            onPrimaryAction: _fetchHome,
          ),
        ],
      );
    }

    final sections = <Widget>[];

    if (_newArrivals.isNotEmpty) {
      sections.add(_ProductSection(
        title: 'New arrivals',
        products: _newArrivals,
        onTap: _onTapProduct,
        onSeeAll: () => context.pushNamed('discover'),
      ));
      sections.add(const SizedBox(height: 16));
    }

    if (_topRated.isNotEmpty) {
      sections.add(_ProductSection(
        title: 'Top rated',
        products: _topRated,
        onTap: _onTapProduct,
        onSeeAll: () => context.pushNamed('discover'),
      ));
      sections.add(const SizedBox(height: 16));
    }

    if (_budgetPicks.isNotEmpty) {
      sections.add(_ProductSection(
        title: 'Budget picks',
        products: _budgetPicks,
        onTap: _onTapProduct,
        onSeeAll: () => context.pushNamed('discover'),
      ));
      sections.add(const SizedBox(height: 16));
    }

    if (sections.isEmpty) {
      sections.add(
        EmptyState(
          icon: Icons.inbox_rounded,
          title: 'Nothing here yet',
          message: 'No products available. Please check back later.',
          primaryActionLabel: 'Refresh',
          onPrimaryAction: _fetchHome,
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      children: sections,
    );
  }
}

// =============================================================================
// Data model
// =============================================================================

class ProductItem {
  final String id;
  final String name;
  final String? brand;
  final double price;
  final String currency;
  final String? heroImage;

  const ProductItem({
    required this.id,
    required this.name,
    this.brand,
    required this.price,
    required this.currency,
    this.heroImage,
  });

  factory ProductItem.fromJson(Map<String, dynamic> json) {
    return ProductItem(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      brand: (json['brand'] as String?)?.toString(),
      price: _toDouble(json['price']),
      currency: (json['currency'] ?? AppInfo.defaultCurrency).toString(),
      heroImage: (json['hero_image'] as String?)?.toString(),
    );
  }

  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }
}

// =============================================================================
// UI widgets
// =============================================================================

class _ProductSection extends StatelessWidget {
  const _ProductSection({
    required this.title,
    required this.products,
    required this.onTap,
    required this.onSeeAll,
  });

  final String title;
  final List<ProductItem> products;
  final void Function(ProductItem) onTap;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title row
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
          child: Row(
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: onSeeAll,
                child: const Text('See all'),
              ),
            ],
          ),
        ),

        // Horizontal product list
        SizedBox(
          height: 250,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            itemCount: products.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final p = products[i];
              return _ProductCard(
                product: p,
                onTap: () => onTap(p),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.onTap,
  });

  final ProductItem product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Ink(
        width: 160,
        decoration: BoxDecoration(
          color: theme.cardTheme.color ?? theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
              child: AspectRatio(
                aspectRatio: 1,
                child: (product.heroImage == null || product.heroImage!.isEmpty)
                    ? const _ImagePlaceholder(icon: Icons.image_outlined)
                    : Image.network(
                        product.heroImage!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const _ImagePlaceholder(icon: Icons.broken_image),
                        loadingBuilder: (ctx, child, progress) {
                          if (progress == null) return child;
                          return const _ImagePlaceholder(
                            icon: Icons.photo_library_outlined,
                          );
                        },
                      ),
              ),
            ),

            // Details
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    // Price
                    Text(
                      Formatters.price(product.price, currency: product.currency),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.surfaceContainerHighest,
      child: Icon(icon, color: cs.onSurfaceVariant),
    );
  }
}

class _SectionSkeleton extends StatelessWidget {
  const _SectionSkeleton({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
        // Row of placeholders
        SizedBox(
          height: 250,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4),
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
                    // image box
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
                    // lines
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        children: [
                          _shimmerBar(cs, width: 120),
                          const SizedBox(height: 8),
                          _shimmerBar(cs, width: 80),
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
    );
  }

  Widget _shimmerBar(ColorScheme cs, {double width = 100}) {
    return Container(
      width: width,
      height: 12,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}
