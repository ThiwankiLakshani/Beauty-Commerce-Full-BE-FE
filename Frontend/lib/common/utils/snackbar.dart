// lib/common/utils/snackbar.dart
//


import 'package:flutter/material.dart';

enum SnackType { success, error, info, warning }

class AppSnackbars {
  AppSnackbars._();

  // ---------------- Public API ----------------

  static void success(
    BuildContext context,
    String message, {
    String? title,
    Duration? duration,
    String? actionLabel,
    VoidCallback? onAction,
    bool clearQueue = true,
    bool floating = true,
  }) {
    show(
      context,
      message: message,
      title: title,
      type: SnackType.success,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
      clearQueue: clearQueue,
      floating: floating,
    );
  }

  static void error(
    BuildContext context,
    String message, {
    String? title,
    Duration? duration,
    String? actionLabel,
    VoidCallback? onAction,
    bool clearQueue = true,
    bool floating = true,
  }) {
    show(
      context,
      message: message,
      title: title,
      type: SnackType.error,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
      clearQueue: clearQueue,
      floating: floating,
    );
  }

  static void info(
    BuildContext context,
    String message, {
    String? title,
    Duration? duration,
    String? actionLabel,
    VoidCallback? onAction,
    bool clearQueue = true,
    bool floating = true,
  }) {
    show(
      context,
      message: message,
      title: title,
      type: SnackType.info,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
      clearQueue: clearQueue,
      floating: floating,
    );
  }

  static void warning(
    BuildContext context,
    String message, {
    String? title,
    Duration? duration,
    String? actionLabel,
    VoidCallback? onAction,
    bool clearQueue = true,
    bool floating = true,
  }) {
    show(
      context,
      message: message,
      title: title,
      type: SnackType.warning,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
      clearQueue: clearQueue,
      floating: floating,
    );
  }

  /// Core show method used by all presets.
  static void show(
    BuildContext context, {
    required String message,
    String? title,
    SnackType type = SnackType.info,
    Duration? duration,
    String? actionLabel,
    VoidCallback? onAction,
    bool clearQueue = true,
    bool floating = true,
  }) {
    if (message.trim().isEmpty) return;

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final pal = _paletteFor(type, cs, theme.snackBarTheme);

    final content = _SnackContent(
      title: title,
      message: message,
      icon: pal.icon,
      foreground: pal.fg,
    );

    final snack = SnackBar(
      content: content,
      duration: duration ?? const Duration(seconds: 3),
      behavior: floating ? SnackBarBehavior.floating : SnackBarBehavior.fixed,
      backgroundColor: pal.bg,
      action: (actionLabel != null && onAction != null)
          ? SnackBarAction(
              label: actionLabel,
              onPressed: onAction,
              textColor: pal.action ?? theme.snackBarTheme.actionTextColor,
            )
          : null,
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(floating ? 14.0 : 0.0), // match AppTheme
        side: floating
            ? BorderSide(color: cs.outlineVariant, width: 0.6)
            : BorderSide.none,
      ),
      margin: floating
          ? const EdgeInsets.fromLTRB(12, 0, 12, 12)
          : null, // default bottom padding
      elevation: theme.snackBarTheme.elevation ?? 0,
    );

    final messenger = ScaffoldMessenger.of(context);
    if (clearQueue) messenger.clearSnackBars();
    messenger.showSnackBar(snack);
  }

  /// Dismiss any current snackbars.
  static void dismiss(BuildContext context) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }

  // ---------------- Internals ----------------

  static _Palette _paletteFor(
    SnackType type,
    ColorScheme cs,
    SnackBarThemeData themeTheme,
  ) {
    switch (type) {
      case SnackType.success:
        return _Palette(
          bg: cs.primaryContainer,
          fg: cs.onPrimaryContainer,
          action: cs.onPrimaryContainer,
          icon: Icons.check_circle_rounded,
        );
      case SnackType.error:
        return _Palette(
          bg: cs.errorContainer,
          fg: cs.onErrorContainer,
          action: cs.onErrorContainer,
          icon: Icons.error_rounded,
        );
      case SnackType.warning:
        return _Palette(
          bg: cs.tertiaryContainer,
          fg: cs.onTertiaryContainer,
          action: cs.onTertiaryContainer,
          icon: Icons.warning_rounded,
        );
      case SnackType.info:
      default:
        // Use inverseSurface to stay consistent with AppTheme.snackBarTheme defaults
        return _Palette(
          bg: themeTheme.backgroundColor ?? cs.inverseSurface,
          fg: themeTheme.contentTextStyle?.color ?? cs.onInverseSurface,
          action: themeTheme.actionTextColor ?? cs.inversePrimary,
          icon: Icons.info_rounded,
        );
    }
  }
}

class _Palette {
  const _Palette({
    required this.bg,
    required this.fg,
    required this.icon,
    this.action,
  });

  final Color bg;
  final Color fg;
  final Color? action;
  final IconData icon;
}

class _SnackContent extends StatelessWidget {
  const _SnackContent({
    required this.message,
    required this.icon,
    required this.foreground,
    this.title,
  });

  final String? title;
  final String message;
  final IconData icon;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final titleStyle = theme.textTheme.titleSmall?.copyWith(
      color: foreground,
      fontWeight: FontWeight.w700,
    );
    final messageStyle = theme.textTheme.bodyMedium?.copyWith(
      color: foreground,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: foreground),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title != null && title!.trim().isNotEmpty)
                Text(
                  title!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: titleStyle,
                ),
              Text(
                message,
                style: messageStyle,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
