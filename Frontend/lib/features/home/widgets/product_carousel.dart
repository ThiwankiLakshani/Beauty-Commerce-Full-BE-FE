// lib/features/home/widgets/product_carousel.dart
//


import 'package:flutter/material.dart';

import '../../../common/utils/formatters.dart';

class ProductCarousel extends StatelessWidget {
  const ProductCarousel({
    super.key,
    required this.title,
    required this.items,
    this.onSeeAll,
    this.onTapItem,
    this.height = 250,
    this.cardWidth = 160,
    this.spacing = 10,
    this.padding = const EdgeInsets.symmetric(horizontal: 8),
    this.showSeeAll = true,
    this.accessTokenForImages,
    this.imageHeaders,
    this.showBrand = false,
    this.imageAspectRatio = 1.0,
  });

  /// Section title shown above the list. If empty, header row is hidden.
  final String title;

  /// Product list to render.
  final List<ProductCarouselItem> items;

  /// Optional "See all" callback.
  final VoidCallback? onSeeAll;

  /// Called when a card is tapped.
  final void Function(ProductCarouselItem item)? onTapItem;

  /// Overall section height (card height).
  final double height;

  /// Width of each card.
  final double cardWidth;

  /// Spacing between cards.
  final double spacing;

  /// Horizontal padding for the list.
  final EdgeInsetsGeometry padding;

  /// Whether to show the "See all" button at top-right (only if title is not empty).
  final bool showSeeAll;

  /// If your CDN/API requires auth for images, pass a token and the widget
  /// will send `Authorization: Bearer <token>` headers for Image.network.
  final String? accessTokenForImages;

  /// Explicit headers for image requests. Takes precedence over [accessTokenForImages].
  final Map<String, String>? imageHeaders;

  /// Show brand text line above product name.
  final bool showBrand;

  /// Aspect ratio for product images (1.0 = square).
  final double imageAspectRatio;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final hasHeader = title.trim().isNotEmpty;

    // Build headers for Image.network if needed.
    Map<String, String>? headers = imageHeaders;
    if (headers == null) {
      final t = (accessTokenForImages ?? '').trim();
      if (t.isNotEmpty) headers = {'Authorization': 'Bearer $t'};
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasHeader)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
            child: Row(
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                if (showSeeAll)
                  TextButton(
                    onPressed: onSeeAll,
                    child: const Text('See all'),
                  ),
              ],
            ),
          ),

        // Horizontal list
        SizedBox(
          height: height,
          child: ListView.separated(
            padding: padding,
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => SizedBox(width: spacing),
            itemBuilder: (context, index) {
              final item = items[index];
              return _ProductCard(
                item: item,
                width: cardWidth,
                imageAspectRatio: imageAspectRatio,
                onTap: onTapItem != null ? () => onTapItem!(item) : null,
                surfaceColor: theme.cardTheme.color ?? cs.surface,
                borderColor: cs.outlineVariant,
                priceColor: cs.primary,
                showBrand: showBrand,
                imageHeaders: headers,
              );
            },
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Data model
// =============================================================================

class ProductCarouselItem {
  final String id;
  final String name;
  final String? brand;
  final double price;
  final String currency;
  final String? heroImage;

  const ProductCarouselItem({
    required this.id,
    required this.name,
    required this.price,
    required this.currency,
    this.brand,
    this.heroImage,
  });

  /// Builds from the API map used by /api/home and /api/products endpoints.
  factory ProductCarouselItem.fromApi(Map<String, dynamic> json) {
    return ProductCarouselItem(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      brand: (json['brand'] as String?)?.toString(),
      price: _toDouble(json['price']),
      currency: (json['currency'] ?? 'LKR').toString(),
      heroImage: (json['hero_image'] as String?)?.toString(),
    );
  }

  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }
}

// =============================================================================
// Card
// =============================================================================

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.item,
    required this.width,
    required this.surfaceColor,
    required this.borderColor,
    required this.priceColor,
    required this.showBrand,
    required this.imageAspectRatio,
    this.onTap,
    this.imageHeaders,
  });

  final ProductCarouselItem item;
  final double width;
  final Color surfaceColor;
  final Color borderColor;
  final Color priceColor;
  final bool showBrand;
  final double imageAspectRatio;
  final VoidCallback? onTap;

  /// Headers for Image.network (e.g., Authorization: Bearer <token>)
  final Map<String, String>? imageHeaders;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = 14.0;

    return InkWell(
      borderRadius: BorderRadius.circular(radius),
      onTap: onTap,
      child: Ink(
        width: width,
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
              child: AspectRatio(
                aspectRatio: imageAspectRatio,
                child: (item.heroImage == null || item.heroImage!.isEmpty)
                    ? const _ImagePlaceholder(icon: Icons.image_outlined)
                    : Image.network(
                        item.heroImage!,
                        fit: BoxFit.cover,
                        headers: imageHeaders,
                        errorBuilder: (_, __, ___) =>
                            const _ImagePlaceholder(icon: Icons.broken_image),
                        loadingBuilder: (ctx, child, progress) {
                          if (progress == null) return child;
                          return const _ImagePlaceholder(
                              icon: Icons.photo_library_outlined);
                        },
                      ),
              ),
            ),

            // Details
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showBrand && (item.brand ?? '').isNotEmpty) ...[
                      Text(
                        item.brand!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                    ],
                    // Name
                    Text(
                      item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    // Price
                    Text(
                      Formatters.price(item.price, currency: item.currency),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: priceColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
