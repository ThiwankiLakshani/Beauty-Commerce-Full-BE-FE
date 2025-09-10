// lib/features/account/widgets/account_header.dart
//


import 'package:flutter/material.dart';

class AccountHeader extends StatelessWidget {
  const AccountHeader({
    super.key,
    required this.name,
    required this.email,
    this.imageUrl,
    this.onTap,
    this.trailing,
    this.compact = false,
    this.showEmail = true,
    this.avatarIcon = Icons.person_outline,
  });

  /// Display name (shown bold). Pass empty string for placeholder.
  final String name;

  /// Email or secondary text (muted). Hidden if [showEmail] is false.
  final String email;

  /// Optional absolute URL to avatar image.
  final String? imageUrl;

  /// Tap handler for the whole card (optional).
  final VoidCallback? onTap;

  /// Optional trailing widget (e.g., an edit button).
  final Widget? trailing;

  /// Slightly smaller paddings when true.
  final bool compact;

  /// Show or hide the email row.
  final bool showEmail;

  /// Fallback icon when [imageUrl] is null/empty/broken.
  final IconData avatarIcon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pad = compact ? const EdgeInsets.all(12) : const EdgeInsets.all(16);
    final radius = BorderRadius.circular(16);

    final content = Row(
      children: [
        _Avatar(
          imageUrl: imageUrl,
          fallbackIcon: avatarIcon,
          compact: compact,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _NameEmail(
            name: name,
            email: email,
            showEmail: showEmail,
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          IconTheme(
            data: IconThemeData(color: cs.onSurfaceVariant),
            child: trailing!,
          ),
        ],
      ],
    );

    final card = Container(
      padding: pad,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: radius,
        border: Border.all(color: cs.outlineVariant),
      ),
      child: content,
    );

    if (onTap == null) return card;

    return InkWell(
      onTap: onTap,
      borderRadius: radius,
      child: card,
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.imageUrl,
    required this.fallbackIcon,
    required this.compact,
  });

  final String? imageUrl;
  final IconData fallbackIcon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final r = compact ? 22.0 : 28.0;

    final hasUrl = imageUrl != null && imageUrl!.trim().isNotEmpty;

    return CircleAvatar(
      radius: r,
      backgroundColor: cs.primary.withOpacity(0.12),
      foregroundImage: hasUrl
          ? NetworkImage(imageUrl!)
          : null, // if null, we show the icon below
      onForegroundImageError: (_, __) {},
      child: Icon(fallbackIcon, color: cs.primary, size: compact ? 22 : 28),
    );
  }
}

class _NameEmail extends StatelessWidget {
  const _NameEmail({
    required this.name,
    required this.email,
    required this.showEmail,
  });

  final String name;
  final String email;
  final bool showEmail;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name.isEmpty ? 'Your Account' : name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w900),
        ),
        if (showEmail) ...[
          const SizedBox(height: 4),
          Text(
            email.isEmpty ? '—' : email,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}
