// lib/features/product/widgets/rating_bar.dart
//


import 'package:flutter/material.dart';

/// Display-only rating widget with 0–5 stars and half-star support.
class RatingBar extends StatelessWidget {
  const RatingBar({
    super.key,
    required this.value,
    this.count,
    this.size = 18.0,
    this.starSpacing = 2.0,
    this.color,
    this.emptyColor,
    this.showValue = true,
    this.showCount = true,
    this.valueDecimals = 1,
    this.textStyle,
  });

  /// Average rating value (0.0 .. 5.0). Values are clamped into range.
  final double value;

  /// Optional total number of ratings to display, e.g. “(128)”.
  final int? count;

  /// Star icon size.
  final double size;

  /// Spacing between star icons.
  final double starSpacing;

  /// Filled/half star color. Defaults to Theme.primary.
  final Color? color;

  /// Empty star color. Defaults to Theme.colorScheme.outlineVariant.
  final Color? emptyColor;

  /// Whether to show the numeric value (e.g. “4.3”) after stars.
  final bool showValue;

  /// Whether to show “(count)”. If null [count] is not provided, nothing shows.
  final bool showCount;

  /// Number of decimals for numeric value.
  final int valueDecimals;

  /// Style for the trailing value/count text.
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cFilled = color ?? cs.primary;
    final cEmpty = emptyColor ?? cs.outlineVariant;

    final v = value.clamp(0.0, 5.0);
    final full = v.floor();
    final half = (v - full) >= 0.5;
    final trailing = <Widget>[];

    if (showValue) {
      trailing.add(Text(
        v.toStringAsFixed(valueDecimals),
        style: (textStyle ?? Theme.of(context).textTheme.bodySmall)
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ));
    }

    if (showCount && count != null) {
      if (trailing.isNotEmpty) trailing.add(const SizedBox(width: 4));
      trailing.add(Text(
        '(${count!})',
        style: (textStyle ?? Theme.of(context).textTheme.bodySmall)
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ));
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Stars
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (i) {
            IconData icon;
            if (i < full) {
              icon = Icons.star_rounded;
            } else if (i == full && half) {
              icon = Icons.star_half_rounded;
            } else {
              icon = Icons.star_border_rounded;
            }
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: starSpacing / 2),
              child: Icon(icon, size: size, color: (icon == Icons.star_border_rounded) ? cEmpty : cFilled),
            );
          }),
        ),
        if (trailing.isNotEmpty) const SizedBox(width: 6),
        ...trailing,
      ],
    );
  }
}

/// Interactive 1–5 star picker. Optionally allows clearing to 0 by tapping the
/// same selected star again.
class RatingPicker extends StatelessWidget {
  const RatingPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 24.0,
    this.starSpacing = 4.0,
    this.color,
    this.emptyColor,
    this.allowClear = true,
    this.semanticLabel,
  });

  /// Current selected rating. Expected 0..5 (0 = no rating).
  final int value;

  /// Callback when user selects a value (0..5).
  final ValueChanged<int> onChanged;

  /// Star size.
  final double size;

  /// Spacing between stars.
  final double starSpacing;

  /// Filled star color.
  final Color? color;

  /// Empty star color.
  final Color? emptyColor;

  /// If true, tapping the same star again clears to 0.
  final bool allowClear;

  /// Optional semantics label for accessibility.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cFilled = color ?? cs.primary;
    final cEmpty = emptyColor ?? cs.outline;

    final v = value.clamp(0, 5);

    return Semantics(
      label: semanticLabel ?? 'Rating',
      value: '$v of 5',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (i) {
          final idx = i + 1;
          final filled = idx <= v;
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: starSpacing / 2),
            child: InkWell(
              onTap: () {
                final next = (allowClear && v == idx) ? 0 : idx;
                onChanged(next);
              },
              borderRadius: BorderRadius.circular(6),
              child: Icon(
                filled ? Icons.star_rounded : Icons.star_border_rounded,
                color: filled ? cFilled : cEmpty,
                size: size,
              ),
            ),
          );
        }),
      ),
    );
  }
}
