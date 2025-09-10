// lib/common/widgets/empty_state.dart
//

import 'package:flutter/material.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    this.illustration,
    this.icon = Icons.inbox_rounded,
    this.iconSize,
    this.title,
    this.message,
    this.primaryActionLabel,
    this.onPrimaryAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.alignment = MainAxisAlignment.center,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.padding = const EdgeInsets.all(24),
    this.maxContentWidth = 440,
    this.compact = false,
  });

  /// Optional custom illustration widget (e.g., Lottie, image, etc.).
  /// If provided, this is shown instead of [icon].
  final Widget? illustration;

  /// Fallback icon if [illustration] is not provided.
  final IconData icon;

  /// Optional icon size; sensible defaults are chosen according to [compact].
  final double? iconSize;

  /// Title (bold). If null, a subtle default is shown only if [message] is also null.
  final String? title;

  /// Supporting message (softer).
  final String? message;

  /// Primary action label (renders a filled button).
  final String? primaryActionLabel;

  /// Primary action callback.
  final VoidCallback? onPrimaryAction;

  /// Secondary action label (renders an outlined button).
  final String? secondaryActionLabel;

  /// Secondary action callback.
  final VoidCallback? onSecondaryAction;

  /// Vertical alignment inside the available space.
  final MainAxisAlignment alignment;

  /// Horizontal alignment for the column contents.
  final CrossAxisAlignment crossAxisAlignment;

  /// Outer padding around the whole component.
  final EdgeInsetsGeometry padding;

  /// Constrain the maximum width to keep layout tidy on tablets/landscape.
  final double maxContentWidth;

  /// If true, reduces paddings and icon size.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final double resolvedIconSize = iconSize ?? (compact ? 40 : 56);
    final double spacingL = compact ? 8 : 12;
    final double spacingXL = compact ? 12 : 16;
    final double spacingXXL = compact ? 16 : 24;

    final bool hasPrimary = primaryActionLabel != null && onPrimaryAction != null;
    final bool hasSecondary = secondaryActionLabel != null && onSecondaryAction != null;

    final String? effectiveTitle = title ?? (message == null ? 'Nothing here yet' : null);

    return Padding(
      padding: padding,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxContentWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: alignment,
            crossAxisAlignment: crossAxisAlignment,
            children: [
              // Illustration or Icon
              if (illustration != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    height: resolvedIconSize * 2,
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: illustration,
                    ),
                  ),
                )
              else
                Icon(
                  icon,
                  size: resolvedIconSize,
                  color: cs.onSurfaceVariant,
                ),

              if (effectiveTitle != null) ...[
                SizedBox(height: spacingXL),
                Text(
                  effectiveTitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],

              if (message != null) ...[
                SizedBox(height: spacingL),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],

              if (hasPrimary || hasSecondary) ...[
                SizedBox(height: spacingXXL),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (hasPrimary)
                      _PrimaryActionButton(
                        label: primaryActionLabel!,
                        onPressed: onPrimaryAction!,
                      ),
                    if (hasSecondary)
                      _SecondaryActionButton(
                        label: secondaryActionLabel!,
                        onPressed: onSecondaryAction!,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// Internal action buttons (kept minimal so they inherit Theme properly)

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _SecondaryActionButton extends StatelessWidget {
  const _SecondaryActionButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
