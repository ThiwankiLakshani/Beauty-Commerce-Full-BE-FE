// lib/features/cart/screens/order_review_screen.dart
//


import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../app/app_constants.dart';
import '../../../common/utils/snackbar.dart';
import '../../../common/widgets/app_bar_primary.dart';
import '../../../common/widgets/empty_state.dart';
import '../../../common/widgets/primary_button.dart';

class OrderReviewScreen extends StatefulWidget {
  const OrderReviewScreen({
    super.key,
    required this.accessToken,
    this.onOrderPlaced,
  });

  /// JWT is required for fetching cart/addresses.
  final String accessToken;

  /// Optional callback after order is successfully placed.
  final VoidCallback? onOrderPlaced;

  @override
  State<OrderReviewScreen> createState() => _OrderReviewScreenState();
}

class _OrderReviewScreenState extends State<OrderReviewScreen> {
  bool _loading = true;
  String? _error;

  // Data
  List<_CartItem> _items = const [];
  _CartPricing? _pricing;
  List<_Address> _addresses = const [];
  String? _selectedAddressId;

  // Contact inputs
  final _emailCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  // UI state
  bool _placing = false;

  String get _baseUrl {
    const fromEnv = String.fromEnvironment(Api.envBaseUrlKey, defaultValue: '');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (Platform.isIOS || Platform.isMacOS) return Api.defaultBaseUrlIosSimulator;
    return Api.defaultBaseUrlAndroidEmulator;
  }

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
      _items = const [];
      _pricing = null;
      _addresses = const [];
      _selectedAddressId = null;
    });

    try {
      await Future.wait([
        _fetchCart(),
        _fetchAddresses(),
      ]);

      // Autofill name from default address if present (email cannot be inferred here)
      final sel = _selectedAddress();
      if ((_nameCtrl.text.trim().isEmpty) && sel != null && (sel.name.isNotEmpty)) {
        _nameCtrl.text = sel.name;
      }

      if (!mounted) return;
      setState(() => _loading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load order details. Please try again.';
        _loading = false;
      });
    }
  }

  Future<void> _fetchCart() async {
    final client = HttpClient();
    try {
      final uri = Uri.parse('$_baseUrl${Api.cart}');
      final req = await client.getUrl(uri);
      req.headers.set('Accept', 'application/json');
      req.headers.set('Authorization', 'Bearer ${widget.accessToken}');
      final resp = await req.close();
      final body = await resp.transform(utf8.decoder).join();

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final map = (jsonDecode(body) as Map).cast<String, dynamic>();
        final items = (map['items'] as List? ?? [])
            .whereType<Map>()
            .map((m) => _CartItem.fromApi(m.cast<String, dynamic>()))
            .toList();
        final pricing = map['pricing'] is Map
            ? _CartPricing.fromApi((map['pricing'] as Map).cast<String, dynamic>())
            : null;
        _items = items;
        _pricing = pricing;
      } else {
        throw Exception('cart-load-failed');
      }
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _fetchAddresses() async {
    final client = HttpClient();
    try {
      final uri = Uri.parse('$_baseUrl${Api.addresses}');
      final req = await client.getUrl(uri);
      req.headers.set('Accept', 'application/json');
      req.headers.set('Authorization', 'Bearer ${widget.accessToken}');
      final resp = await req.close();
      final body = await resp.transform(utf8.decoder).join();

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final map = (jsonDecode(body) as Map).cast<String, dynamic>();
        final list = (map['items'] as List? ?? [])
            .whereType<Map>()
            .map((m) => _Address.fromApi(m.cast<String, dynamic>()))
            .toList();
        _addresses = list;
        // pick default
        final def = list.firstWhere(
          (a) => a.isDefault,
          orElse: () => list.isNotEmpty ? list.first : _Address.empty(),
        );
        _selectedAddressId = def.id.isNotEmpty ? def.id : null;
      } else {
        throw Exception('addresses-load-failed');
      }
    } finally {
      client.close(force: true);
    }
  }

  _Address? _selectedAddress() {
    if (_selectedAddressId == null) return null;
    try {
      return _addresses.firstWhere((a) => a.id == _selectedAddressId);
    } catch (_) {
      return null;
    }
  }

  String _formatCurrency(double amount, {String? currency}) {
    final cur = currency ?? _pricing?.currency ?? 'LKR';
    return '$cur ${amount.toStringAsFixed(2)}';
  }

  bool _validEmail(String s) {
    final v = s.trim();
    return v.contains('@') && v.split('@').last.contains('.');
  }

  Future<void> _placeOrder() async {
    if (_placing) return;
    if (_items.isEmpty) {
      AppSnackbars.info(context, 'Your cart is empty');
      return;
    }

    final email = _emailCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    if (email.isEmpty || !_validEmail(email)) {
      AppSnackbars.warning(context, 'Please enter a valid email.');
      return;
    }

    final addr = _selectedAddress();
    final payloadItems = _items
        .map((e) => {
              'product_id': e.productId,
              'qty': e.qty,
            })
        .toList();

    final shipping = addr == null
        ? <String, dynamic>{}
        : {
            'name': addr.name,
            'line1': addr.line1,
            'line2': addr.line2,
            'city': addr.city,
            'region': addr.region,
            'postal_code': addr.postalCode,
            'country': addr.country,
            'phone': addr.phone,
          };

    setState(() => _placing = true);

    final client = HttpClient();
    try {
      final uri = Uri.parse('$_baseUrl${Api.checkout}');
      final req = await client.postUrl(uri);
      req.headers.set('Accept', 'application/json');
      req.headers.set('Content-Type', 'application/json');
      // Optional auth header; backend supports optional JWT
      req.headers.set('Authorization', 'Bearer ${widget.accessToken}');
      req.add(utf8.encode(jsonEncode({
        'items': payloadItems,
        'email': email,
        'name': name,
        'shipping_address': shipping,
        'payment_method': 'cod',
      })));

      final resp = await req.close();
      final body = await resp.transform(utf8.decoder).join();

      if (!mounted) return;

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final map = (jsonDecode(body) as Map).cast<String, dynamic>();
        final orderNo = (map['order_no'] ?? '').toString();
        final status = (map['status'] ?? '').toString();

        AppSnackbars.success(
          context,
          'Order placed successfully',
          title: orderNo.isNotEmpty ? 'Order $orderNo ($status)' : 'Order created',
        );

        widget.onOrderPlaced?.call();
        // Return to previous screen with success flag
        Navigator.of(context).pop(true);
      } else {
        AppSnackbars.error(context, 'Checkout failed (${resp.statusCode}).');
      }
    } catch (_) {
      if (mounted) AppSnackbars.error(context, 'Network problem during checkout.');
    } finally {
      client.close(force: true);
      if (mounted) setState(() => _placing = false);
    }
  }

  void _manageAddresses() {
    AppSnackbars.info(context, 'Address management coming soon');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppBarPrimary(title: 'Order Review'),
      body: _loading
          ? const _OrderSkeleton()
          : _error != null
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: EmptyState(
                    icon: Icons.error_outline,
                    title: 'Something went wrong',
                    message: _error ?? 'Please try again.',
                    primaryActionLabel: 'Retry',
                    onPrimaryAction: _bootstrap,
                  ),
                )
              : _items.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: EmptyState(
                        icon: Icons.shopping_cart_outlined,
                        title: 'Your cart is empty',
                        message: 'Add items to proceed to checkout.',
                        primaryActionLabel: 'Back to Cart',
                        onPrimaryAction: () => Navigator.of(context).pop(),
                      ),
                    )
                  : Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _Section(
                                  title: 'Shipping address',
                                  action: TextButton(
                                    onPressed: _manageAddresses,
                                    child: const Text('Manage'),
                                  ),
                                  child: _addresses.isEmpty
                                      ? Text(
                                          'No addresses found. You can still place an order by entering your email; add an address later.',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                                        )
                                      : _AddressList(
                                          addresses: _addresses,
                                          selectedId: _selectedAddressId,
                                          onChanged: (id) => setState(() => _selectedAddressId = id),
                                        ),
                                ),
                                const SizedBox(height: 12),
                                _Section(
                                  title: 'Contact info',
                                  child: Column(
                                    children: [
                                      TextField(
                                        controller: _emailCtrl,
                                        keyboardType: TextInputType.emailAddress,
                                        textInputAction: TextInputAction.next,
                                        decoration: InputDecoration(
                                          labelText: 'Email (required)',
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      TextField(
                                        controller: _nameCtrl,
                                        textInputAction: TextInputAction.done,
                                        decoration: InputDecoration(
                                          labelText: 'Full name (optional)',
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _Section(
                                  title: 'Items',
                                  child: Column(
                                    children: _items
                                        .map((e) => _ItemRow(
                                              name: e.name,
                                              qty: e.qty,
                                              price: _formatCurrency(e.subtotal, currency: e.currency),
                                            ))
                                        .toList(),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _Section(
                                  title: 'Summary',
                                  child: _pricing == null
                                      ? const Text('Pricing unavailable.')
                                      : Column(
                                          children: [
                                            _KV('Subtotal', _formatCurrency(_pricing!.subtotal)),
                                            const SizedBox(height: 4),
                                            _KV('Tax', _formatCurrency(_pricing!.taxTotal)),
                                            const SizedBox(height: 4),
                                            _KV('Shipping', _formatCurrency(_pricing!.shippingTotal)),
                                            const Divider(height: 16),
                                            _KV('Total', _formatCurrency(_pricing!.total), isTotal: true),
                                          ],
                                        ),
                                ),
                                const SizedBox(height: 20),
                              ],
                            ),
                          ),
                        ),
                        _BottomBar(
                          totalText: _pricing == null ? '' : _formatCurrency(_pricing!.total),
                          placing: _placing,
                          onPlaceOrder: _placeOrder,
                        ),
                      ],
                    ),
    );
  }
}

// ============================================================================
// Models
// ============================================================================

class _CartItem {
  final String productId;
  final String name;
  final int qty;
  final double subtotal;
  final String currency;

  _CartItem({
    required this.productId,
    required this.name,
    required this.qty,
    required this.subtotal,
    required this.currency,
  });

  factory _CartItem.fromApi(Map<String, dynamic> m) {
    double _toD(v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0.0;
    int _toI(v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

    return _CartItem(
      productId: (m['product_id'] ?? '').toString(),
      name: (m['name'] ?? '').toString(),
      qty: _toI(m['qty']),
      subtotal: _toD(m['subtotal']),
      currency: (m['currency'] ?? 'LKR').toString(),
    );
  }
}

class _CartPricing {
  final String currency;
  final double subtotal;
  final double taxTotal;
  final double shippingTotal;
  final double total;

  _CartPricing({
    required this.currency,
    required this.subtotal,
    required this.taxTotal,
    required this.shippingTotal,
    required this.total,
  });

  factory _CartPricing.fromApi(Map<String, dynamic> m) {
    double _toD(v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0.0;
    return _CartPricing(
      currency: (m['currency'] ?? 'LKR').toString(),
      subtotal: _toD(m['subtotal']),
      taxTotal: _toD(m['tax_total']),
      shippingTotal: _toD(m['shipping_total']),
      total: _toD(m['total']),
    );
  }
}

class _Address {
  final String id;
  final String name;
  final String line1;
  final String line2;
  final String city;
  final String region;
  final String postalCode;
  final String country;
  final String phone;
  final bool isDefault;

  _Address({
    required this.id,
    required this.name,
    required this.line1,
    required this.line2,
    required this.city,
    required this.region,
    required this.postalCode,
    required this.country,
    required this.phone,
    required this.isDefault,
  });

  factory _Address.fromApi(Map<String, dynamic> m) {
    return _Address(
      id: (m['id'] ?? '').toString(),
      name: (m['name'] ?? '').toString(),
      line1: (m['line1'] ?? '').toString(),
      line2: (m['line2'] ?? '').toString(),
      city: (m['city'] ?? '').toString(),
      region: (m['region'] ?? '').toString(),
      postalCode: (m['postal_code'] ?? '').toString(),
      country: (m['country'] ?? 'LK').toString(),
      phone: (m['phone'] ?? '').toString(),
      isDefault: (m['is_default'] == true),
    );
  }

  static _Address empty() => _Address(
        id: '',
        name: '',
        line1: '',
        line2: '',
        city: '',
        region: '',
        postalCode: '',
        country: 'LK',
        phone: '',
        isDefault: false,
      );
}

// ============================================================================
// Widgets
// ============================================================================

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.child,
    this.action,
  });

  final String title;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              if (action != null) action!,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _AddressList extends StatelessWidget {
  const _AddressList({
    required this.addresses,
    required this.selectedId,
    required this.onChanged,
  });

  final List<_Address> addresses;
  final String? selectedId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: addresses.map((a) {
        final sel = a.id == selectedId;
        return InkWell(
          onTap: () => onChanged(a.id),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: sel ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outlineVariant,
                width: sel ? 2 : 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Radio<String>(
                  value: a.id,
                  groupValue: selectedId,
                  onChanged: (v) => onChanged(v ?? a.id),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _formatAddress(a),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                if (a.isDefault)
                  Padding(
                    padding: const EdgeInsets.only(left: 8, top: 2),
                    child: Chip(
                      label: const Text('Default'),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  String _formatAddress(_Address a) {
    final parts = <String>[
      if (a.name.isNotEmpty) a.name,
      if (a.line1.isNotEmpty) a.line1,
      if (a.line2.isNotEmpty) a.line2,
      [a.city, a.region].where((e) => e.isNotEmpty).join(', '),
      if (a.postalCode.isNotEmpty) a.postalCode,
      if (a.country.isNotEmpty) a.country,
      if (a.phone.isNotEmpty) '☎ ${a.phone}',
    ].where((e) => e.trim().isNotEmpty).toList();
    return parts.join('\n');
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.name,
    required this.qty,
    required this.price,
  });

  final String name;
  final int qty;
  final String price;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$name  ×$qty',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Text(price, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _KV extends StatelessWidget {
  const _KV(this.k, this.v, {this.isTotal = false});
  final String k;
  final String v;
  final bool isTotal;

  @override
  Widget build(BuildContext context) {
    final style = isTotal
        ? Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)
        : Theme.of(context).textTheme.bodyLarge;
    return Row(
      children: [
        Text(k, style: style),
        const Spacer(),
        Text(v, style: style),
      ],
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.totalText,
    required this.placing,
    required this.onPlaceOrder,
  });

  final String totalText;
  final bool placing;
  final VoidCallback onPlaceOrder;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border(top: BorderSide(color: cs.outlineVariant)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total', style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 2),
                  Text(
                    totalText.isEmpty ? '—' : totalText,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w900, color: cs.primary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 160,
              child: PrimaryButton(
                label: placing ? 'Placing…' : 'Place order',
                onPressed: placing ? null : onPlaceOrder,
                fullWidth: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderSkeleton extends StatelessWidget {
  const _OrderSkeleton();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget bar(double w, double h) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(6),
          ),
        );

    Widget box() => Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              bar(140, 16),
              const SizedBox(height: 10),
              bar(double.infinity, 14),
              const SizedBox(height: 6),
              bar(double.infinity, 14),
              const SizedBox(height: 6),
              bar(180, 14),
            ],
          ),
        );

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            itemCount: 4,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, __) => box(),
          ),
        ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(top: BorderSide(color: cs.outlineVariant)),
            ),
            child: Row(
              children: [
                Expanded(child: bar(double.infinity, 28)),
                const SizedBox(width: 10),
                bar(160, 48),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
