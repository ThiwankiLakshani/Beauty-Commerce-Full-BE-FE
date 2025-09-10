// lib/features/product/widgets/add_to_cart_panel.dart

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../app/app_constants.dart';
import '../../../common/utils/snackbar.dart';
import '../../../common/widgets/primary_button.dart';

class AddToCartPanel extends StatefulWidget {
  const AddToCartPanel({
    super.key,
    required this.productId,
    required this.price,
    required this.currency,
    required this.stock,
    this.accessToken,
    this.initialQty = 1,
    this.onAdded,
    this.onBuyNow,
  });

  final String productId;
  final double price;
  final String currency;
  final int stock;

  /// JWT access token. Required to call /api/cart.
  final String? accessToken;

  /// Initial quantity (clamped to 1..stock).
  final int initialQty;

  /// Called after the item is successfully added (Add to cart).
  final VoidCallback? onAdded;

  /// Called after a successful "Buy now" add-to-cart (parent should navigate).
  final VoidCallback? onBuyNow;

  @override
  State<AddToCartPanel> createState() => _AddToCartPanelState();
}

class _AddToCartPanelState extends State<AddToCartPanel> {
  late int _qty;
  bool _adding = false;

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
    _qty = _clampQty(widget.initialQty);
  }

  @override
  void didUpdateWidget(covariant AddToCartPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stock != widget.stock) {
      _qty = _clampQty(_qty);
    }
  }

  int _clampQty(int v) {
    if (widget.stock <= 0) return 1;
    if (v < 1) return 1;
    if (v > widget.stock) return widget.stock;
    return v;
  }

  Future<bool> _addToCartRequest() async {
    final token = (widget.accessToken ?? '').trim();
    if (token.isEmpty) {
      AppSnackbars.info(
        context,
        'Please log in to add items to your cart.',
        title: 'Sign-in required',
      );
      return false;
    }
    if (widget.stock <= 0) {
      AppSnackbars.warning(context, 'This item is currently out of stock.');
      return false;
    }

    final client = HttpClient();
    try {
      final uri = Uri.parse('$_baseUrl/api/cart');
      final req = await client.postUrl(uri);
      req.headers
        ..set('Accept', 'application/json')
        ..set('Content-Type', 'application/json')
        ..set('Authorization', 'Bearer $token');
      req.add(utf8.encode(jsonEncode({
        'product_id': widget.productId,
        'qty': _qty,
      })));

      final resp = await req.close();
      // Consume the body even if unused.
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
    if (_adding) return;
    setState(() => _adding = true);

    final ok = await _addToCartRequest();
    if (!mounted) return;

    if (ok) {
      AppSnackbars.success(context, 'Added to cart');
      widget.onAdded?.call();
    }

    setState(() => _adding = false);
  }

  Future<void> _buyNow() async {
    if (_adding) return;
    setState(() => _adding = true);

    final ok = await _addToCartRequest();
    if (!mounted) return;

    if (ok) {
      // Parent decides where to go (e.g., cart or checkout).
      if (widget.onBuyNow != null) {
        widget.onBuyNow!.call();
      } else {
        AppSnackbars.info(
          context,
          'Item added. Open your cart to proceed to checkout.',
        );
      }
    }

    setState(() => _adding = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final disabled = widget.stock <= 0;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border(top: BorderSide(color: cs.outlineVariant)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 360;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Price row
                Row(
                  children: [
                    Text(
                      '${widget.currency} ${widget.price.toStringAsFixed(2)}',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: cs.primary,
                      ),
                    ),
                    const Spacer(),
                    _QtyStepper(
                      value: _qty,
                      max: widget.stock <= 0 ? 1 : widget.stock,
                      onChanged: (v) => setState(() => _qty = v),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: PrimaryButton(
                        label: disabled
                            ? 'Out of stock'
                            : (_adding ? 'Adding…' : 'Add to cart'),
                        loading: _adding,
                        onPressed: disabled || _adding ? null : _addToCart,
                        fullWidth: true,
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: disabled || _adding ? null : _buyNow,
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            horizontal: isCompact ? 10 : 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Buy now'),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Private quantity stepper (compact, no external deps)
// -----------------------------------------------------------------------------
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
