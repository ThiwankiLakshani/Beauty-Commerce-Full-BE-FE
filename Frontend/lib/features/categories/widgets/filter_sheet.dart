// lib/features/categories/widgets/filter_sheet.dart
//

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../common/widgets/primary_button.dart';
import '../../../common/widgets/text_field.dart';
import '../../categories/widgets/category_chip.dart';

/// Simple key/label pair for attributes (skin types, concerns).
class KeyLabel {
  final String key;
  final String label;
  const KeyLabel({required this.key, required this.label});
}

/// Filters that map to backend query parameters.
/// (Backend currently supports single values for item_type, concern, skin_type.)
class CategoryFilters {
  final String? itemType;
  final String? concernKey;
  final String? skinTypeKey;

  // Optional local-only filters (reserved for future server support)
  final double? minPrice;
  final double? maxPrice;

  const CategoryFilters({
    this.itemType,
    this.concernKey,
    this.skinTypeKey,
    this.minPrice,
    this.maxPrice,
  });

  CategoryFilters copyWith({
    String? itemType,
    String? concernKey,
    String? skinTypeKey,
    double? minPrice,
    double? maxPrice,
    bool keepItemTypeNull = false,
    bool keepConcernNull = false,
    bool keepSkinTypeNull = false,
    bool keepMinPriceNull = false,
    bool keepMaxPriceNull = false,
  }) {
    return CategoryFilters(
      itemType: keepItemTypeNull ? null : (itemType ?? this.itemType),
      concernKey: keepConcernNull ? null : (concernKey ?? this.concernKey),
      skinTypeKey: keepSkinTypeNull ? null : (skinTypeKey ?? this.skinTypeKey),
      minPrice: keepMinPriceNull ? null : (minPrice ?? this.minPrice),
      maxPrice: keepMaxPriceNull ? null : (maxPrice ?? this.maxPrice),
    );
  }

  /// Convert to backend-ready query map for /api/products.
  /// (Only includes keys the server understands.)
  Map<String, String> toQuery() {
    final m = <String, String>{};
    if (itemType != null && itemType!.isNotEmpty) m['item_type'] = itemType!;
    if (concernKey != null && concernKey!.isNotEmpty) m['concern'] = concernKey!;
    if (skinTypeKey != null && skinTypeKey!.isNotEmpty) m['skin_type'] = skinTypeKey!;
    return m;
  }

  /// Convenience: empty filters
  static const empty = CategoryFilters();

  bool get isEmpty =>
      (itemType == null || itemType!.isEmpty) &&
      (concernKey == null || concernKey!.isEmpty) &&
      (skinTypeKey == null || skinTypeKey!.isEmpty) &&
      minPrice == null &&
      maxPrice == null;
}

/// Shows the modal bottom sheet and returns the selected [CategoryFilters],
/// or null if the user dismissed without applying.
Future<CategoryFilters?> showCategoryFilterSheet(
  BuildContext context, {
  CategoryFilters initial = CategoryFilters.empty,
  required List<String> itemTypes,
  required List<KeyLabel> skinTypes,
  required List<KeyLabel> concerns,
}) {
  return showModalBottomSheet<CategoryFilters>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _CategoryFilterSheet(
      initial: initial,
      itemTypes: itemTypes,
      skinTypes: skinTypes,
      concerns: concerns,
    ),
  );
}

// ============================================================================
// Sheet UI
// ============================================================================

class _CategoryFilterSheet extends StatefulWidget {
  const _CategoryFilterSheet({
    required this.initial,
    required this.itemTypes,
    required this.skinTypes,
    required this.concerns,
  });

  final CategoryFilters initial;
  final List<String> itemTypes;
  final List<KeyLabel> skinTypes;
  final List<KeyLabel> concerns;

  @override
  State<_CategoryFilterSheet> createState() => _CategoryFilterSheetState();
}

class _CategoryFilterSheetState extends State<_CategoryFilterSheet> {
  late String? _itemType = widget.initial.itemType;
  late String? _concernKey = widget.initial.concernKey;
  late String? _skinTypeKey = widget.initial.skinTypeKey;

  final _minCtrl = TextEditingController();
  final _maxCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initial.minPrice != null) {
      _minCtrl.text = _formatNum(widget.initial.minPrice!);
    }
    if (widget.initial.maxPrice != null) {
      _maxCtrl.text = _formatNum(widget.initial.maxPrice!);
    }
  }

  @override
  void dispose() {
    _minCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  String _formatNum(double v) {
    // Minimal formatting to avoid locale complications in a minimal dependency setup
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(2);
  }

  double? _parsePrice(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  void _clearAll() {
    setState(() {
      _itemType = null;
      _concernKey = null;
      _skinTypeKey = null;
      _minCtrl.clear();
      _maxCtrl.clear();
    });
  }

  void _apply() {
    final filters = CategoryFilters(
      itemType: _itemType,
      concernKey: _concernKey,
      skinTypeKey: _skinTypeKey,
      minPrice: _parsePrice(_minCtrl.text),
      maxPrice: _parsePrice(_maxCtrl.text),
    );
    Navigator.of(context).pop(filters);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return DraggableScrollableSheet(
      expand: false,
      maxChildSize: 0.95,
      initialChildSize: 0.86,
      minChildSize: 0.60,
      builder: (context, controller) {
        return Column(
          children: [
            // --- Grip + Title bar ---
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                children: [
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.outlineVariant,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        'Filters',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _clearAll,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Clear'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // --- Content ---
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                children: [
                  // Item Type
                  _Section(
                    title: 'Item type',
                    child: _SingleSelectChips<String>(
                      options: widget.itemTypes,
                      isSelected: (val) => _itemType == val,
                      labelOf: (val) => val,
                      onSelect: (val) {
                        setState(() {
                          _itemType = _itemType == val ? null : val;
                        });
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Skin Type
                  _Section(
                    title: 'Skin type',
                    child: _SingleSelectChips<KeyLabel>(
                      options: widget.skinTypes,
                      isSelected: (val) => _skinTypeKey == val.key,
                      labelOf: (val) => val.label,
                      onSelect: (val) {
                        setState(() {
                          _skinTypeKey = _skinTypeKey == val.key ? null : val.key;
                        });
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Concerns
                  _Section(
                    title: 'Concerns',
                    child: _SingleSelectChips<KeyLabel>(
                      options: widget.concerns,
                      isSelected: (val) => _concernKey == val.key,
                      labelOf: (val) => val.label,
                      onSelect: (val) {
                        setState(() {
                          _concernKey = _concernKey == val.key ? null : val.key;
                        });
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Price range (local-only for now)
                  _Section(
                    title: 'Price range',
                    child: Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            controller: _minCtrl,
                            label: 'Min',
                            hint: '0',
                            keyboardType:
                                const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                            ],
                            prefixIcon: const Icon(Icons.price_change_outlined),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppTextField(
                            controller: _maxCtrl,
                            label: 'Max',
                            hint: '10000',
                            keyboardType:
                                const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                            ],
                            prefixIcon: const Icon(Icons.price_change),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // --- Actions ---
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PrimaryButton(
                      label: 'Apply filters',
                      onPressed: _apply,
                      fullWidth: true,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ============================================================================
// Building blocks
// ============================================================================

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style:
              theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.inputDecorationTheme.fillColor ?? cs.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: child,
        ),
      ],
    );
  }
}

class _SingleSelectChips<T> extends StatelessWidget {
  const _SingleSelectChips({
    required this.options,
    required this.isSelected,
    required this.labelOf,
    required this.onSelect,
  });

  final List<T> options;
  final bool Function(T value) isSelected;
  final String Function(T value) labelOf;
  final void Function(T value) onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: -4,
      children: options.map((opt) {
        final selected = isSelected(opt);
        return CategoryChip.small(
          label: labelOf(opt),
          selected: selected,
          onSelected: (_) => onSelect(opt),
          showCheckmark: false,
        );
      }).toList(),
    );
  }
}
