// lib/features/cart/screens/order_success_screen.dart
//


import 'package:flutter/material.dart';

import '../../../common/utils/snackbar.dart';
import '../../../common/widgets/app_bar_primary.dart';
import '../../../common/widgets/primary_button.dart';

class OrderSuccessScreen extends StatelessWidget {
  const OrderSuccessScreen({
    super.key,
    this.orderNo,
    this.total,
    this.currency,
    this.status,
    this.createdAt,
    this.onViewOrders,
    this.onViewOrder,
    this.onContinueShopping,
  });

  /// Optional order number to show (e.g., "BC-20250906-1A2B3C").
  final String? orderNo;

  /// Optional total paid/due.
  final double? total;

  /// Currency code (e.g., "LKR"). Defaults to "LKR" if null.
  final String? currency;

  /// Optional current order status (e.g., "processing", "paid", "shipped").
  final String? status;

  /// Optional order timestamp.
  final DateTime? createdAt;

  /// Optional actions: wire these to your router.
  final VoidCallback? onViewOrders;
  final VoidCallback? onViewOrder;
  final VoidCallback? onContinueShopping;

  String _formatCurrency(double? amount, {String? currency}) {
    final cur = (currency ?? 'LKR');
    if (amount == null) return '$cur —';
    return '$cur ${amount.toStringAsFixed(2)}';
  }

  String _fmtDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  Color _statusColor(BuildContext context, String st) {
    final cs = Theme.of(context).colorScheme;
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

  void _defaultInfo(BuildContext context, String msg) {
    AppSnackbars.info(context, msg);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final st = (status ?? 'processing').toString();

    return Scaffold(
      appBar: const AppBarPrimary(title: 'Order success'),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: cs.primary.withOpacity(0.12),
                        child: Icon(Icons.check_rounded, color: cs.primary, size: 30),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Thank you!', style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                            )),
                            const SizedBox(height: 6),
                            Text(
                              orderNo == null || orderNo!.isEmpty
                                  ? 'Your order has been placed.'
                                  : 'Order $orderNo has been placed.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                _StatusChip(
                                  label: st.isEmpty ? 'processing' : st,
                                  color: _statusColor(context, st),
                                ),
                                const Spacer(),
                                if (createdAt != null)
                                  Text(
                                    _fmtDate(createdAt!),
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(color: cs.onSurfaceVariant),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Summary
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.receipt_long_outlined, color: cs.primary),
                      const SizedBox(width: 10),
                      Text('Total', style: Theme.of(context).textTheme.titleMedium),
                      const Spacer(),
                      Text(
                        _formatCurrency(total, currency: currency),
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(color: cs.primary, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Reference info
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: Column(
                    children: [
                      _KV(
                        'Order number',
                        (orderNo == null || orderNo!.isEmpty) ? '—' : orderNo!,
                      ),
                      const SizedBox(height: 8),
                      _KV('Status', st.isEmpty ? 'processing' : st),
                      if (createdAt != null) ...[
                        const SizedBox(height: 8),
                        _KV('Date', _fmtDate(createdAt!)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Bottom actions
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
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onViewOrders ?? () => _defaultInfo(context, 'Open orders list'),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('My orders'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: PrimaryButton(
                      label: 'Track order',
                      onPressed: onViewOrder ?? () => _defaultInfo(context, 'Open order details'),
                      fullWidth: true,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onContinueShopping ?? () => _defaultInfo(context, 'Continue shopping'),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Shop more'),
                    ),
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

// -----------------------------------------------------------------------------
// UI helpers
// -----------------------------------------------------------------------------

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelMedium
            ?.copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _KV extends StatelessWidget {
  const _KV(this.k, this.v);

  final String k;
  final String v;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(k, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        const Spacer(),
        Text(v, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}
