// lib/features/home/widgets/product_card.dart
//


import 'package:flutter/material.dart';

import '../../../common/utils/formatters.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.item,
    this.onTap,
    this.onFavorite,
    this.showFavorite = false,
    this.isFavorite = false,
    this.width = 160,
    this.aspectRatio = 1.0, // image aspect ratio (1 = square)
    this.compact = false,
    this.accessTokenForImages,
    this.imageHeaders,
  });

  final ProductCardItem item;

  /// Card tap (navigate to details)
  final VoidCallback? onTap;

  /// Favorite toggle (if [showFavorite] is true)
  final VoidCallback? onFavorite;

  /// Whether to show a heart icon overlay in the image area.
  final bool showFavorite;

  /// If true renders a filled heart, otherwise outline.
  final bool isFavorite;

  /// Fixed width (useful in horizontal carousels). Ignored in grids if constrained.
  final double width;

  /// Image aspect ratio (width / height). Usually 1.0 for square product shots.
  final double aspectRatio;

  /// Compact spacing & slightly smaller typography.
  final bool compact;

  /// Optional JWT for protected images. If provided, we set Authorization header.
  final String? accessTokenForImages;

  /// Optional explicit headers for image requests. Takes precedence over token.
  final Map<String, String>? imageHeaders;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final radius = 14.0;
    final surface = theme.cardTheme.color ?? cs.surface;
    final border = cs.outlineVariant;

    final nameStyle = (compact ? theme.textTheme.bodySmall : theme.textTheme.bodyMedium)
        ?.copyWith(fontWeight: FontWeight.w600);
    final brandStyle = theme.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant);
    final priceStyle = theme.textTheme.titleSmall
        ?.copyWith(color: cs.primary, fontWeight: FontWeight.w800);

    // Build headers for Image.network if needed.
    Map<String, String>? headers = imageHeaders;
    if (headers == null) {
      final t = (accessTokenForImages ?? '').trim();
      if (t.isNotEmpty) headers = {'Authorization': 'Bearer $t'};
    }

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Image with optional favorite overlay ---
        ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(14),
            topRight: Radius.circular(14),
          ),
          child: Stack(
            children: [
              AspectRatio(
                aspectRatio: aspectRatio,
                child: (item.heroImage == null || item.heroImage!.isEmpty)
                    ? const _ImagePlaceholder(icon: Icons.image_outlined)
                    : Image.network(
                        item.heroImage!,
                        fit: BoxFit.cover,
                        headers: headers,
                        errorBuilder: (_, __, ___) =>
                            const _ImagePlaceholder(icon: Icons.broken_image),
                        loadingBuilder: (ctx, child, progress) {
                          if (progress == null) return child;
                          return const _ImagePlaceholder(icon: Icons.photo_library_outlined);
                        },
                      ),
              ),
              if (showFavorite)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Material(
                    color: Colors.black.withOpacity(0.35),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onFavorite,
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(
                          isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),

        // --- Details ---
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: compact ? 6 : 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Brand (optional)
                if ((item.brand ?? '').isNotEmpty) ...[
                  Text(item.brand!, maxLines: 1, overflow: TextOverflow.ellipsis, style: brandStyle),
                  const SizedBox(height: 2),
                ],

                // Name (2 lines)
                Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: nameStyle,
                ),

                const Spacer(),

                // Rating (optional) + Price
                if (item.hasRating) ...[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded, size: 16, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        item.ratingAvg!.toStringAsFixed(1),
                        style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      if ((item.ratingCount ?? 0) > 0) ...[
                        const SizedBox(width: 4),
                        Text(
                          '(${item.ratingCount})',
                          style: theme.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                ],

                // Price
                Text(
                  Formatters.price(item.price, currency: item.currency),
                  style: priceStyle,
                ),
              ],
            ),
          ),
        ),
      ],
    );

    // InkWell + Ink to get ripple on rounded container.
    return InkWell(
      borderRadius: BorderRadius.circular(radius),
      onTap: onTap,
      child: Ink(
        width: width,
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: border),
        ),
        child: content,
      ),
    );
  }
}

// =============================================================================
// Data model
// =============================================================================

class ProductCardItem {
  final String id;
  final String name;
  final String? brand;
  final double price;
  final String currency;
  final String? heroImage;
  final double? ratingAvg;
  final int? ratingCount;

  const ProductCardItem({
    required this.id,
    required this.name,
    required this.price,
    required this.currency,
    this.brand,
    this.heroImage,
    this.ratingAvg,
    this.ratingCount,
  });

  /// Build from /api/home or /api/products style payload.
  factory ProductCardItem.fromApi(Map<String, dynamic> json) {
    return ProductCardItem(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      brand: (json['brand'] as String?)?.toString(),
      price: _toDouble(json['price']),
      currency: (json['currency'] ?? 'LKR').toString(),
      heroImage: (json['hero_image'] as String?)?.toString(),
      ratingAvg: _toDoubleOrNull(json['rating_avg']),
      ratingCount: _toIntOrNull(json['rating_count']),
    );
  }

  bool get hasRating => (ratingAvg ?? 0) > 0;

  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  static double? _toDoubleOrNull(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static int? _toIntOrNull(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }
}

// =============================================================================
// Helpers
// =============================================================================

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.surfaceContainerHighest,
      child: Icon(icon, color: cs.onSurfaceVariant),
    );
  }
}
