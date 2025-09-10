// lib/features/orders/widgets/status_chip.dart
//


import 'package:flutter/material.dart';

class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.status,
    this.dense = false,
    this.uppercase = false,
  });

  /// Raw status text (e.g., "processing", "paid", "canceled").
  final String status;

  /// Slightly smaller paddings when true.
  final bool dense;

  /// Convert label to uppercase for stronger emphasis.
  final bool uppercase;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final raw = status.trim();
    final color = colorForStatus(raw, cs);

    final label = raw.isEmpty ? 'processing' : raw;
    final text = uppercase ? label.toUpperCase() : label;

    final pad = dense
        ? const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5)
        : const EdgeInsets.symmetric(horizontal: 10, vertical: 4);

    return Semantics(
      label: 'Order status: $label',
      child: Container(
        padding: pad,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color),
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context)
              .textTheme
              .labelMedium
              ?.copyWith(color: color, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  /// Public helper to reuse color mapping elsewhere.
  static Color colorForStatus(String status, ColorScheme cs) {
    switch (status.toLowerCase()) {
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
