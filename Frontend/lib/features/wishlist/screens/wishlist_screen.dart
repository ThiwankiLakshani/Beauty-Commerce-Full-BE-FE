// lib/features/wishlist/screens/wishlist_screen.dart


import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_constants.dart';
import '../../../common/utils/snackbar.dart';
import '../../../common/widgets/app_bar_primary.dart';
import '../../../common/widgets/empty_state.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({
    super.key,
    this.accessToken,
  });

  /// JWT access token; required to view/modify wishlist.
  final String? accessToken;

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  bool _loading = true;
  String? _error;
  List<_WishItem> _items = const [];

  String get _baseUrl {
    const fromEnv = String.fromEnvironment(Api.envBaseUrlKey, defaultValue: '');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (Platform.isIOS || Platform.isMacOS) {
      return Api.defaultBaseUrlIosSimulator; // http://localhost:5000
    }
    return Api.defaultBaseUrlAndroidEmulator; // http://10.0.2.2:5000
  }

  bool get _hasToken => (widget.accessToken ?? '').trim().isNotEmpty;

  Map<String, String>? get _imageHeaders {
    final t = (widget.accessToken ?? '').trim();
    if (t.isEmpty) return null;
    return {'Authorization': 'Bearer $t'};
  }

  String _formatCurrency(double amount, {String currency = 'LKR'}) {
    return '$currency ${amount.toStringAsFixed(2)}';
  }

  @override
  void initState() {
    super.initState();
    if (_hasToken) {
      _fetch();
    } else {
      // No token -> show sign-in prompt state (not loading)
      _loading = false;
      _error = null;
      _items = const [];
    }
  }

  @override
  void didUpdateWidget(covariant WishlistScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.accessToken != widget.accessToken) {
      if (_hasToken) {
        _fetch();
      } else {
        setState(() {
          _loading = false;
          _error = null;
          _items = const [];
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Networking
  // ---------------------------------------------------------------------------

  String _extractServerMessage(String body, int status) {
    try {
      final m = (jsonDecode(body) as Map).cast<String, dynamic>();
      final msg = (m['error'] ?? m['message'] ?? m['detail'])?.toString();
      return (msg == null || msg.isEmpty) ? 'Error ($status).' : msg;
    } catch (_) {
      return 'Error ($status).';
    }
  }

  Future<void> _fetch() async {
    if (!_hasToken) return;
    setState(() {
      _loading = true;
      _error = null;
      _items = const [];
    });

    final client = HttpClient();
    try {
      final uri = Uri.parse('$_baseUrl${Api.wishlist}');
      final req = await client.getUrl(uri);
      req.headers.set('Accept', 'application/json');
      req.headers.set('Authorization', 'Bearer ${widget.accessToken}');
      final resp = await req.close();
      final body = await resp.transform(utf8.decoder).join();
      if (!mounted) return;

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final map = (jsonDecode(body) as Map).cast<String, dynamic>();
        final list = (map['items'] as List? ?? [])
            .whereType<Map>()
            .map((m) => _WishItem.fromApi(m.cast<String, dynamic>()))
            .toList();
        setState(() {
          _items = list;
          _loading = false;
        });
      } else if (resp.statusCode == 401) {
        setState(() {
          _loading = false;
        });
        AppSnackbars.warning(context, 'Session expired. Please log in again.');
      } else {
        setState(() {
          _error = _extractServerMessage(body, resp.statusCode);
          _loading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Network problem. Please try again.';
        _loading = false;
      });
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _remove(String productId) async {
    if (!_hasToken) return;

    final client = HttpClient();
    try {
      final uri = Uri.parse('$_baseUrl${Api.wishlist}/$productId');
      final req = await client.deleteUrl(uri);
      req.headers.set('Accept', 'application/json');
      req.headers.set('Authorization', 'Bearer ${widget.accessToken}');
      final resp = await req.close();
      final body = await resp.transform(utf8.decoder).join();

      if (!mounted) return;

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        setState(() {
          _items = _items.where((e) => e.id != productId).toList();
        });
        AppSnackbars.success(context, 'Removed from wishlist');
      } else if (resp.statusCode == 401) {
        AppSnackbars.warning(context, 'Session expired. Please log in again.');
      } else {
        AppSnackbars.error(context, _extractServerMessage(body, resp.statusCode));
      }
    } catch (_) {
      if (mounted) AppSnackbars.error(context, 'Network problem. Try again.');
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _addToCart(String productId) async {
    if (!_hasToken) {
      AppSnackbars.info(context, 'Please log in to use your cart.', title: 'Sign-in required');
      return;
    }
    final client = HttpClient();
    try {
      final uri = Uri.parse('$_baseUrl${Api.cart}');
      final req = await client.postUrl(uri);
      req.headers.set('Accept', 'application/json');
      req.headers.set('Content-Type', 'application/json');
      req.headers.set('Authorization', 'Bearer ${widget.accessToken}');
      req.add(utf8.encode(jsonEncode({
        'product_id': productId,
        'qty': 1,
      })));
      final resp = await req.close();
      final body = await resp.transform(utf8.decoder).join();
      if (!mounted) return;

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        AppSnackbars.success(context, 'Added to cart');
      } else if (resp.statusCode == 401) {
        AppSnackbars.warning(context, 'Session expired. Please log in again.');
      } else {
        AppSnackbars.error(context, _extractServerMessage(body, resp.statusCode));
      }
    } catch (_) {
      if (mounted) AppSnackbars.error(context, 'Network problem. Try again.');
    } finally {
      client.close(force: true);
    }
  }

  // ---------------------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------------------

  void _openProduct(_WishItem item) {
    context.pushNamed(
      'product_detail',
      pathParameters: {'idOrSlug': item.id},     // <-- must match your route param
      extra: {'accessToken': widget.accessToken}, // <-- pass token through
    );
  }


  void _goToLogin() {
    // Adjust if your auth route uses a different name.
    context.pushNamed('login');
  }

  void _goDiscover() {
    // Navigate to your main discovery/home/catalog route.
    // Use goNamed to replace instead of stacking.
    context.goNamed('home');
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppBarPrimary(title: 'Wishlist'),
      body: !_hasToken
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: EmptyState(
                icon: Icons.favorite_border,
                title: 'Sign in to view your wishlist',
                message: 'Save items you love and access them across devices.',
                primaryActionLabel: 'Go to Login',
                onPrimaryAction: _goToLogin,
              ),
            )
          : _loading
              ? const _WishlistSkeleton()
              : _error != null
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: EmptyState(
                        icon: Icons.error_outline,
                        title: 'Something went wrong',
                        message: _error ?? 'Please try again.',
                        primaryActionLabel: 'Retry',
                        onPrimaryAction: _fetch,
                      ),
                    )
                  : _items.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(16),
                          child: EmptyState(
                            icon: Icons.favorite_border,
                            title: 'Your wishlist is empty',
                            message: 'Tap the heart on a product to add it here.',
                            primaryActionLabel: 'Discover products',
                            onPrimaryAction: _goDiscover,
                          ),
                        )
                      : RefreshIndicator(
                          color: Theme.of(context).colorScheme.primary,
                          onRefresh: _fetch,
                          child: ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
                            itemCount: _items.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (_, i) => _WishTile(
                              item: _items[i],
                              onTap: () => _openProduct(_items[i]),
                              onRemove: () => _remove(_items[i].id),
                              onAddToCart: () => _addToCart(_items[i].id),
                              formatPrice: (p, c) => _formatCurrency(p, currency: c),
                              imageHeaders: _imageHeaders,
                            ),
                          ),
                        ),
    );
  }
}

// ============================================================================
// Models
// ============================================================================

class _WishItem {
  final String id;
  final String name;
  final double price;
  final String currency;
  final String? heroImage;

  _WishItem({
    required this.id,
    required this.name,
    required this.price,
    required this.currency,
    required this.heroImage,
  });

  factory _WishItem.fromApi(Map<String, dynamic> m) {
    double _toD(v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0.0;
    return _WishItem(
      id: (m['id'] ?? '').toString(),
      name: (m['name'] ?? '').toString(),
      price: _toD(m['price']),
      currency: (m['currency'] ?? 'LKR').toString(),
      heroImage: (m['hero_image'] as String?)?.toString(),
    );
  }
}

// ============================================================================
// Tiles & Skeletons
// ============================================================================

class _WishTile extends StatelessWidget {
  const _WishTile({
    required this.item,
    required this.onTap,
    required this.onRemove,
    required this.onAddToCart,
    required this.formatPrice,
    this.imageHeaders,
  });

  final _WishItem item;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  final VoidCallback onAddToCart;
  final String Function(double price, String currency) formatPrice;
  final Map<String, String>? imageHeaders;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(
          children: [
            // Image
            Container(
              width: 84,
              height: 84,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: (item.heroImage != null && item.heroImage!.isNotEmpty)
                  ? Image.network(
                      item.heroImage!,
                      fit: BoxFit.cover,
                      headers: imageHeaders,
                      errorBuilder: (_, __, ___) =>
                          Icon(Icons.broken_image_outlined, color: cs.onSurfaceVariant),
                    )
                  : Icon(Icons.image_outlined, color: cs.onSurfaceVariant),
            ),
            const SizedBox(width: 12),

            // Texts
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name, // non-null
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    formatPrice(item.price, item.currency),
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: cs.primary, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),

            // Actions
            const SizedBox(width: 8),
            Tooltip(
              message: 'Add to cart',
              child: IconButton(
                onPressed: onAddToCart,
                icon: const Icon(Icons.add_shopping_cart_outlined),
              ),
            ),
            Tooltip(
              message: 'Remove',
              child: IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WishlistSkeleton extends StatelessWidget {
  const _WishlistSkeleton();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, __) {
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: cs.outlineVariant),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _bar(cs, double.infinity, 14),
                    const SizedBox(height: 6),
                    _bar(cs, 180, 14),
                    const SizedBox(height: 8),
                    _bar(cs, 90, 20),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _circle(cs, 40),
              const SizedBox(width: 6),
              _circle(cs, 40),
            ],
          ),
        );
      },
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

  Widget _circle(ColorScheme cs, double s) {
    return Container(
      width: s,
      height: s,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        shape: BoxShape.circle,
      ),
    );
  }
}
