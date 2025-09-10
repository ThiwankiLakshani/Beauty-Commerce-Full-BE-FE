// lib/features/search/widgets/facet_filters.dart
//


import 'package:flutter/material.dart';

import '../../categories/widgets/filter_sheet.dart';
import '../../categories/widgets/category_chip.dart';

class FacetFilters extends StatelessWidget {
  const FacetFilters({
    super.key,
    required this.value,
    required this.onChanged,
    required this.itemTypes,
    required this.skinTypes,
    required this.concerns,
    this.loading = false,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 8),
    this.showClearAction = true,
  });

  /// Current selected filters.
  final CategoryFilters value;

  /// Called with new filters when the sheet is applied or when chips are cleared.
  final ValueChanged<CategoryFilters> onChanged;

  /// Available item types (strings shown directly as labels).
  final List<String> itemTypes;

  /// Available skin types (key/label pairs).
  final List<KeyLabel> skinTypes;

  /// Available concerns (key/label pairs).
  final List<KeyLabel> concerns;

  /// Whether filter metadata is loading (disables the button and shows spinner).
  final bool loading;

  /// Outer padding.
  final EdgeInsetsGeometry padding;

  /// Show a "Clear" text button if any filter is active.
  final bool showClearAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final hasActive = !value.isEmpty;

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Filters button
              SizedBox(
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: loading
                      ? null
                      : () async {
                          final result = await showCategoryFilterSheet(
                            context,
                            initial: value,
                            itemTypes: itemTypes,
                            skinTypes: skinTypes,
                            concerns: concerns,
                          );

                          // If the sheet returns null, do nothing.
                          // If it returns an empty CategoryFilters, treat that as "clear".
                          if (result == null) return;
                          if (result.isEmpty) {
                            if (!value.isEmpty) onChanged(CategoryFilters.empty);
                            return;
                          }
                          onChanged(result);
                        },
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.tune_rounded),
                  label: const Text('Filters'),
                ),
              ),
              const SizedBox(width: 8),
              // Summary (optional)
              Expanded(
                child: _SelectedSummary(
                  value: value,
                  skinTypes: skinTypes,
                  concerns: concerns,
                  textStyle: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
              if (showClearAction && hasActive) ...[
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => onChanged(CategoryFilters.empty),
                  icon: const Icon(Icons.clear_all_rounded, size: 18),
                  label: const Text('Clear'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          // Selected chips
          _SelectedChips(
            value: value,
            skinTypes: skinTypes,
            concerns: concerns,
            onRemove: (updated) => onChanged(updated),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Selected summary (one-line text like: "Serum • Oily Skin • Acne")
// -----------------------------------------------------------------------------

class _SelectedSummary extends StatelessWidget {
  const _SelectedSummary({
    required this.value,
    required this.skinTypes,
    required this.concerns,
    this.textStyle,
  });

  final CategoryFilters value;
  final List<KeyLabel> skinTypes;
  final List<KeyLabel> concerns;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];
    final type = value.itemType?.trim();
    final st   = value.skinTypeKey?.trim();
    final con  = value.concernKey?.trim();

    if (type != null && type.isNotEmpty) {
      parts.add(type);
    }
    if (st != null && st.isNotEmpty) {
      final lbl = _findLabel(skinTypes, st);
      if (lbl != null) parts.add(lbl);
    }
    if (con != null && con.isNotEmpty) {
      final lbl = _findLabel(concerns, con);
      if (lbl != null) parts.add(lbl);
    }

    if (parts.isEmpty) return const SizedBox.shrink();

    return Text(
      parts.join(' • '),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: textStyle,
    );
  }
}

// -----------------------------------------------------------------------------
// Selected chips list (removable)
// -----------------------------------------------------------------------------

class _SelectedChips extends StatelessWidget {
  const _SelectedChips({
    required this.value,
    required this.skinTypes,
    required this.concerns,
    required this.onRemove,
  });

  final CategoryFilters value;
  final List<KeyLabel> skinTypes;
  final List<KeyLabel> concerns;

  /// Called with a new [CategoryFilters] when a chip is removed.
  final ValueChanged<CategoryFilters> onRemove;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];

    final type = value.itemType?.trim();
    final st   = value.skinTypeKey?.trim();
    final con  = value.concernKey?.trim();

    if (type != null && type.isNotEmpty) {
      chips.add(_RemovableChip(
        label: type,
        onRemoved: () => onRemove(
          CategoryFilters(
            itemType: null,
            skinTypeKey: value.skinTypeKey,
            concernKey: value.concernKey,
          ),
        ),
      ));
    }

    if (st != null && st.isNotEmpty) {
      final lbl = _findLabel(skinTypes, st);
      if (lbl != null) {
        chips.add(_RemovableChip(
          label: lbl,
          onRemoved: () => onRemove(
            CategoryFilters(
              itemType: value.itemType,
              skinTypeKey: null,
              concernKey: value.concernKey,
            ),
          ),
        ));
      }
    }

    if (con != null && con.isNotEmpty) {
      final lbl = _findLabel(concerns, con);
      if (lbl != null) {
        chips.add(_RemovableChip(
          label: lbl,
          onRemoved: () => onRemove(
            CategoryFilters(
              itemType: value.itemType,
              skinTypeKey: value.skinTypeKey,
              concernKey: null,
            ),
          ),
        ));
      }
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: -4,
      children: chips,
    );
  }
}

class _RemovableChip extends StatelessWidget {
  const _RemovableChip({required this.label, required this.onRemoved});

  final String label;
  final VoidCallback onRemoved;

  @override
  Widget build(BuildContext context) {
    return CategoryChip.small(
      label: label,
      selected: true,
      onSelected: (_) => onRemoved(),
      showCheckmark: false,
      tooltip: 'Remove "$label"',
    );
  }
}

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

String? _findLabel(List<KeyLabel> pairs, String key) {
  for (final p in pairs) {
    if (p.key == key) return p.label;
  }
  return null;
}
