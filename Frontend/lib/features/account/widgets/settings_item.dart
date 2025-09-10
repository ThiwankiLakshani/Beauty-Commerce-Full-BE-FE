// lib/features/account/widgets/settings_item.dart


import 'package:flutter/material.dart';

class SettingsItem extends StatelessWidget {
  const SettingsItem({
    super.key,
    this.icon,
    this.leadingImageUrl,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.showChevron = true,
    this.dense = false,
    this.danger = false,
    this.enabled = true,
    this.switchValue,
    this.onSwitchChanged,
  });

  /// Leading icon (used if [leadingImageUrl] is not provided).
  final IconData? icon;

  /// Optional leading avatar image (network). If provided, takes precedence over [icon].
  final String? leadingImageUrl;

  /// Primary text (required).
  final String title;

  /// Secondary text (muted).
  final String? subtitle;

  /// Row tap handler (ignored in switch mode; tap toggles the switch instead).
  final VoidCallback? onTap;

  /// Optional trailing widget. If null and not in switch mode, a chevron can be shown via [showChevron].
  final Widget? trailing;

  /// Show a chevron when [trailing] is null and not in switch mode.
  final bool showChevron;

  /// Slightly smaller paddings when true.
  final bool dense;

  /// Draw in "danger" style (uses error color hints for icon/text).
  final bool danger;

  /// Enable/disable the row.
  final bool enabled;

  /// If set, this item becomes a "switch row" and shows a trailing Switch.adaptive.
  final bool? switchValue;

  /// Called when the switch changes (only used if [switchValue] is not null).
  final ValueChanged<bool>? onSwitchChanged;

  bool get _isSwitchMode => switchValue != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final pad = dense
        ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
        : const EdgeInsets.symmetric(horizontal: 12, vertical: 12);

    final radius = BorderRadius.circular(16);

    final Color iconColor = danger
        ? cs.error
        : (enabled ? cs.primary : cs.onSurfaceVariant);

    final Color titleColor = danger
        ? cs.error
        : (enabled ? theme.textTheme.titleSmall?.color ?? cs.onSurface : cs.onSurfaceVariant);

    final Color subtitleColor = cs.onSurfaceVariant;

    // Build leading (image avatar > icon avatar > empty)
    Widget leadingWidget;
    if ((leadingImageUrl ?? '').trim().isNotEmpty) {
      leadingWidget = CircleAvatar(
        radius: dense ? 16 : 18,
        backgroundColor: cs.primary.withOpacity(0.10),
        foregroundImage: NetworkImage(leadingImageUrl!.trim()),
        onForegroundImageError: (_, __) {},
        child: Icon(icon ?? Icons.person_outline, color: iconColor, size: dense ? 18 : 20),
      );
    } else if (icon != null) {
      leadingWidget = CircleAvatar(
        radius: dense ? 16 : 18,
        backgroundColor: cs.primary.withOpacity(0.10),
        child: Icon(icon, color: iconColor, size: dense ? 18 : 20),
      );
    } else {
      leadingWidget = const SizedBox.shrink();
    }

    // Build middle text column
    final textColumn = Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: titleColor,
            ),
          ),
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(color: subtitleColor),
            ),
          ],
        ],
      ),
    );

    // Build trailing area
    Widget trailingArea;
    if (_isSwitchMode) {
      trailingArea = Switch.adaptive(
        value: switchValue ?? false,
        onChanged: enabled ? onSwitchChanged : null,
      );
    } else if (trailing != null) {
      trailingArea = trailing!;
    } else if (showChevron) {
      trailingArea = Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant);
    } else {
      trailingArea = const SizedBox.shrink();
    }

    // Row content
    final row = Row(
      children: [
        if (!(leadingWidget is SizedBox)) leadingWidget,
        if (!(leadingWidget is SizedBox)) const SizedBox(width: 10),
        textColumn,
        const SizedBox(width: 10),
        trailingArea,
      ],
    );

    // Card container
    final card = Container(
      padding: pad,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: radius,
        border: Border.all(color: cs.outlineVariant),
      ),
      child: row,
    );

    // Interaction behavior
    if (!enabled) {
      return Opacity(opacity: 0.6, child: card);
    }

    if (_isSwitchMode) {
      // In switch mode, tapping toggles the value if a handler exists.
      return InkWell(
        onTap: (onSwitchChanged != null)
            ? () => onSwitchChanged!.call(!(switchValue ?? false))
            : null,
        borderRadius: radius,
        child: card,
      );
    } else {
      // Normal mode: onTap as provided.
      return InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: card,
      );
    }
  }
}
