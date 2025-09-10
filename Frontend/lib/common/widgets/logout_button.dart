import 'package:flutter/material.dart';

/// A small, self-contained primary action for signing out.
/// Uses Material 3 [FilledButton] and matches the app's rounded style.
class LogoutButton extends StatelessWidget {
  const LogoutButton({
    super.key,
    required this.onPressed,
    this.label = 'Sign out',
    this.fullWidth = true,
    this.loading = false,
  });

  final VoidCallback? onPressed;
  final String label;
  final bool fullWidth;
  final bool loading;

  static const double _kRadius = 14.0;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bool disabled = onPressed == null || loading;

    final child = loading
        ? Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation<Color>(cs.onPrimary),
                  backgroundColor: cs.onPrimary.withOpacity(0.22),
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
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.logout_rounded, size: 18),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Sign out',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );

    final button = FilledButton(
      onPressed: disabled ? null : onPressed,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_kRadius)),
      ),
      child: child,
    );

    return SizedBox(width: fullWidth ? double.infinity : null, child: button);
  }
}
