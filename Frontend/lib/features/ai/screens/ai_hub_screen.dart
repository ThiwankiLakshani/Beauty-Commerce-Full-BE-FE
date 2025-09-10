// lib/features/ai/screens/ai_hub_screen.dart


import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../common/widgets/app_bar_primary.dart';
import '../../../common/widgets/primary_button.dart';

class AiHubScreen extends StatelessWidget {
  const AiHubScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget card({
      required IconData icon,
      required String title,
      required String subtitle,
      required String cta,
      required VoidCallback onPressed,
    }) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: cs.primary.withOpacity(0.12),
              child: Icon(icon, color: cs.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            PrimaryButton(
              label: cta,
              onPressed: onPressed,
              size: ButtonSize.small,
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: const AppBarPrimary(title: 'AI'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          card(
            icon: Icons.auto_awesome,
            title: 'Analyze a photo',
            subtitle: 'Paste an image URL or Base64 to get skin insights.',
            cta: 'Analyze',
            onPressed: () => context.pushNamed('ai_analyze'),
          ),
          const SizedBox(height: 12),
          card(
            icon: Icons.face_retouching_natural_outlined,
            title: 'Your AI profile',
            subtitle: 'View your saved analysis and detected concerns.',
            cta: 'Open',
            onPressed: () => context.pushNamed('ai_profile'),
          ),
        ],
      ),
    );
  }
}
