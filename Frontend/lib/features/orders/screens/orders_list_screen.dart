// lib/features/orders/screens/orders_list_screen.dart


import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_constants.dart';
import '../../../common/widgets/app_bar_primary.dart';
import '../../../common/widgets/empty_state.dart';

class OrdersListScreen extends StatefulWidget {
  const OrdersListScreen({
    super.key,
    required this.accessToken,
    this.onOpenOrder,
  });

  /// JWT token for authenticated requests.
  final String accessToken;

  /// Optional callback when user taps a specific order.
  /// If not provided, defaults to context.pushNamed('order_detail', pathParameters:{'id': order.id})
  final void Function(_OrderListItem order)? onOpenOrder;

  @override
  State<OrdersListScreen> createState() => _OrdersListScreenState();
}

class _OrdersListScreenState extends State<OrdersListScreen> {
  bool _loading = true;
  bool _unauthorized = false;
  String? _error;

  List<_OrderListItem> _items = const [];

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
      _unauthorized = false;
      _error = null;
    });

    final client = HttpClient();
    try {
      final uri = Uri.parse('$_baseUrl${Api.orders}');
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
            .map((m) => _OrderListItem.fromApi(m.cast<String, dynamic>()))
            .toList();

        setState(() {
          _items = list;
          _loading = false;
        });
      } else if (resp.statusCode == 401) {
        setState(() {
          _unauthorized = true;
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Could not load your orders.';
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

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _formatCurrency(double amount, {String? currency}) {
    final cur = currency ?? 'LKR';
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

  void _openOrder(_OrderListItem o) {
    if (widget.onOpenOrder != null) {
      widget.onOpenOrder!(o);
    } else {
      // Default: navigate to order detail screen
      context.pushNamed('order_detail', pathParameters: {'id': o.id});
    }
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: const AppBarPrimary(title: 'My orders'),
      body: _loading
          ? const _OrdersSkeleton()
          : _unauthorized
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: EmptyState(
                    icon: Icons.lock_outline,
                    title: 'Please sign in',
                    message: 'Your session has expired or is invalid.',
                    primaryActionLabel: 'Go to login',
                    onPrimaryAction: () => context.goNamed('login'),
                  ),
                )
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
                            icon: Icons.receipt_long_outlined,
                            title: 'No orders yet',
                            message: 'When you place orders, they’ll show up here.',
                            primaryActionLabel: 'Start shopping',
                            onPrimaryAction: () => context.goNamed('home'),
                          ),
                        )
                      : RefreshIndicator(
                          color: cs.primary,
                          onRefresh: _fetch,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                            itemCount: _items.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (_, i) {
                              final o = _items[i];
                              final color = _statusColor(o.status, cs);
                              return InkWell(
                                onTap: () => _openOrder(o),
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: cs.surface,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: cs.outlineVariant),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundColor: cs.primary.withOpacity(0.12),
                                        child: Icon(Icons.shopping_bag_outlined, color: cs.primary),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            // Title row
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    o.orderNo.isEmpty
                                                        ? 'Order'
                                                        : 'Order ${o.orderNo}',
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .titleSmall
                                                        ?.copyWith(fontWeight: FontWeight.w800),
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 10, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: color.withOpacity(0.12),
                                                    borderRadius: BorderRadius.circular(999),
                                                    border: Border.all(color: color),
                                                  ),
                                                  child: Text(
                                                    o.status.isEmpty ? 'processing' : o.status,
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .labelMedium
                                                        ?.copyWith(
                                                            color: color,
                                                            fontWeight: FontWeight.w700),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            // Date row
                                            Text(
                                              _fmtDate(o.createdAt),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(color: cs.onSurfaceVariant),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      // Total
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            _formatCurrency(o.total, currency: o.currency),
                                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                                  color: cs.primary,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                          ),
                                          const SizedBox(height: 6),
                                          Icon(Icons.chevron_right_rounded,
                                              color: cs.onSurfaceVariant),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
    );
  }
}

// ============================================================================
// Model
// ============================================================================

class _OrderListItem {
  final String id;
  final String orderNo;
  final String status;
  final double total;
  final String currency;
  final DateTime? createdAt;

  _OrderListItem({
    required this.id,
    required this.orderNo,
    required this.status,
    required this.total,
    required this.currency,
    required this.createdAt,
  });

  factory _OrderListItem.fromApi(Map<String, dynamic> m) {
    double _toD(v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0.0;

    DateTime? _toDt(v) {
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    return _OrderListItem(
      id: (m['id'] ?? '').toString(),
      orderNo: (m['order_no'] ?? '').toString(),
      status: (m['status'] ?? '').toString(),
      total: _toD(m['total']),
      currency: (m['currency'] ?? 'LKR').toString(),
      createdAt: _toDt(m['created_at']),
    );
  }
}

// ============================================================================
// Skeleton
// ============================================================================

class _OrdersSkeleton extends StatelessWidget {
  const _OrdersSkeleton();

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

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, __) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(
          children: [
            bar(40, 40),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  bar(180, 16),
                  const SizedBox(height: 6),
                  bar(120, 14),
                ],
              ),
            ),
            const SizedBox(width: 10),
            bar(90, 18),
          ],
        ),
      ),
    );
  }
}
