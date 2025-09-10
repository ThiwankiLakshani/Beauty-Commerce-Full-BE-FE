// lib/features/orders/screens/order_detail_screen.dart
//


import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_constants.dart';
import '../../../common/utils/snackbar.dart';
import '../../../common/widgets/app_bar_primary.dart';
import '../../../common/widgets/empty_state.dart';
import '../../../common/widgets/primary_button.dart';

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({
    super.key,
    required this.accessToken,
    required this.orderId,
    this.onCanceled, // optional callback after successful cancel
  });

  final String accessToken;
  final String orderId;
  final VoidCallback? onCanceled;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  bool _loading = true;
  String? _error;
  _Order? _order;

  String get _baseUrl {
    const fromEnv = String.fromEnvironment(Api.envBaseUrlKey, defaultValue: '');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (Platform.isIOS || Platform.isMacOS) return Api.defaultBaseUrlIosSimulator;
    return Api.defaultBaseUrlAndroidEmulator;
  }

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  // ---------------------------------------------------------------------------
  // Networking
  // ---------------------------------------------------------------------------

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final client = HttpClient();
    try {
      final uri = Uri.parse('$_baseUrl${Api.orders}/${widget.orderId}');
      final req = await client.getUrl(uri);
      req.headers.set('Accept', 'application/json');
      req.headers.set('Authorization', 'Bearer ${widget.accessToken}');
      final resp = await req.close();
      final body = await resp.transform(utf8.decoder).join();

      if (!mounted) return;

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final map = (jsonDecode(body) as Map).cast<String, dynamic>();
        setState(() {
          _order = _Order.fromApi(map);
          _loading = false;
        });
      } else if (resp.statusCode == 401) {
        setState(() {
          _error = 'Session expired. Please log in again.';
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Could not load order.';
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

  Future<void> _cancelOrder() async {
    if (_order == null) return;
    final st = _order!.status.toLowerCase();
    if (!(st == 'pending' || st == 'processing')) {
      AppSnackbars.warning(context, 'Order cannot be canceled in its current state.');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this order?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Keep order')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Cancel order')),
        ],
      ),
    );
    if (confirm != true) return;

    final client = HttpClient();
    try {
      final uri = Uri.parse('$_baseUrl${Api.orders}/${widget.orderId}/cancel');
      final req = await client.postUrl(uri);
      req.headers.set('Accept', 'application/json');
      req.headers.set('Authorization', 'Bearer ${widget.accessToken}');
      final resp = await req.close();
      await resp.transform(utf8.decoder).join();

      if (!mounted) return;

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        AppSnackbars.success(context, 'Order canceled');
        await _fetch(); // reflect updated status
        widget.onCanceled?.call();
      } else if (resp.statusCode == 401) {
        AppSnackbars.warning(context, 'Session expired. Please log in again.');
      } else {
        AppSnackbars.error(context, 'Cancel failed (${resp.statusCode}).');
      }
    } catch (_) {
      if (mounted) AppSnackbars.error(context, 'Network problem. Please try again.');
    } finally {
      client.close(force: true);
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _formatCurrency(double amount, {String? currency}) {
    final cur = currency ?? _order?.currency ?? 'LKR';
    return '$cur ${amount.toStringAsFixed(2)}';
  }

  String _fmtDate(DateTime? dt) {
    if (dt == null) return '—';
    final local = dt.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  Color _statusColor(String st, ColorScheme cs) {
    switch (st.toLowerCase()) {
      case 'paid':
      case 'completed':
      case 'shipped':
      case 'processing':
        return cs.primary;
      case 'pending':
        return cs.tertiary;
      case 'canceled':
      case 'refunded':
        return cs.error;
      default:
        return cs.onSurfaceVariant;
    }
  }

  bool get _canCancel {
    final st = _order?.status.toLowerCase() ?? '';
    return st == 'pending' || st == 'processing';
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: const AppBarPrimary(title: 'Order details'),
      bottomNavigationBar: (_order != null)
          ? SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    // Support → navigate to Settings (adjust if you add a dedicated Support route)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => context.pushNamed('settings'),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Support'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Cancel (if allowed) or Reorder (go to Cart)
                    Expanded(
                      child: PrimaryButton(
                        label: _canCancel ? 'Cancel order' : 'Reorder',
                        onPressed: _canCancel
                            ? _cancelOrder
                            : () => context.pushNamed('cart'),
                        fullWidth: true,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
      body: _loading
          ? const _DetailSkeleton()
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
              : _order == null
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: EmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'Order not found',
                        message: 'This order may have been removed.',
                      ),
                    )
                  : RefreshIndicator(
                      color: cs.primary,
                      onRefresh: _fetch,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                        children: [
                          _HeaderCard(
                            orderNo: _order!.orderNo,
                            status: _order!.status,
                            createdAt: _order!.createdAt,
                            statusColor: _statusColor(_order!.status, cs),
                            paymentMethod: _order!.paymentMethod,
                          ),
                          const SizedBox(height: 12),
                          _ItemsCard(
                            items: _order!.items,
                            formatPrice: (p, c) => _formatCurrency(p, currency: c),
                          ),
                          const SizedBox(height: 12),
                          _AddressCard(address: _order!.shippingAddress),
                          const SizedBox(height: 12),
                          _TotalsCard(
                            subtotal: _formatCurrency(_order!.subtotal, currency: _order!.currency),
                            shipping:
                                _formatCurrency(_order!.shippingTotal, currency: _order!.currency),
                            tax: _formatCurrency(_order!.taxTotal, currency: _order!.currency),
                            total: _formatCurrency(_order!.total, currency: _order!.currency),
                          ),
                        ],
                      ),
                    ),
    );
  }
}

// ============================================================================
// Models
// ============================================================================

class _Order {
  final String id;
  final String orderNo;
  final String status;
  final double total;
  final String currency;
  final DateTime? createdAt;
  final double subtotal;
  final double shippingTotal;
  final double taxTotal;
  final String paymentMethod;
  final List<_OrderItem> items;
  final _ShippingAddress shippingAddress;

  _Order({
    required this.id,
    required this.orderNo,
    required this.status,
    required this.total,
    required this.currency,
    required this.createdAt,
    required this.subtotal,
    required this.shippingTotal,
    required this.taxTotal,
    required this.paymentMethod,
    required this.items,
    required this.shippingAddress,
  });

  factory _Order.fromApi(Map<String, dynamic> m) {
    double _toD(v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0.0;

    DateTime? _toDt(v) {
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    final items = (m['items'] as List? ?? [])
        .whereType<Map>()
        .map((e) => _OrderItem.fromApi(e.cast<String, dynamic>()))
        .toList();

    return _Order(
      id: (m['id'] ?? '').toString(),
      orderNo: (m['order_no'] ?? '').toString(),
      status: (m['status'] ?? '').toString(),
      total: _toD(m['total']),
      currency: (m['currency'] ?? 'LKR').toString(),
      createdAt: _toDt(m['created_at']),
      subtotal: _toD(m['subtotal']),
      shippingTotal: _toD(m['shipping_total']),
      taxTotal: _toD(m['tax_total']),
      paymentMethod: (m['payment_method'] ?? '').toString(),
      items: items,
      shippingAddress: _ShippingAddress.fromApi(
        (m['shipping_address'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
    );
  }
}

class _OrderItem {
  final String name;
  final String sku;
  final int qty;
  final double price;
  final double subtotal;
  final String currency;
  final String? heroImage;

  _OrderItem({
    required this.name,
    required this.sku,
    required this.qty,
    required this.price,
    required this.subtotal,
    required this.currency,
    required this.heroImage,
  });

  factory _OrderItem.fromApi(Map<String, dynamic> m) {
    double _toD(v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0.0;
    int _toI(v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

    return _OrderItem(
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

class _ShippingAddress {
  final String name;
  final String line1;
  final String line2;
  final String city;
  final String region;
  final String postalCode;
  final String country;
  final String phone;

  const _ShippingAddress({
    required this.name,
    required this.line1,
    required this.line2,
    required this.city,
    required this.region,
    required this.postalCode,
    required this.country,
    required this.phone,
  });

  factory _ShippingAddress.fromApi(Map<String, dynamic> m) {
    return _ShippingAddress(
      name: (m['name'] ?? '').toString(),
      line1: (m['line1'] ?? '').toString(),
      line2: (m['line2'] ?? '').toString(),
      city: (m['city'] ?? '').toString(),
      region: (m['region'] ?? '').toString(),
      postalCode: (m['postal_code'] ?? '').toString(),
      country: (m['country'] ?? 'LK').toString(),
      phone: (m['phone'] ?? '').toString(),
    );
  }
}

// ============================================================================
// UI Pieces
// ============================================================================

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.orderNo,
    required this.status,
    required this.statusColor,
    required this.paymentMethod,
    this.createdAt,
  });

  final String orderNo;
  final String status;
  final Color statusColor;
  final String paymentMethod;
  final DateTime? createdAt;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: cs.primary.withOpacity(0.12),
            child: Icon(Icons.receipt_long_outlined, color: cs.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  orderNo.isEmpty ? 'Order' : 'Order $orderNo',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: statusColor),
                      ),
                      child: Text(
                        status.isEmpty ? 'processing' : status,
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(color: statusColor, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const Spacer(),
                    if (createdAt != null)
                      Text(
                        _fmtDate(createdAt!),
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.payments_outlined, color: cs.onSurfaceVariant, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      paymentMethod.isEmpty ? 'Payment: —' : 'Payment: $paymentMethod',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }
}

class _ItemsCard extends StatelessWidget {
  const _ItemsCard({
    required this.items,
    required this.formatPrice,
  });

  final List<_OrderItem> items;
  final String Function(double price, String currency) formatPrice;

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
          Text('Items', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...items.map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: cs.outlineVariant),
                      ),
                      child: (e.heroImage != null && e.heroImage!.isNotEmpty)
                          ? Image.network(
                              e.heroImage!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  Icon(Icons.broken_image_outlined, color: cs.onSurfaceVariant),
                            )
                          : Icon(Icons.image_outlined, color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${e.name}  •  ${e.sku.isEmpty ? '—' : e.sku}  ×${e.qty}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style:
                            Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formatPrice(e.subtotal, e.currency),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({required this.address});
  final _ShippingAddress address;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    String _formatAddress(_ShippingAddress a) {
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

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.location_on_outlined, color: cs.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Shipping address', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(
                  _formatAddress(address),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({
    required this.subtotal,
    required this.shipping,
    required this.tax,
    required this.total,
  });

  final String subtotal;
  final String shipping;
  final String tax;
  final String total;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget row(String k, String v, {bool strong = false}) {
      final style = strong
          ? Theme.of(context).textTheme.titleMedium?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.w900,
              )
          : Theme.of(context).textTheme.bodyMedium;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Text(k),
            const Spacer(),
            Text(v, style: style),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        children: [
          row('Subtotal', subtotal),
          row('Shipping', shipping),
          row('Tax', tax),
          const Divider(height: 18),
          row('Total', total, strong: true),
        ],
      ),
    );
  }
}

// ============================================================================
// Skeleton
// ============================================================================

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

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

    Widget box({double h = 100}) => Container(
          height: h,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Row(
            children: [
              bar(44, 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    bar(160, 16),
                    const SizedBox(height: 8),
                    bar(double.infinity, 14),
                    const SizedBox(height: 6),
                    bar(180, 14),
                  ],
                ),
              ),
            ],
          ),
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        box(h: 120),
        const SizedBox(height: 12),
        box(h: 140),
        const SizedBox(height: 12),
        box(h: 110),
        const SizedBox(height: 12),
        box(h: 110),
      ],
    );
  }
}
