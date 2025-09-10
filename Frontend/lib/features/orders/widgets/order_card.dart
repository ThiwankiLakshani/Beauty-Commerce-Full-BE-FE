// lib/features/orders/widgets/order_card.dart
//


import 'package:flutter/material.dart';

class OrderCardData {
  final String id;
  final String orderNo;
  final String status;
  final double total;
  final String currency;
  final DateTime? createdAt;

  const OrderCardData({
    required this.id,
    required this.orderNo,
    required this.status,
    required this.total,
    required this.currency,
    required this.createdAt,
  });

  factory OrderCardData.fromApi(Map<String, dynamic> m) {
    double _toD(v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0.0;

    DateTime? _toDt(v) {
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    return OrderCardData(
      id: (m['id'] ?? '').toString(),
      orderNo: (m['order_no'] ?? '').toString(),
      status: (m['status'] ?? '').toString(),
      total: _toD(m['total']),
      currency: (m['currency'] ?? 'LKR').toString(),
      createdAt: _toDt(m['created_at']),
    );
  }
}

class OrderCard extends StatelessWidget {
  const OrderCard({
    super.key,
    required this.data,
    this.onTap,
    this.dense = false,
    this.showChevron = true,
  });

  final OrderCardData data;
  final VoidCallback? onTap;
  final bool dense;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final borderRadius = BorderRadius.circular(14);
    final padding = dense ? const EdgeInsets.all(10) : const EdgeInsets.all(12);

    return InkWell(
      onTap: onTap,
      borderRadius: borderRadius,
      child: Ink(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: borderRadius,
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Padding(
          padding: padding,
          child: Row(
            children: [
              CircleAvatar(
                radius: dense ? 18 : 20,
                backgroundColor: cs.primary.withOpacity(0.12),
                child: Icon(Icons.shopping_bag_outlined, color: cs.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Content(
                  title: data.orderNo.isEmpty ? 'Order' : 'Order ${data.orderNo}',
                  status: data.status,
                  createdAt: data.createdAt,
                ),
              ),
              const SizedBox(width: 10),
              _TotalAndChevron(
                totalText: _formatCurrency(data.total, data.currency),
                showChevron: showChevron,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatCurrency(double amount, String currency) {
    final a = amount.toStringAsFixed(2);
    return '$currency $a';
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.title,
    required this.status,
    required this.createdAt,
  });

  final String title;
  final String status;
  final DateTime? createdAt;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = _statusColor(status, cs);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title + Status chip
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: color),
              ),
              child: Text(
                status.isEmpty ? 'processing' : status,
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: color, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // Date
        Text(
          _fmtDate(createdAt),
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }

  static String _fmtDate(DateTime? dt) {
    if (dt == null) return '—';
    final local = dt.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  static Color _statusColor(String st, ColorScheme cs) {
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
}

class _TotalAndChevron extends StatelessWidget {
  const _TotalAndChevron({
    required this.totalText,
    required this.showChevron,
  });

  final String totalText;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          totalText,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 6),
        if (showChevron)
          Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
      ],
    );
  }
}
