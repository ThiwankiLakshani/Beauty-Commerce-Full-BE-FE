// lib/common/widgets/primary_button.dart


import 'package:flutter/material.dart';

enum ButtonSize { small, medium, large }

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.onLongPress,
    this.loading = false,
    this.fullWidth = false,
    this.size = ButtonSize.medium,
    // Preferred API
    Widget? leadingIcon,
    Widget? trailingIcon,
    // Back-compat aliases (e.g. older code using `leading:`)
    Widget? leading,
    Widget? trailing,
    this.radius,
    this.padding,
    this.backgroundColor,
    this.foregroundColor,
    this.textStyle,
    this.focusNode,
    this.autofocus = false,
    this.clipBehavior = Clip.antiAlias,
    this.semanticLabel,
  })  : leadingIcon = leadingIcon ?? leading,
        trailingIcon = trailingIcon ?? trailing;

  /// Text on the button.
  final String label;

  /// Tap callbacks.
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;

  /// When true, disables the button and shows a progress spinner.
  final bool loading;

  /// If true, expands to the full available width.
  final bool fullWidth;

  /// Size preset.
  final ButtonSize size;

  /// Optional icons (preferred API).
  final Widget? leadingIcon;
  final Widget? trailingIcon;

  /// Corner radius override (defaults to 14.0 to match app theme).
  final double? radius;

  /// Custom padding override. If null, uses size preset.
  final EdgeInsetsGeometry? padding;

  /// Optional color overrides (let theme drive these in most cases).
  final Color? backgroundColor;
  final Color? foregroundColor;

  /// Optional text style override.
  final TextStyle? textStyle;

  /// Focus/autofocus.
  final FocusNode? focusNode;
  final bool autofocus;

  /// Clipping behavior for ink effects.
  final Clip clipBehavior;

  /// Accessibility label override.
  final String? semanticLabel;

  static const double _kDefaultRadius = 14.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final dims = _dimensionsFor(size);
    final EdgeInsetsGeometry resolvedPadding = padding ?? dims.padding;
    final double r = radius ?? _kDefaultRadius;

    final bool disabled = onPressed == null || loading;

    final ButtonStyle style = ElevatedButton.styleFrom(
      padding: resolvedPadding,
      backgroundColor: backgroundColor, // if null, theme handles it
      foregroundColor: foregroundColor,
      textStyle: textStyle ??
          theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(r),
      ),
      // Let the global ElevatedButtonTheme control elevation/colors.
    );

    Widget child;
    if (loading) {
      child = _LoadingLabel(
        label: label,
        progressSize: dims.spinner,
      );
    } else {
      child = _LabeledRow(
        label: label,
        leadingIcon: leadingIcon,
        trailingIcon: trailingIcon,
        gap: dims.iconGap,
      );
    }

    final btn = Semantics(
      button: true,
      label: semanticLabel ?? label,
      enabled: !disabled,
      child: ElevatedButton(
        style: style,
        focusNode: focusNode,
        autofocus: autofocus,
        clipBehavior: clipBehavior,
        onPressed: disabled ? null : onPressed,
        onLongPress: disabled ? null : onLongPress,
        child: child,
      ),
    );

    if (fullWidth) {
      return SizedBox(width: double.infinity, child: btn);
    }
    return btn;
  }
}

// ---- Internal helpers/widgets ------------------------------------------------

class _Dims {
  const _Dims({required this.padding, required this.spinner, required this.iconGap});
  final EdgeInsetsGeometry padding;
  final double spinner;
  final double iconGap;
}

_Dims _dimensionsFor(ButtonSize size) {
  switch (size) {
    case ButtonSize.small:
      return const _Dims(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        spinner: 16,
        iconGap: 8,
      );
    case ButtonSize.large:
      return const _Dims(
        padding: EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        spinner: 20,
        iconGap: 10,
      );
    case ButtonSize.medium:
    default:
      return const _Dims(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        spinner: 18,
        iconGap: 8,
      );
  }
}

class _LabeledRow extends StatelessWidget {
  const _LabeledRow({
    required this.label,
    required this.gap,
    this.leadingIcon,
    this.trailingIcon,
  });

  final String label;
  final double gap;
  final Widget? leadingIcon;
  final Widget? trailingIcon;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];

    if (leadingIcon != null) {
      children.add(leadingIcon!);
      children.add(SizedBox(width: gap));
    }

    children.add(Flexible(
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ));

    if (trailingIcon != null) {
      children.add(SizedBox(width: gap));
      children.add(trailingIcon!);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: children,
    );
  }
}

class _LoadingLabel extends StatelessWidget {
  const _LoadingLabel({
    required this.label,
    required this.progressSize,
  });

  final String label;
  final double progressSize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          height: progressSize,
          width: progressSize,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            valueColor: AlwaysStoppedAnimation<Color>(scheme.onPrimary),
            backgroundColor: scheme.onPrimary.withOpacity(0.22),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
