// lib/features/cart/screens/order_confirm_screen.dart
//


import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../app/app_constants.dart';
import '../../../common/utils/snackbar.dart';
import '../../../common/widgets/app_bar_primary.dart';
import '../../../common/widgets/empty_state.dart';
import '../../../common/widgets/primary_button.dart';

class OrderConfirmScreen extends StatefulWidget {
  const OrderConfirmScreen({
    super.key,
    this.accessToken,
    this.orderId,
    this.orderNo,
    this.status,
    this.total,
    this.currency,
    this.createdAt,
    this.onViewOrders,
    this.onContinueShopping,
    this.onViewOrder, // if you have a dedicated order-detail route
  });

  /// JWT; required only if you want to fetch details via `orderId`.
  final String? accessToken;

  /// If provided (with accessToken), details will be fetched.
  final String? orderId;

  /// Optional, for generic confirmation (shown immediately).
  final String? orderNo;

  /// Optional status hint (shown if fetch is skipped).
  final String? status;

  /// Optional totals for generic confirmation (currency defaults to LKR).
  final double? total;
  final String? currency;

  /// Optional timestamp for generic confirmation.
  final DateTime? createdAt;

  /// Optional navigation callbacks.
  final VoidCallback? onViewOrders;
  final VoidCallback? onContinueShopping;
  final VoidCallback? onViewOrder;

  @override
  State<OrderConfirmScreen> createState() => _OrderConfirmScreenState();
}

class _OrderConfirmScreenState extends State<OrderConfirmScreen> {
  bool _loading = false;
  String? _error;

  _OrderDetail? _order;

  bool get _hasToken => (widget.accessToken ?? '').isNotEmpty;
  bool get _canFetch => _hasToken && (widget.orderId ?? '').isNotEmpty;

  String get _baseUrl {
    const fromEnv = String.fromEnvironment(Api.envBaseUrlKey, defaultValue: '');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (Platform.isIOS || Platform.isMacOS) return Api.defaultBaseUrlIosSimulator;
    return Api.defaultBaseUrlAndroidEmulator;
  }

  @override
  void initState() {
    super.initState();
    // If we can fetch full details, do it.
    if (_canFetch) {
      _fetch();
    } else {
      // Prepare a lightweight order summary from provided hints.
      _order = _OrderDetail(
        id: widget.orderId ?? '',
        orderNo: widget.orderNo ?? '',
        status: (widget.status ?? 'processing').toLowerCase(),
        total: widget.total ?? 0.0,
        currency: widget.currency ?? 'LKR',
        createdAt: widget.createdAt,
        items: const [],
      );
    }
  }

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
        _order = _OrderDetail.fromApi(map);
        setState(() => _loading = false);
      } else if (resp.statusCode == 401) {
        setState(() {
          _loading = false;
          _error = 'Session expired. Please log in again.';
        });
      } else {
        setState(() {
          _loading = false;
          _error = 'Could not load order details.';
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Network problem. Please try again.';
      });
    } finally {
      client.close(force: true);
    }
  }

  String _formatCurrency(double amount, {String? currency}) {
    final cur = currency ?? _order?.currency ?? widget.currency ?? 'LKR';
    return '$cur ${amount.toStringAsFixed(2)}';
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

  void _handleViewOrders() {
    if (widget.onViewOrders != null) {
      widget.onViewOrders!();
    } else {
      AppSnackbars.info(context, 'Open orders list');
    }
  }

  void _handleContinue() {
    if (widget.onContinueShopping != null) {
      widget.onContinueShopping!();
    } else {
      AppSnackbars.info(context, 'Continue shopping');
    }
  }

  void _handleTrackOrder() {
    if (widget.onViewOrder != null) {
      widget.onViewOrder!();
    } else {
      final no = _order?.orderNo;
      AppSnackbars.info(context, no == null || no.isEmpty ? 'Open order details' : 'Open $no');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: const AppBarPrimary(title: 'Order confirmed'),
      body: _loading
          ? const _ConfirmSkeleton()
          : _error != null
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: EmptyState(
                    icon: Icons.error_outline,
                    title: 'Couldn’t load your order',
                    message: _error ?? 'Please try again.',
                    primaryActionLabel: 'Retry',
                    onPrimaryAction: _fetch,
                  ),
                )
              : (_order == null)
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: EmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'Thank you!',
                        message: 'Your order has been placed.',
                        primaryActionLabel: 'View my orders',
                        onPrimaryAction: _handleViewOrders,
                        secondaryActionLabel: 'Continue shopping',
                        onSecondaryAction: _handleContinue,
                      ),
                    )
                  : Column(
                      children: [
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                            children: [
                              _HeaderCard(
                                orderNo: _order!.orderNo,
                                status: _order!.status,
                                statusColor: _statusColor(_order!.status, cs),
                                createdAt: _order!.createdAt,
                              ),
                              const SizedBox(height: 12),
                              if (_order!.items.isNotEmpty)
                                _ItemsCard(
                                  items: _order!.items,
                                  formatPrice: (p, c) => _formatCurrency(p, currency: c),
                                ),
                              if (_order!.items.isNotEmpty) const SizedBox(height: 12),
                              _SummaryCard(
                                totalText: _formatCurrency(_order!.total, currency: _order!.currency),
                              ),
                            ],
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
                                OutlinedButton(
                                  onPressed: _handleViewOrders,
                                  style: OutlinedButton.styleFrom(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  ),
                                  child: const Text('My orders'),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: PrimaryButton(
                                    label: 'Track order',
                                    onPressed: _handleTrackOrder,
                                    fullWidth: true,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                OutlinedButton(
                                  onPressed: _handleContinue,
                                  style: OutlinedButton.styleFrom(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  ),
                                  child: const Text('Shop more'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
    );
  }
}

// ============================================================================
// Models
// ============================================================================

class _OrderDetail {
  final String id;
  final String orderNo;
  final String status;
  final double total;
  final String currency;
  final DateTime? createdAt;
  final List<_OrderItem> items;

  _OrderDetail({
    required this.id,
    required this.orderNo,
    required this.status,
    required this.total,
    required this.currency,
    required this.createdAt,
    required this.items,
  });

  factory _OrderDetail.fromApi(Map<String, dynamic> m) {
    double _toD(v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0.0;

    DateTime? _toDt(v) {
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    final items = (m['items'] as List? ?? [])
        .whereType<Map>()
        .map((e) => _OrderItem.fromApi(e.cast<String, dynamic>()))
        .toList();

    return _OrderDetail(
      id: (m['id'] ?? '').toString(),
      orderNo: (m['order_no'] ?? '').toString(),
      status: (m['status'] ?? '').toString(),
      total: _toD(m['total']),
      currency: (m['currency'] ?? 'LKR').toString(),
      createdAt: _toDt(m['created_at']),
      items: items,
    );
  }
}

class _OrderItem {
  final String name;
  final int qty;
  final double subtotal;
  final String currency;
  final String? heroImage;

  _OrderItem({
    required this.name,
    required this.qty,
    required this.subtotal,
    required this.currency,
    required this.heroImage,
  });

  factory _OrderItem.fromApi(Map<String, dynamic> m) {
    double _toD(v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0.0;
    int _toI(v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

    return _OrderItem(
      name: (m['name'] ?? '').toString(),
      qty: _toI(m['qty']),
      subtotal: _toD(m['subtotal']),
      currency: (m['currency'] ?? 'LKR').toString(),
      heroImage: (m['hero_image'] as String?)?.toString(),
    );
  }
}

// ============================================================================
// UI pieces
// ============================================================================

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.orderNo,
    required this.status,
    required this.statusColor,
    this.createdAt,
  });

  final String orderNo;
  final String status;
  final Color statusColor;
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
            child: Icon(Icons.check_rounded, color: cs.primary, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Thank you!', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(
                  orderNo.isEmpty ? 'Your order has been placed.' : 'Order $orderNo has been placed.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime dt) {
    // Minimal, locale-agnostic date for display (YYYY-MM-DD HH:MM)
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
                        '${e.name}  ×${e.qty}',
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

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.totalText});
  final String totalText;

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
      child: Row(
        children: [
          Icon(Icons.receipt_long_outlined, color: cs.primary),
          const SizedBox(width: 10),
          Text('Total paid / due', style: Theme.of(context).textTheme.titleMedium),
          const Spacer(),
          Text(
            totalText,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(color: cs.primary, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _ConfirmSkeleton extends StatelessWidget {
  const _ConfirmSkeleton();

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

    Widget box({double h = 90}) => Container(
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
        box(h: 110),
        const SizedBox(height: 12),
        box(),
        const SizedBox(height: 12),
        box(h: 80),
      ],
    );
  }
}
