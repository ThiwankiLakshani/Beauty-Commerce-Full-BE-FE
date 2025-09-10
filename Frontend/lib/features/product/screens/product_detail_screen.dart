// lib/features/product/screens/product_detail_screen.dart
//

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_constants.dart';
import '../../../common/utils/snackbar.dart';
import '../../../common/widgets/app_bar_primary.dart';
import '../../../common/widgets/empty_state.dart';
import '../../../common/widgets/primary_button.dart';
import '../../home/widgets/product_carousel.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({
    super.key,
    required this.idOrSlug,
    this.accessToken,
  });

  /// Backend accepts either the product's ID or its slug.
  final String idOrSlug;

  /// Optional JWT access token (used for /api/cart, wishlist and protected images).
  final String? accessToken;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  bool _loading = true;
  String? _error;
  ProductDetail? _product;

  int _imageIndex = 0;
  int _qty = 1;

  bool _loadingRelated = false;
  List<ProductCarouselItem> _related = const [];

  bool _loadingReviews = false;
  List<ReviewItem> _reviews = const [];

  // Wishlist local state
  bool _wishLoading = false;
  bool _inWishlist = false; // set via GET /api/wishlist and live toggles

  String get _baseUrl {
    const fromEnv = String.fromEnvironment(Api.envBaseUrlKey, defaultValue: '');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (Platform.isIOS || Platform.isMacOS) {
      return Api.defaultBaseUrlIosSimulator; // http://localhost:5000
    }
    return Api.defaultBaseUrlAndroidEmulator; // http://10.0.2.2:5000
  }

  Map<String, String>? get _imageHeaders {
    final t = (widget.accessToken ?? '').trim();
    if (t.isEmpty) return null;
    return {'Authorization': 'Bearer $t'};
  }

  // Local currency formatter (simple).
  String _formatCurrency(double amount, {String currency = 'LKR'}) {
    final txt = amount.toStringAsFixed(2);
    return '$currency $txt';
  }

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  Future<void> _fetchAll() async {
    await _fetchDetail();
    if (!mounted) return;
    if (_product != null) {
      // load membership in wishlist for this product
      await _loadWishlistState(_product!.id);
      await Future.wait([
        _fetchRelated(_product!.id),
        _fetchReviews(_product!.id),
      ]);
    }
  }

  Future<void> _fetchDetail() async {
    setState(() {
      _loading = true;
      _error = null;
      _product = null;
      _imageIndex = 0;
      _qty = 1;
      _wishLoading = false;
      _inWishlist = false;
    });

    final client = HttpClient();
    try {
      final uri = Uri.parse('$_baseUrl${Api.products}/${widget.idOrSlug}');
      final req = await client.getUrl(uri);
      req.headers.set('Accept', 'application/json');
      final resp = await req.close();
      final body = await resp.transform(utf8.decoder).join();

      if (!mounted) return;

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final map = (jsonDecode(body) as Map).cast<String, dynamic>();
        setState(() {
          _product = ProductDetail.fromApi(map);
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Product not found.';
          _loading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Network problem. Please check your connection.';
        _loading = false;
      });
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _fetchRelated(String productId) async {
    setState(() {
      _loadingRelated = true;
      _related = const [];
    });

    final client = HttpClient();
    try {
      final uri = Uri.parse('$_baseUrl${Api.products}/$productId/related');
      final req = await client.getUrl(uri);
      req.headers.set('Accept', 'application/json');
      final resp = await req.close();
      final body = await resp.transform(utf8.decoder).join();

      if (!mounted) return;

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final map = (jsonDecode(body) as Map).cast<String, dynamic>();
        final items = (map['items'] as List? ?? [])
            .whereType<Map>()
            .map((m) => ProductCarouselItem.fromApi(m.cast<String, dynamic>()))
            .toList();
        setState(() {
          _related = items;
          _loadingRelated = false;
        });
      } else {
        setState(() => _loadingRelated = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingRelated = false);
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _fetchReviews(String productId) async {
    setState(() {
      _loadingReviews = true;
      _reviews = const [];
    });

    final client = HttpClient();
    try {
      final uri = Uri.parse('$_baseUrl${Api.products}/$productId/reviews');
      final req = await client.getUrl(uri);
      req.headers.set('Accept', 'application/json');
      final resp = await req.close();
      final body = await resp.transform(utf8.decoder).join();

      if (!mounted) return;

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final map = (jsonDecode(body) as Map).cast<String, dynamic>();
        final items = (map['items'] as List? ?? [])
            .whereType<Map>()
            .map((m) => ReviewItem.fromApi(m.cast<String, dynamic>()))
            .toList();
        setState(() {
          _reviews = items.take(3).toList();
          _loadingReviews = false;
        });
      } else {
        setState(() => _loadingReviews = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingReviews = false);
    } finally {
      client.close(force: true);
    }
  }

  // ---------------------------------------------------------------------------
  // Wishlist (uses your exact backend routes)
  // ---------------------------------------------------------------------------

  Future<void> _loadWishlistState(String productId) async {
    final token = (widget.accessToken ?? '').trim();
    if (token.isEmpty) return;

    final client = HttpClient();
    try {
      final uri = Uri.parse('$_baseUrl/api/wishlist');
      final req = await client.getUrl(uri);
      req.headers
        ..set('Accept', 'application/json')
        ..set('Authorization', 'Bearer $token');
      final resp = await req.close();
      final body = await resp.transform(utf8.decoder).join();

      if (!mounted) return;
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final map = (jsonDecode(body) as Map).cast<String, dynamic>();
        final ids = (map['items'] as List? ?? [])
            .whereType<Map>()
            .map((m) => (m['id'] ?? '').toString())
            .toSet();
        setState(() => _inWishlist = ids.contains(productId));
      }
    } catch (_) {
      // silent fail – keep default false
    } finally {
      client.close(force: true);
    }
  }

  String _extractServerMessage(String body, int status) {
    try {
      final m = (jsonDecode(body) as Map).cast<String, dynamic>();
      final msg = (m['error'] ?? m['message'] ?? m['detail'])?.toString();
      return (msg == null || msg.isEmpty) ? 'Error ($status).' : msg;
    } catch (_) {
      return 'Error ($status).';
    }
  }

  Future<bool> _wishlistAdd(String productId) async {
    final token = (widget.accessToken ?? '').trim();
    if (token.isEmpty) {
      AppSnackbars.info(context, 'Please log in to save items.', title: 'Sign-in required');
      return false;
    }

    final client = HttpClient();
    try {
      final uri = Uri.parse('$_baseUrl/api/wishlist/$productId');
      final req = await client.postUrl(uri);
      req.headers
        ..set('Accept', 'application/json')
        ..set('Authorization', 'Bearer $token');
      final resp = await req.close();
      final body = await resp.transform(utf8.decoder).join();

      if (resp.statusCode >= 200 && resp.statusCode < 300) return true;
      if (resp.statusCode == 401) {
        AppSnackbars.warning(context, 'Session expired. Please log in again.');
        return false;
      }
      AppSnackbars.error(context, _extractServerMessage(body, resp.statusCode));
      return false;
    } catch (_) {
      AppSnackbars.error(context, 'Network problem. Please try again.');
      return false;
    } finally {
      client.close(force: true);
    }
  }

  Future<bool> _wishlistRemove(String productId) async {
    final token = (widget.accessToken ?? '').trim();
    if (token.isEmpty) {
      AppSnackbars.info(context, 'Please log in to manage your wishlist.', title: 'Sign-in required');
      return false;
    }

    final client = HttpClient();
    try {
      final uri = Uri.parse('$_baseUrl/api/wishlist/$productId');
      final req = await client.deleteUrl(uri);
      req.headers
        ..set('Accept', 'application/json')
        ..set('Authorization', 'Bearer $token');
      final resp = await req.close();
      final body = await resp.transform(utf8.decoder).join();

      if (resp.statusCode >= 200 && resp.statusCode < 300) return true;
      if (resp.statusCode == 401) {
        AppSnackbars.warning(context, 'Session expired. Please log in again.');
        return false;
      }
      AppSnackbars.error(context, _extractServerMessage(body, resp.statusCode));
      return false;
    } catch (_) {
      AppSnackbars.error(context, 'Network problem. Please try again.');
      return false;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _toggleWishlist() async {
    if (_wishLoading || _product == null) return;
    final productId = _product!.id;

    setState(() => _wishLoading = true);
    bool ok = false;

    if (_inWishlist) {
      ok = await _wishlistRemove(productId);
      if (ok && mounted) {
        setState(() => _inWishlist = false);
        AppSnackbars.info(context, 'Removed from wishlist');
      }
    } else {
      ok = await _wishlistAdd(productId);
      if (ok && mounted) {
        setState(() => _inWishlist = true);
        AppSnackbars.success(context, 'Saved to wishlist');
      }
    }

    if (mounted) setState(() => _wishLoading = false);
  }

  // ---------------------------------------------------------------------------
  // Cart
  // ---------------------------------------------------------------------------

  Future<bool> _addToCartRequest({
    required String productId,
    required int qty,
  }) async {
    final token = (widget.accessToken ?? '').trim();
    if (token.isEmpty) {
      AppSnackbars.info(
        context,
        'Please log in to use your cart.',
        title: 'Sign-in required',
      );
      return false;
    }

    final client = HttpClient();
    try {
      final uri = Uri.parse('$_baseUrl/api/cart');
      final req = await client.postUrl(uri);
      req.headers.set('Accept', 'application/json');
      req.headers.set('Content-Type', 'application/json');
      req.headers.set('Authorization', 'Bearer $token');
      req.add(utf8.encode(jsonEncode({
        'product_id': productId,
        'qty': qty,
      })));
      final resp = await req.close();
      await resp.transform(utf8.decoder).join();

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        return true;
      } else if (resp.statusCode == 401) {
        AppSnackbars.warning(context, 'Session expired. Please log in again.');
        return false;
      } else {
        AppSnackbars.error(
          context,
          'Could not add to cart. (${resp.statusCode})',
        );
        return false;
      }
    } catch (_) {
      AppSnackbars.error(context, 'Network problem. Please try again.');
      return false;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _addToCart() async {
    final p = _product;
    if (p == null) return;
    final ok = await _addToCartRequest(productId: p.id, qty: _qty);
    if (ok && mounted) AppSnackbars.success(context, 'Added to cart');
  }

  // ---------------------------------------------------------------------------
  // Share
  // ---------------------------------------------------------------------------

  Future<void> _copyShareLink() async {
    final p = _product;
    if (p == null) return;
    // Build a shareable product URL (adjust path to your web/DEEPLINK).
    final url = '$_baseUrl/product/${p.id}';
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    AppSnackbars.info(context, 'Product link copied to clipboard');
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final titleStr = _product?.name ?? 'Product';
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBarPrimary(
        title: titleStr,
        actions: [
          IconButton(
            tooltip: 'Copy link',
            onPressed: _copyShareLink,
            icon: const Icon(Icons.link_rounded),
          ),
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: _WishlistIcon(
              active: _inWishlist,
              loading: _wishLoading,
              onTap: _toggleWishlist,
              activeColor: cs.primary,
            ),
          ),
        ],
      ),
      body: _loading
          ? const _DetailSkeleton()
          : _error != null
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: EmptyState(
                    icon: Icons.shopping_bag_outlined,
                    title: 'Oops',
                    message: _error ?? 'Something went wrong.',
                    primaryActionLabel: 'Retry',
                    onPrimaryAction: _fetchAll,
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchAll,
                  color: Theme.of(context).colorScheme.primary,
                  child: _buildDetail(),
                ),
    );
  }

  Widget _buildDetail() {
    final p = _product!;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final imgs = <String>[
      if ((p.heroImage ?? '').isNotEmpty) p.heroImage!,
      ...p.gallery,
    ];
    final hasImages = imgs.isNotEmpty;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // Images
        if (hasImages)
          _ImagesPager(
            images: imgs,
            index: _imageIndex,
            onChanged: (i) => setState(() => _imageIndex = i),
            headers: _imageHeaders,
          )
        else
          Container(
            height: 300,
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: const Center(
              child: Icon(Icons.image_not_supported_outlined, size: 48),
            ),
          ),

        // Title, rating, brand
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            p.name,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              _Stars(rating: p.ratingAvg, count: p.ratingCount),
              const SizedBox(width: 10),
              if ((p.brand ?? '').isNotEmpty)
                Text(
                  p.brand!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),

        // Price
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            _formatCurrency(p.price, currency: p.currency),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: cs.primary,
            ),
          ),
        ),

        // Stock + SKU + Category
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _InfoChip(
                icon: Icons.inventory_2_outlined,
                label: p.stock > 0 ? 'In stock (${p.stock})' : 'Out of stock',
                color: p.stock > 0 ? cs.primary : cs.error,
              ),
              if ((p.sku ?? '').isNotEmpty)
                _InfoChip(
                  icon: Icons.confirmation_number_outlined,
                  label: 'SKU: ${p.sku!}',
                  color: cs.secondary,
                ),
              if ((p.category ?? '').isNotEmpty)
                _InfoChip(
                  icon: Icons.category_outlined,
                  label: p.category!,
                  color: cs.tertiary,
                ),
            ],
          ),
        ),

        // Quantity + Wishlist button + Add to cart
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              _QtyStepper(
                value: _qty,
                onChanged: (v) => setState(() => _qty = v),
                max: max(1, p.stock),
              ),
              const SizedBox(width: 12),

              // Round heart next to qty (like your screenshot)
              _HeartCircleButton(
                active: _inWishlist,
                loading: _wishLoading,
                onTap: _toggleWishlist,
              ),

              const SizedBox(width: 12),
              Expanded(
                child: PrimaryButton(
                  label: 'Add to cart',
                  onPressed: p.stock > 0 ? _addToCart : null,
                  fullWidth: true,
                ),
              ),
            ],
          ),
        ),

        // Short description
        if ((p.shortDescription ?? '').isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              p.shortDescription!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),

        // Attributes (skin types / concerns)
        if (p.skinTypes.isNotEmpty || p.concerns.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (p.skinTypes.isNotEmpty) ...[
                  Text('Best for skin type', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: -4,
                    children: p.skinTypes
                        .map((t) => _Tag(label: _beautifyKey(t)))
                        .toList(),
                  ),
                  const SizedBox(height: 10),
                ],
                if (p.concerns.isNotEmpty) ...[
                  Text('Targets concerns', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: -4,
                    children: p.concerns
                        .map((t) => _Tag(label: _beautifyKey(t)))
                        .toList(),
                  ),
                ],
              ],
            ),
          ),

        // Description (HTML stripped)
        if ((p.descriptionHtml ?? '').isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              _stripHtml(p.descriptionHtml!),
              style: theme.textTheme.bodyMedium,
            ),
          ),

        const SizedBox(height: 8),
        const Divider(height: 1),

        // Reviews preview
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Text('Reviews', style: theme.textTheme.titleMedium),
              const Spacer(),
              if (_reviews.isNotEmpty)
                Text(
                  'Top 3 shown',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),

        if (_loadingReviews)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: _ReviewsSkeleton(),
          )
        else if (_reviews.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'No reviews yet.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: _reviews.map((r) => _ReviewTile(r)).toList(),
            ),
          ),

        const SizedBox(height: 8),
        const Divider(height: 1),

        // Related
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Text('Related products', style: theme.textTheme.titleMedium),
        ),
        if (_loadingRelated)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: _RelatedSkeleton(),
          )
        else if (_related.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              'No related products found.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ProductCarousel(
              title: '', // hide header row
              items: _related,
              accessTokenForImages: widget.accessToken,
              onTapItem: (item) {
                context.pushNamed(
                  'product_detail',
                  pathParameters: {'idOrSlug': item.id},
                );
              },
              onSeeAll: null,
            ),
          ),

        const SizedBox(height: 20),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Utils
  // ---------------------------------------------------------------------------

  String _stripHtml(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>'), '').trim();
  }

  String _beautifyKey(String key) {
    // "oily_skin" -> "Oily Skin"
    final s = key.replaceAll('_', ' ').trim();
    if (s.isEmpty) return key;
    return s.split(' ').map((w) {
      if (w.isEmpty) return w;
      return '${w[0].toUpperCase()}${w.substring(1)}';
    }).join(' ');
  }
}

// ============================================================================
// Models
// ============================================================================

class ProductDetail {
  final String id;
  final String name;
  final String? brand;
  final double price;
  final String currency;
  final String? heroImage;
  final List<String> gallery;
  final double ratingAvg;
  final int ratingCount;
  final int stock;
  final String? shortDescription;
  final String? descriptionHtml;
  final String? sku;
  final String? category;
  final String? itemType;
  final List<String> skinTypes;
  final List<String> concerns;

  ProductDetail({
    required this.id,
    required this.name,
    required this.brand,
    required this.price,
    required this.currency,
    required this.heroImage,
    required this.gallery,
    required this.ratingAvg,
    required this.ratingCount,
    required this.stock,
    required this.shortDescription,
    required this.descriptionHtml,
    required this.sku,
    required this.category,
    required this.itemType,
    required this.skinTypes,
    required this.concerns,
  });

  factory ProductDetail.fromApi(Map<String, dynamic> m) {
    double _toD(v) {
      if (v is num) return v.toDouble();
      return double.tryParse('$v') ?? 0.0;
    }

    int _toI(v) {
      if (v is num) return v.toInt();
      return int.tryParse('$v') ?? 0;
    }

    List<String> _toStrList(v) {
      if (v is List) {
        return v.map((e) => '$e').where((s) => s.isNotEmpty).toList();
      }
      return const [];
    }

    return ProductDetail(
      id: (m['id'] ?? '').toString(),
      name: (m['name'] ?? '').toString(),
      brand: (m['brand'] as String?)?.toString(),
      price: _toD(m['price']),
      currency: (m['currency'] ?? 'LKR').toString(),
      heroImage: (m['hero_image'] as String?)?.toString(),
      gallery: _toStrList(m['gallery']),
      ratingAvg: _toD(m['rating_avg']),
      ratingCount: _toI(m['rating_count']),
      stock: _toI(m['stock']),
      shortDescription: (m['short_description'] as String?)?.toString(),
      descriptionHtml: (m['description_html'] as String?)?.toString(),
      sku: (m['sku'] as String?)?.toString(),
      category: (m['category'] as String?)?.toString(),
      itemType: (m['item_type'] as String?)?.toString(),
      skinTypes: _toStrList(m['skin_types']),
      concerns: _toStrList(m['concerns']),
    );
  }
}

class ReviewItem {
  final String id;
  final int rating;
  final String? title;
  final String? body;
  final String? userName;
  final DateTime? createdAt;

  ReviewItem({
    required this.id,
    required this.rating,
    this.title,
    this.body,
    this.userName,
    this.createdAt,
  });

  factory ReviewItem.fromApi(Map<String, dynamic> m) {
    DateTime? _parse(String? s) {
      if (s == null) return null;
      try {
        return DateTime.tryParse(s);
      } catch (_) {
        return null;
      }
    }

    int _toI(v) {
      if (v is num) return v.toInt();
      return int.tryParse('$v') ?? 0;
    }

    return ReviewItem(
      id: (m['id'] ?? '').toString(),
      rating: _toI(m['rating']),
      title: (m['title'] as String?)?.toString(),
      body: (m['body'] as String?)?.toString(),
      userName: (m['user_name'] as String?)?.toString(),
      createdAt: _parse((m['created_at'] as String?)?.toString()),
    );
  }
}

// ============================================================================
// Widgets
// ============================================================================

class _ImagesPager extends StatelessWidget {
  const _ImagesPager({
    required this.images,
    required this.index,
    required this.onChanged,
    this.headers,
  });

  final List<String> images;
  final int index;
  final ValueChanged<int> onChanged;

  /// Optional headers for protected images (e.g., {'Authorization': 'Bearer ...'})
  final Map<String, String>? headers;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Stack(
      children: [
        SizedBox(
          height: 340,
          child: PageView.builder(
            itemCount: images.length,
            controller: PageController(initialPage: index),
            onPageChanged: onChanged,
            itemBuilder: (_, i) {
              final url = images[i];
              return Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cs.outlineVariant),
                  color: cs.surfaceContainerHigh,
                ),
                child: Image.network(
                  url,
                  fit: BoxFit.cover,
                  headers: headers,
                  errorBuilder: (_, __, ___) => Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        // Dots
        Positioned(
          bottom: 14,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: cs.surface.withOpacity(0.85),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(images.length, (i) {
                  final active = i == index;
                  return Container(
                    width: active ? 18.0 : 8.0,
                    height: 8.0,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: active ? cs.primary : cs.outlineVariant,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelMedium
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  const _QtyStepper({
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 999,
  });

  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    void dec() {
      if (value > min) onChanged(value - 1);
    }

    void inc() {
      if (value < max) onChanged(value + 1);
    }

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _IconBtn(icon: Icons.remove_rounded, onTap: dec),
          SizedBox(
            width: 44,
            child: Center(
              child: Text(
                '$value',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          _IconBtn(icon: Icons.add_rounded, onTap: inc),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 48,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Icon(icon),
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars({required this.rating, required this.count});
  final double rating;
  final int count;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final full = rating.floor();
    final half = (rating - full) >= 0.5;
    return Row(
      children: [
        ...List.generate(5, (i) {
          IconData icon;
          if (i < full) {
            icon = Icons.star_rounded;
          } else if (i == full && half) {
            icon = Icons.star_half_rounded;
          } else {
            icon = Icons.star_border_rounded;
          }
          return Icon(icon, size: 18, color: cs.primary);
        }),
        const SizedBox(width: 6),
        Text(
          '${rating.toStringAsFixed(1)} ($count)',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: cs.onSurfaceVariant),
        )
      ],
    );
  }
}

// Wishlist heart with loading overlay in AppBar
class _WishlistIcon extends StatelessWidget {
  const _WishlistIcon({
    required this.active,
    required this.loading,
    required this.onTap,
    required this.activeColor,
  });

  final bool active;
  final bool loading;
  final VoidCallback onTap;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final icon = active ? Icons.favorite : Icons.favorite_border;
    final color = active ? activeColor : cs.onSurface;

    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          tooltip: active ? 'Remove from wishlist' : 'Add to wishlist',
          onPressed: loading ? null : onTap,
          icon: Icon(icon, color: color),
        ),
        if (loading)
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
      ],
    );
  }
}

// Round heart next to the quantity stepper (like screenshot)
class _HeartCircleButton extends StatelessWidget {
  const _HeartCircleButton({
    required this.active,
    required this.loading,
    required this.onTap,
  });

  final bool active;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          InkWell(
            onTap: loading ? null : onTap,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: cs.surface,
                shape: BoxShape.circle,
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Icon(
                active ? Icons.favorite : Icons.favorite_border,
                color: active ? cs.primary : cs.onSurface,
              ),
            ),
          ),
          if (loading)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// Skeletons
// ============================================================================

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Container(
          height: 340,
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outlineVariant),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _bar(cs, 240, 20),
              const SizedBox(height: 8),
              _bar(cs, 140, 14),
              const SizedBox(height: 10),
              _bar(cs, 90, 28),
              const SizedBox(height: 20),
              Row(
                children: [
                  _bar(cs, 120, 32),
                  const SizedBox(width: 12),
                  Expanded(child: _bar(cs, double.infinity, 48)),
                  const SizedBox(width: 12),
                  _bar(cs, 100, 48),
                ],
              ),
              const SizedBox(height: 20),
              _bar(cs, double.infinity, 14),
              const SizedBox(height: 8),
              _bar(cs, double.infinity, 14),
              const SizedBox(height: 8),
              _bar(cs, 220, 14),
              const SizedBox(height: 24),
              _bar(cs, 160, 18),
              const SizedBox(height: 10),
              _bar(cs, double.infinity, 120),
              const SizedBox(height: 24),
              _bar(cs, 160, 18),
              const SizedBox(height: 10),
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
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bar(ColorScheme cs, double w, double h) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

class _RelatedSkeleton extends StatelessWidget {
  const _RelatedSkeleton();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
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
          );
        },
      ),
    );
  }
}

class _ReviewsSkeleton extends StatelessWidget {
  const _ReviewsSkeleton();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: List.generate(3, (_) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _bar(cs, 120, 14),
                const SizedBox(height: 8),
                _bar(cs, double.infinity, 12),
                const SizedBox(height: 6),
                _bar(cs, 200, 12),
              ],
            ),
          ),
        );
      }),
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

// -----------------------------------------------------------------------------
// Review tile
// -----------------------------------------------------------------------------

class _ReviewTile extends StatelessWidget {
  const _ReviewTile(this.item);
  final ReviewItem item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dt = item.createdAt;
    final dateStr = dt == null
        ? ''
        : '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

    final displayName = (item.userName ?? '').trim().isNotEmpty
        ? (item.userName ?? '').trim()
        : 'Anonymous';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: name + rating + date
          Row(
            children: [
              Expanded(
                child: Text(
                  displayName,
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Row(
                children: List.generate(5, (i) {
                  return Icon(
                    i < item.rating
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    size: 16,
                    color: cs.primary,
                  );
                }),
              ),
              if (dateStr.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  dateStr,
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ],
          ),
          if ((item.title ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              item.title!,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
          if ((item.body ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              item.body!,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }
}
