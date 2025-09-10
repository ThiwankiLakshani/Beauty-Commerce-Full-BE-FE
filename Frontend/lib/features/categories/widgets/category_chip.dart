// lib/features/categories/widgets/category_chip.dart
//


import 'package:flutter/material.dart';

class CategoryChip extends StatelessWidget {
  const CategoryChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onSelected,
    this.icon,
    this.count,
    this.enabled = true,
    this.dense = false,
    this.showCheckmark = false,
    this.tooltip,
  });

  /// Chip text.
  final String label;

  /// Whether the chip is selected.
  final bool selected;

  /// Callback when the chip is toggled.
  final ValueChanged<bool>? onSelected;

  /// Optional leading icon.
  final IconData? icon;

  /// Optional trailing count badge (e.g., number of items).
  final int? count;

  /// Whether the chip is enabled.
  final bool enabled;

  /// Compact spacing and height.
  final bool dense;

  /// Whether to show a checkmark when selected.
  final bool showCheckmark;

  /// Optional tooltip shown on long-press / hover.
  final String? tooltip;

  /// Convenience compact constructor.
  const CategoryChip.small({
    super.key,
    required this.label,
    this.selected = false,
    this.onSelected,
    this.icon,
    this.count,
    this.enabled = true,
    this.showCheckmark = false,
    this.tooltip,
  }) : dense = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Colors & styles (Material 3-friendly)
    final bg = selected
        ? cs.primaryContainer
        : (theme.inputDecorationTheme.fillColor ?? cs.surface);
    final fg = selected ? cs.onPrimaryContainer : cs.onSurface;
    final borderColor = selected ? cs.primary : cs.outlineVariant;

    final labelStyle = theme.textTheme.labelLarge?.copyWith(
      color: fg,
      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
      height: 1.1,
    );

    final iconWidget = icon == null
        ? null
        : Icon(icon, size: dense ? 16 : 18, color: fg);

    final labelRow = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: labelStyle,
          ),
        ),
        if ((count ?? 0) > 0) ...[
          SizedBox(width: dense ? 6 : 8),
          _CountBadge(
            count: count!,
            bg: cs.surfaceContainerHighest,
            fg: cs.onSurfaceVariant,
            dense: dense,
          ),
        ],
      ],
    );

    final chip = FilterChip(
      label: labelRow,
      avatar: iconWidget == null
          ? null
          : IconTheme.merge(
              data: IconThemeData(color: fg),
              child: iconWidget,
            ),
      selected: selected,
      onSelected: enabled ? onSelected : null,
      showCheckmark: showCheckmark,
      checkmarkColor: fg,
      disabledColor: bg,
      backgroundColor: bg,
      selectedColor: bg, // keep same; border & text convey selection
      labelPadding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 10,
        vertical: dense ? 0 : 2,
      ),
      materialTapTargetSize:
          dense ? MaterialTapTargetSize.shrinkWrap : MaterialTapTargetSize.padded,
      visualDensity:
          dense ? const VisualDensity(horizontal: -2, vertical: -2) : VisualDensity.standard,
      shape: StadiumBorder(side: BorderSide(color: borderColor)),
    );

    if (tooltip == null || tooltip!.isEmpty) return chip;

    return Tooltip(message: tooltip!, child: chip);
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({
    required this.count,
    required this.bg,
    required this.fg,
    required this.dense,
  });

  final int count;
  final Color bg;
  final Color fg;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(999);
    final textStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
        );

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 6 : 8,
        vertical: dense ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: radius,
      ),
      child: Text(
        count > 999 ? '999+' : '$count',
        maxLines: 1,
        overflow: TextOverflow.clip,
        style: textStyle,
      ),
    );
  }
}
