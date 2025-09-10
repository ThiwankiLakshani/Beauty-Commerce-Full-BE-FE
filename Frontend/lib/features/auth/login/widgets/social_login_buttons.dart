// lib/features/auth/login/widgets/social_login_buttons.dart


import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class SocialLoginButtons extends StatelessWidget {
  const SocialLoginButtons({
    super.key,
    this.onGoogle,
    this.onApple,
    this.onFacebook,
    this.showApple, // null => auto (iOS/macOS)
    this.showFacebook = true,
    this.spacing = 10,
    this.buttonHeight = 48,
    this.fullWidth = true,
    this.padding = const EdgeInsets.symmetric(vertical: 4),
  });

  /// Tap callbacks (add only those you support)
  final VoidCallback? onGoogle;
  final VoidCallback? onApple;
  final VoidCallback? onFacebook;

  /// Control visibility (Apple auto-detected if null).
  final bool? showApple;
  final bool showFacebook;

  /// Layout
  final double spacing;
  final double buttonHeight;
  final bool fullWidth;
  final EdgeInsetsGeometry padding;

  bool _isCupertinoPlatform(BuildContext context) {
    // Avoid dart:io for web compatibility.
    final p = Theme.of(context).platform;
    return p == TargetPlatform.iOS || p == TargetPlatform.macOS;
  }

  @override
  Widget build(BuildContext context) {
    final wantApple = showApple ?? _isCupertinoPlatform(context);

    final items = <Widget>[];
    if (onGoogle != null) items.add(_GoogleButton(onPressed: onGoogle!, height: buttonHeight));
    if (onFacebook != null && showFacebook) {
      items.add(SizedBox(height: spacing));
      items.add(_FacebookButton(onPressed: onFacebook!, height: buttonHeight));
    }
    if (onApple != null && wantApple) {
      items.add(SizedBox(height: spacing));
      items.add(_AppleButton(onPressed: onApple!, height: buttonHeight));
    }

    if (items.isEmpty) return const SizedBox.shrink();

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: items,
    );

    if (fullWidth) {
      return Padding(padding: padding, child: content);
    }
    return Padding(
      padding: padding,
      child: Align(
        alignment: Alignment.center,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 240, maxWidth: 420),
          child: content,
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Individual brand buttons
// -----------------------------------------------------------------------------

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.onPressed, required this.height});

  final VoidCallback onPressed;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final radius = BorderRadius.circular(14);

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: Size(double.infinity, height),
        side: BorderSide(color: cs.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        foregroundColor: cs.onSurface,
        backgroundColor: theme.inputDecorationTheme.fillColor ?? cs.surface,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _GoogleGlyph(),
          const SizedBox(width: 10),
          const Flexible(
            child: Text(
              'Continue with Google',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _AppleButton extends StatelessWidget {
  const _AppleButton({required this.onPressed, required this.height});

  final VoidCallback onPressed;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(14);

    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        minimumSize: Size(double.infinity, height),
        shape: RoundedRectangleBorder(borderRadius: radius),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        textStyle: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.apple, size: 22),
          SizedBox(width: 10),
          Flexible(
            child: Text(
              'Continue with Apple',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _FacebookButton extends StatelessWidget {
  const _FacebookButton({required this.onPressed, required this.height});

  final VoidCallback onPressed;
  final double height;

  static const Color _fbBlue = Color(0xFF1877F2);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(14);

    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        minimumSize: Size(double.infinity, height),
        shape: RoundedRectangleBorder(borderRadius: radius),
        backgroundColor: _fbBlue,
        foregroundColor: Colors.white,
        textStyle: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.facebook, size: 22),
          SizedBox(width: 10),
          Flexible(
            child: Text(
              'Continue with Facebook',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Simple "G" glyph (since we aren’t bundling brand assets here)
// -----------------------------------------------------------------------------

class _GoogleGlyph extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Text(
        'G',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: cs.onSurface,
          fontSize: 14,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
