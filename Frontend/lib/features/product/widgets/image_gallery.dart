// lib/features/product/widgets/image_gallery.dart

import 'package:flutter/material.dart';

class ImageGallery extends StatefulWidget {
  const ImageGallery({
    super.key,
    required this.images,
    this.initialIndex = 0,
    this.height = 340,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.showDots = true,
    this.showThumbnails = false,
    this.thumbnailHeight = 66,
    this.enableZoom = true,
    this.fit = BoxFit.cover,
    this.onIndexChanged,
    this.onTapImage,
  });

  /// Absolute image URLs. If empty, a placeholder is shown.
  final List<String> images;

  /// First page to show (clamped into range).
  final int initialIndex;

  /// Height of the main gallery area.
  final double height;

  /// Corner radius for the gallery container.
  final BorderRadius borderRadius;

  /// Show page indicators (dots) overlay.
  final bool showDots;

  /// Show a thumbnail strip below the gallery.
  final bool showThumbnails;

  /// Height of thumbnails when [showThumbnails] is true.
  final double thumbnailHeight;

  /// Allow pinch-to-zoom on the main image.
  final bool enableZoom;

  /// BoxFit for network images.
  final BoxFit fit;

  /// Called when the visible page changes.
  final ValueChanged<int>? onIndexChanged;

  /// Called when the current image is tapped.
  final ValueChanged<int>? onTapImage;

  @override
  State<ImageGallery> createState() => _ImageGalleryState();
}

class _ImageGalleryState extends State<ImageGallery> {
  late final PageController _pageController;
  late int _index;

  List<String> get _imgs => widget.images;

  @override
  void initState() {
    super.initState();
    _index = _clampIndex(widget.initialIndex);
    _pageController = PageController(initialPage: _index);
  }

  @override
  void didUpdateWidget(covariant ImageGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.images != widget.images ||
        oldWidget.initialIndex != widget.initialIndex) {
      final newIndex = _clampIndex(widget.initialIndex);
      if (newIndex != _index) {
        _index = newIndex;
        _pageController.jumpToPage(_index);
      }
    }
  }

  int _clampIndex(int i) {
    if (_imgs.isEmpty) return 0;
    if (i < 0) return 0;
    if (i >= _imgs.length) return _imgs.length - 1;
    return i;
  }

  void _goTo(int i) {
    if (i == _index) return;
    _pageController.animateToPage(
      i,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasImages = _imgs.isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Main gallery
        Stack(
          children: [
            Container(
              height: widget.height,
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: widget.borderRadius,
                border: Border.all(color: cs.outlineVariant),
                color: cs.surfaceContainerHigh,
              ),
              child: hasImages
                  ? PageView.builder(
                      controller: _pageController,
                      itemCount: _imgs.length,
                      onPageChanged: (i) {
                        setState(() => _index = i);
                        widget.onIndexChanged?.call(i);
                      },
                      itemBuilder: (_, i) {
                        final url = _imgs[i];
                        final image = Image.network(
                          url,
                          fit: widget.fit,
                          errorBuilder: (_, __, ___) => Center(
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        );
                        final content = widget.enableZoom
                            ? InteractiveViewer(
                                minScale: 1,
                                maxScale: 4,
                                clipBehavior: Clip.hardEdge,
                                child: image,
                              )
                            : image;

                        return GestureDetector(
                          onTap: () => widget.onTapImage?.call(i),
                          child: content,
                        );
                      },
                    )
                  : Center(
                      child: Icon(
                        Icons.image_not_supported_outlined,
                        color: cs.onSurfaceVariant,
                        size: 48,
                      ),
                    ),
            ),
            // Dots
            if (widget.showDots && _imgs.length > 1)
              Positioned(
                bottom: 14,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: cs.surface.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: cs.outlineVariant),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(_imgs.length, (i) {
                        final active = i == _index;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: active ? 18.0 : 8.0,
                          height: 8.0,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: active ? cs.primary : cs.outlineVariant,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
          ],
        ),

        // Thumbnails (optional)
        if (widget.showThumbnails && _imgs.length > 1)
          SizedBox(
            height: widget.thumbnailHeight + 16, // include padding
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              itemCount: _imgs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final url = _imgs[i];
                final selected = i == _index;
                return GestureDetector(
                  onTap: () => _goTo(i),
                  child: Container(
                    height: widget.thumbnailHeight,
                    width: widget.thumbnailHeight * (4 / 3),
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected ? cs.primary : cs.outlineVariant,
                        width: selected ? 2 : 1,
                      ),
                      color: cs.surfaceContainerHigh,
                    ),
                    child: Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.image_outlined,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
