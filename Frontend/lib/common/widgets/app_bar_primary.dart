// lib/common/widgets/app_bar_primary.dart
//


import 'package:flutter/material.dart';

class AppBarPrimary extends StatelessWidget implements PreferredSizeWidget {
  const AppBarPrimary({
    super.key,
    this.title,
    this.titleWidget,
    this.centerTitle = false,
    this.leading,
    this.showBack, // null = auto (if navigator can pop)
    this.onBack,
    this.actions,
    this.bottom,
    this.elevation = 0.0,
    this.backgroundColor,
  }) : assert(
          title != null || titleWidget != null,
          'Provide either title or titleWidget.',
        );

  /// Simple text title. Ignored if [titleWidget] is provided.
  final String? title;

  /// Custom title widget (e.g., a search pill). Takes precedence over [title].
  final Widget? titleWidget;

  /// Whether to center the title. Defaults to `false` to match AliExpress style.
  final bool centerTitle;

  /// Custom leading. If null, a back button is shown when the route can pop
  /// (unless [showBack] is explicitly set to false).
  final Widget? leading;

  /// Force-show or force-hide the back button.
  /// If null, it is shown automatically when the route can pop.
  final bool? showBack;

  /// Callback for the back button. Defaults to Navigator.pop().
  final VoidCallback? onBack;

  /// Action widgets (e.g., icons) on the right.
  final List<Widget>? actions;

  /// Optional bottom (e.g., a TabBar). Must implement PreferredSizeWidget.
  final PreferredSizeWidget? bottom;

  /// Elevation for the AppBar (Material 3 often uses 0).
  final double elevation;

  /// Background color override. If null, uses theme surface.
  final Color? backgroundColor;

  // Compute preferred size taking into account the optional bottom.
  @override
  Size get preferredSize => Size.fromHeight(
        kToolbarHeight + (bottom?.preferredSize.height ?? 0),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Decide whether to show the back button
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    final shouldShowBack = showBack ?? canPop;

    return AppBar(
      backgroundColor: backgroundColor ?? theme.appBarTheme.backgroundColor ?? cs.surface,
      surfaceTintColor: Colors.transparent, // keep surfaces flat like commerce UIs
      elevation: elevation,
      centerTitle: centerTitle,
      leading: _buildLeading(context, shouldShowBack, cs),
      title: titleWidget ??
          Text(
            title ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
      actions: actions,
      bottom: bottom,
    );
  }

  Widget? _buildLeading(BuildContext context, bool shouldShowBack, ColorScheme cs) {
    if (leading != null) return leading;
    if (!shouldShowBack) return null;

    return IconButton(
      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
      icon: const Icon(Icons.arrow_back_rounded),
      color: cs.onSurface,
      onPressed: onBack ?? () => Navigator.maybePop(context),
    );
  }

  /// Factory that returns an AppBar with a pill-style search field in the title.
  /// Common on e-commerce home pages.
  ///
  /// Example:
  /// ```
  /// AppBarPrimary.search(
  ///   hintText: 'Search products',
  ///   onTap: () => context.go(Routes.search),
  ///   actions: [IconButton(icon: Icon(Icons.shopping_cart_outlined), onPressed: ...)],
  /// )
  /// ```
  factory AppBarPrimary.search({
    Key? key,
    String hintText = 'Search',
    VoidCallback? onTap,
    List<Widget>? actions,
    PreferredSizeWidget? bottom,
    bool centerTitle = false,
    Widget? leading,
    bool? showBack,
    VoidCallback? onBack,
    double elevation = 0.0,
    Color? backgroundColor,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return AppBarPrimary(
      key: key,
      titleWidget: _SearchPill(
        hintText: hintText,
        onTap: onTap,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
      ),
      actions: actions,
      bottom: bottom,
      centerTitle: centerTitle,
      leading: leading,
      showBack: showBack,
      onBack: onBack,
      elevation: elevation,
      backgroundColor: backgroundColor,
    );
  }
}

/// Internal pill-shaped, non-editable search widget used in the AppBar title.
/// Tapping it should navigate to the actual search screen.
class _SearchPill extends StatelessWidget {
  const _SearchPill({
    required this.hintText,
    this.onTap,
    this.prefixIcon,
    this.suffixIcon,
  });

  final String hintText;
  final VoidCallback? onTap;
  final Widget? prefixIcon;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: cs.surfaceVariant.withOpacity(0.6),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: cs.outlineVariant),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            prefixIcon ??
                Icon(Icons.search_rounded, color: cs.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hintText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
            if (suffixIcon != null) ...[
              const SizedBox(width: 8),
              suffixIcon!,
            ],
          ],
        ),
      ),
    );
  }
}
