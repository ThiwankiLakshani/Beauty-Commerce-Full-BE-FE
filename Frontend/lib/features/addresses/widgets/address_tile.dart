// lib/features/addresses/widgets/address_tile.dart
//


import 'package:flutter/material.dart';

class AddressTileData {
  const AddressTileData({
    required this.id,
    required this.name,
    required this.line1,
    required this.line2,
    required this.city,
    required this.region,
    required this.postalCode,
    required this.country,
    required this.phone,
    required this.isDefault,
  });

  final String id;
  final String name;
  final String line1;
  final String line2;
  final String city;
  final String region;
  final String postalCode;
  final String country;
  final String phone;
  final bool isDefault;

  /// Helpful when you already have a backend map.
  factory AddressTileData.fromMap(Map<String, dynamic> m) {
    return AddressTileData(
      id: (m['id'] ?? '').toString(),
      name: (m['name'] ?? '').toString(),
      line1: (m['line1'] ?? '').toString(),
      line2: (m['line2'] ?? '').toString(),
      city: (m['city'] ?? '').toString(),
      region: (m['region'] ?? '').toString(),
      postalCode: (m['postal_code'] ?? '').toString(),
      country: (m['country'] ?? 'LK').toString(),
      phone: (m['phone'] ?? '').toString(),
      isDefault: m['is_default'] == true,
    );
  }
}

class AddressTile extends StatelessWidget {
  const AddressTile({
    super.key,
    required this.address,
    required this.selected,
    required this.onSelect,
    this.onEdit,
    this.onDelete,
    this.showActions = true,
    this.dense = false,
  });

  final AddressTileData address;

  /// Whether this tile is currently selected (e.g., default).
  final bool selected;

  /// Called when user taps the tile or the radio.
  final VoidCallback onSelect;

  /// Optional edit/delete callbacks. Hidden if [showActions] = false.
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  /// Hide action buttons (useful in read-only contexts).
  final bool showActions;

  /// Slightly more compact padding when true.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final padding = dense ? const EdgeInsets.all(10) : const EdgeInsets.all(12);
    final borderColor = selected ? cs.primary : cs.outlineVariant;
    final borderWidth = selected ? 2.0 : 1.0;

    return InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: borderWidth),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Radio<bool>(
              value: true,
              groupValue: selected,
              onChanged: (_) => onSelect(),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row with name and default chip
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          address.name.isEmpty ? '—' : address.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      if (address.isDefault)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Chip(
                            label: const Text('Default'),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Address body
                  Text(
                    _formatAddress(address),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),

                  if (showActions) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: onEdit,
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Edit'),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: onDelete,
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Delete'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatAddress(AddressTileData a) {
    final parts = <String>[
      if (a.line1.isNotEmpty) a.line1,
      if (a.line2.isNotEmpty) a.line2,
      [a.city, a.region].where((e) => e.isNotEmpty).join(', '),
      if (a.postalCode.isNotEmpty) a.postalCode,
      if (a.country.isNotEmpty) a.country,
      if (a.phone.isNotEmpty) '☎ ${a.phone}',
    ].where((e) => e.trim().isNotEmpty).toList();

    return parts.join('\n');
  }
}
