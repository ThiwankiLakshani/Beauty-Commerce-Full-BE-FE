// lib/features/cart/screens/cart_screen.dart


import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../app/app_constants.dart';
import '../../../common/utils/snackbar.dart';
import '../../../common/widgets/app_bar_primary.dart';
import '../../../common/widgets/empty_state.dart';
import '../../../common/widgets/primary_button.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({
    super.key,
    this.accessToken,
  });

  /// JWT access token (required for server cart).
  final String? accessToken;

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  bool _loading = true;
  String? _error;

  List<CartItem> _items = const [];
  CartPricing? _pricing;

  bool get _hasToken => (widget.accessToken ?? '').trim().isNotEmpty;

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
    if (_hasToken) {
      _fetch();
    } else {
      _resetEmpty();
    }
  }

  @override
  void didUpdateWidget(covariant CartScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.accessToken != widget.accessToken) {
      if (_hasToken) {
        _fetch();
      } else {
        _resetEmpty();
      }
    }
  }

  void _resetEmpty() {
    setState(() {
      _loading = false;
      _error = null;
      _items = const [];
      _pricing = null;
    });
  }

  // --------------------------------------------
  // Networking
  // --------------------------------------------
  Future<void> _fetch() async {
    if (!_hasToken) return;
    setState(() {
      _loading = true;
      _error = null;
      _items = const [];
      _pricing = null;
    });

    final client = HttpClient();
    try {
      final uri = Uri.parse('$_baseUrl${Api.cart}');
      final req = await client.getUrl(uri);
      req.headers
        ..set('Accept', 'application/json')
        ..set('Authorization', 'Bearer ${widget.accessToken}');
      final resp = await req.close();
      final body = await resp.transform(utf8.decoder).join();

      if (!mounted) return;

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        Map<String, dynamic> map = {};
        try {
          map = (jsonDecode(body) as Map).cast<String, dynamic>();
        } catch (_) {}
        final items = (map['items'] as List? ?? [])
            .whereType<Map>()
            .map((m) => CartItem.fromApi(m.cast<String, dynamic>()))
            .toList();
        final pricing = map['pricing'] is Map
            ? CartPricing.fromApi((map['pricing'] as Map).cast<String, dynamic>())
            : null;

        setState(() {
          _items = items;
          _pricing = pricing;
          _loading = false;
        });
      } else if (resp.statusCode == 401) {
        setState(() => _loading = false);
        AppSnackbars.warning(context, 'Session expired. Please log in again.');
      } else {
        setState(() {
          _error = 'Could not load your cart.';
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

  Future<void> _updateQty(String productId, int qty) async {
    if (!_hasToken) return;
    final newQty = qty < 1 ? 1 : qty;

    final client = HttpClient();
    try {
      final uri = Uri.parse('$_baseUrl${Api.cart}/items/$productId');
      final req = await client.putUrl(uri);
      req.headers
        ..set('Accept', 'application/json')
        ..set('Content-Type', 'application/json')
        ..set('Authorization', 'Bearer ${widget.accessToken}');
      req.add(utf8.encode(jsonEncode({'qty': newQty})));
      final resp = await req.close();
      await resp.transform(utf8.decoder).join();

      if (!mounted) return;

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        _fetch(); // refresh totals and items
      } else {
        AppSnackbars.error(context, 'Could not update quantity (${resp.statusCode}).');
      }
    } catch (_) {
      if (mounted) AppSnackbars.error(context, 'Network problem. Try again.');
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _removeItem(String productId) async {
    if (!_hasToken) return;
    final client = HttpClient();
    try {
      final uri = Uri.parse('$_baseUrl${Api.cart}/items/$productId');
      final req = await client.deleteUrl(uri);
      req.headers
        ..set('Accept', 'application/json')
        ..set('Authorization', 'Bearer ${widget.accessToken}');
      final resp = await req.close();
      await resp.transform(utf8.decoder).join();

      if (!mounted) return;

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        setState(() {
          _items = _items.where((e) => e.productId != productId).toList();
        });
        _fetch(); // refresh totals
      } else {
        AppSnackbars.error(context, 'Could not remove item (${resp.statusCode}).');
      }
    } catch (_) {
      if (mounted) AppSnackbars.error(context, 'Network problem. Try again.');
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _clearCart({bool silent = false}) async {
    if (!_hasToken) {
      // Just clear locally for no-token case (defensive)
      setState(() {
        _items = const [];
        _pricing = null;
      });
      if (!silent) AppSnackbars.success(context, 'Cart cleared');
      return;
    }

    final client = HttpClient();
    try {
      final uri = Uri.parse('$_baseUrl${Api.cart}/clear');
      final req = await client.postUrl(uri);
      req.headers
        ..set('Accept', 'application/json')
        ..set('Authorization', 'Bearer ${widget.accessToken}');
      final resp = await req.close();
      await resp.transform(utf8.decoder).join();

      if (!mounted) return;

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        setState(() {
          _items = const [];
          _pricing = null;
        });
        if (!silent) AppSnackbars.success(context, 'Cart cleared');
      } else {
        if (!silent) {
          AppSnackbars.error(context, 'Could not clear cart (${resp.statusCode}).');
        }
      }
    } catch (_) {
      if (mounted && !silent) {
        AppSnackbars.error(context, 'Network problem. Try again.');
      }
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _checkout() async {
    if (_items.isEmpty) {
      AppSnackbars.info(context, 'Your cart is empty');
      return;
    }

    final payloadItems = _items
        .map((e) => {
              'product_id': e.productId,
              'qty': e.qty,
            })
        .toList();

    final client = HttpClient();
    try {
      final uri = Uri.parse('$_baseUrl${Api.checkout}');
      final req = await client.postUrl(uri);
      req.headers
        ..set('Accept', 'application/json')
        ..set('Content-Type', 'application/json');
      if (_hasToken) {
        // Optional; fine to include
        req.headers.set('Authorization', 'Bearer ${widget.accessToken}');
      }
      req.add(utf8.encode(jsonEncode({
        'items': payloadItems,
        'payment_method': 'cod',
      })));


      final resp = await req.close();
      final body = await resp.transform(utf8.decoder).join();

      if (!mounted) return;

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        Map<String, dynamic> map = {};
        try {
          map = (jsonDecode(body) as Map).cast<String, dynamic>();
        } catch (_) {}
        final orderNo = (map['order_no'] ?? '').toString();
        final status = (map['status'] ?? '').toString();

        // Clear cart quietly if logged in (avoid double snackbar).
        if (_hasToken) {
          await _clearCart(silent: true);
        } else {
          // For no-token scenario, clear locally.
          setState(() {
            _items = const [];
            _pricing = null;
          });
        }

        AppSnackbars.success(
          context,
          'Order placed successfully',
          title: orderNo.isNotEmpty ? 'Order $orderNo${status.isNotEmpty ? " ($status)" : ""}' : 'Order created',
        );
      } else {
        AppSnackbars.error(context, 'Checkout failed (${resp.statusCode}).');
      }
    } catch (_) {
      if (mounted) AppSnackbars.error(context, 'Network problem during checkout.');
    } finally {
      client.close(force: true);
    }
  }

  String _formatCurrency(double amount, {String? currency}) {
    final cur = (currency ?? _pricing?.currency ?? 'LKR').trim().isEmpty ? 'LKR' : (currency ?? _pricing?.currency ?? 'LKR');
    return '$cur ${amount.toStringAsFixed(2)}';
  }

  // --------------------------------------------
  // Build
  // --------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppBarPrimary(title: 'Cart'),
      body: !_hasToken
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: EmptyState(
                icon: Icons.shopping_cart_outlined,
                title: 'Sign in to view your cart',
                message: 'Your cart is saved to your account across devices.',
                primaryActionLabel: 'Go to Login',
                onPrimaryAction: () =>
                    AppSnackbars.info(context, 'Navigate to Login'),
              ),
            )
          : _loading
              ? const _CartSkeleton()
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
                            icon: Icons.shopping_cart_outlined,
                            title: 'Your cart is empty',
                            message: 'Explore products and add something you like.',
                            primaryActionLabel: 'Discover products',
                            onPrimaryAction: () =>
                                AppSnackbars.info(context, 'Open Discover'),
                          ),
                        )
                      : Column(
                          children: [
                            Expanded(
                              child: RefreshIndicator(
                                color: Theme.of(context).colorScheme.primary,
                                onRefresh: _fetch,
                                child: ListView.separated(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                                  itemCount: _items.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                                  itemBuilder: (_, i) {
                                    final it = _items[i];
                                    return _CartTile(
                                      item: it,
                                      onQtyChanged: (v) => _updateQty(it.productId, v),
                                      onRemove: () => _removeItem(it.productId),
                                      formatPrice: (p) =>
                                          _formatCurrency(p, currency: it.currency),
                                    );
                                  },
                                ),
                              ),
                            ),
                            _SummaryPanel(
                              pricing: _pricing,
                              formatCurrency: (p) => _formatCurrency(p),
                              onClear: () => _clearCart(),
                              onCheckout: _checkout,
                            ),
                          ],
                        ),
    );
  }
}

// ============================================================================
// Models
// ============================================================================
class CartItem {
  final String productId;
  final String name;
  final String sku;
  final int qty;
  final double price;
  final double subtotal;
  final String currency;
  final String? heroImage;

  CartItem({
    required this.productId,
    required this.name,
    required this.sku,
    required this.qty,
    required this.price,
    required this.subtotal,
    required this.currency,
    required this.heroImage,
  });

  factory CartItem.fromApi(Map<String, dynamic> m) {
    double _toD(v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0.0;
    int _toI(v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

    return CartItem(
      productId: (m['product_id'] ?? '').toString(),
      name: (m['name'] ?? '').toString(),
      sku: (m['sku'] ?? '').toString(),
      qty: _toI(m['qty']),
      price: _toD(m['price']),
      subtotal: _toD(m['subtotal']),
      currency: (m['currency'] ?? 'LKR').toString(),
      heroImage: (m['hero_image'] as String?)?.toString(),
    );
    }
}

class CartPricing {
  final String currency;
  final double subtotal;
  final double taxTotal;
  final double shippingTotal;
  final double total;

  CartPricing({
    required this.currency,
    required this.subtotal,
    required this.taxTotal,
    required this.shippingTotal,
    required this.total,
  });

  factory CartPricing.fromApi(Map<String, dynamic> m) {
    double _toD(v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0.0;
    return CartPricing(
      currency: (m['currency'] ?? 'LKR').toString(),
      subtotal: _toD(m['subtotal']),
      taxTotal: _toD(m['tax_total']),
      shippingTotal: _toD(m['shipping_total']),
      total: _toD(m['total']),
    );
  }
}

// ============================================================================
// Widgets
// ============================================================================
class _CartTile extends StatelessWidget {
  const _CartTile({
    required this.item,
    required this.onQtyChanged,
    required this.onRemove,
    required this.formatPrice,
  });

  final CartItem item;
  final ValueChanged<int> onQtyChanged;
  final VoidCallback onRemove;
  final String Function(double price) formatPrice;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const maxQty = 999; // Allow generous range when stock not provided.

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                    errorBuilder: (_, __, ___) =>
                        Icon(Icons.broken_image_outlined, color: cs.onSurfaceVariant),
                  )
                : Icon(Icons.image_outlined, color: cs.onSurfaceVariant),
          ),
          const SizedBox(width: 12),

          // Texts & controls
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'SKU: ${item.sku.isEmpty ? '-' : item.sku}',
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 8),

                // Inside _CartTile.build() -> replace the Row that has the stepper + price
                Row(
                  children: [
                    _QtyStepper(
                      value: item.qty,
                      min: 1,
                      max: maxQty,
                      onChanged: onQtyChanged,
                    ),
                    const SizedBox(width: 8),
                    // Give the price the remaining space and allow it to shrink
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: FittedBox(
                          fit: BoxFit.scaleDown, // shrinks text if needed
                          alignment: Alignment.centerRight,
                          child: Text(
                            formatPrice(item.subtotal),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis, // extra safety
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(color: cs.primary, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ),
                  ],
                )

              ],
            ),
          ),

          // Remove
          const SizedBox(width: 8),
          Tooltip(
            message: 'Remove',
            child: IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({
    required this.pricing,
    required this.formatCurrency,
    required this.onClear,
    required this.onCheckout,
  });

  final CartPricing? pricing;
  final String Function(double) formatCurrency;
  final VoidCallback onClear;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final p = pricing;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border(top: BorderSide(color: cs.outlineVariant)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (p != null) ...[
              _row(context, 'Subtotal', formatCurrency(p.subtotal)),
              const SizedBox(height: 4),
              _row(context, 'Tax', formatCurrency(p.taxTotal)),
              const SizedBox(height: 4),
              _row(context, 'Shipping', formatCurrency(p.shippingTotal)),
              const Divider(height: 16),
              _row(context, 'Total', formatCurrency(p.total), isTotal: true),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                OutlinedButton(
                  onPressed: onClear,
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Clear'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PrimaryButton(
                    label: 'Checkout',
                    onPressed: onCheckout,
                    fullWidth: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value, {bool isTotal = false}) {
    final style = isTotal
        ? Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)
        : Theme.of(context).textTheme.bodyLarge;
    return Row(
      children: [
        Text(label, style: style),
        const Spacer(),
        Text(value, style: style),
      ],
    );
  }
}

// ============================================================================
// Local quantity stepper (compact)
// ============================================================================
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
      height: 40,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _IconBtn(icon: Icons.remove_rounded, onTap: dec),
          SizedBox(
            width: 40,
            child: Center(
              child: Text(
                '$value',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
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
      width: 40,
      height: 40,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Icon(icon),
      ),
    );
  }
}

class _CartSkeleton extends StatelessWidget {
  const _CartSkeleton();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
            itemCount: 4,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, __) => Container(
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
                        _bar(cs, 140, 14),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _bar(cs, 100, 36),
                            const Spacer(),
                            _bar(cs, 80, 20),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        _summarySkeleton(cs),
      ],
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

  Widget _summarySkeleton(ColorScheme cs) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border(top: BorderSide(color: cs.outlineVariant)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _bar(cs, double.infinity, 16),
            const SizedBox(height: 8),
            _bar(cs, double.infinity, 16),
            const SizedBox(height: 8),
            _bar(cs, double.infinity, 22),
            const SizedBox(height: 10),
            Row(
              children: [
                _bar(cs, 80, 40),
                const SizedBox(width: 10),
                Expanded(child: _bar(cs, double.infinity, 48)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
