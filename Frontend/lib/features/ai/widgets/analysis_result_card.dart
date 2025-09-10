
import 'package:flutter/material.dart';

class AnalysisResultCard extends StatelessWidget {
  const AnalysisResultCard({
    super.key,
    this.title,
    this.imageUrl,
    this.saved = false,
    this.updatedAt,
    this.skinTypeLabel,
    this.skinTypeProb,
    this.skinConcerns = const <ConcernScore>[],
    this.otherConcerns = const <ConcernScore>[],
    this.lowConcerns = const <ConcernScore>[],
  });

  /// Build directly from the "combined" response object.
  factory AnalysisResultCard.fromCombined({
    required Map<String, dynamic> combined,
    String? imageUrl,
    bool saved = false,
    DateTime? updatedAt,
    String? title,
  }) {
    String? label;
    double? prob;

    final st = (combined['skin_type'] as Map?)?.cast<String, dynamic>() ?? {};
    final rawLabel = (st['label'] ?? '').toString();
    if (rawLabel.isNotEmpty) label = rawLabel;
    final p = st['prob'];
    if (p is num) prob = p.toDouble();

    List<ConcernScore> _pickList(String key) {
      final list = (combined[key] as List?) ?? const [];
      return list
          .whereType<Map>()
          .map((m) {
            final l = (m['label'] ?? '').toString();
            final pr = (m['prob'] is num) ? (m['prob'] as num).toDouble() : 0.0;
            return ConcernScore(l, pr);
          })
          .toList()
        ..sort((a, b) => b.prob.compareTo(a.prob));
    }

    return AnalysisResultCard(
      title: title,
      imageUrl: imageUrl,
      saved: saved,
      updatedAt: updatedAt,
      skinTypeLabel: label,
      skinTypeProb: prob,
      skinConcerns: _pickList('skin_concerns'),
      otherConcerns: _pickList('other_concerns'),
      lowConcerns: _pickList('low_concerns'),
    );
  }

  final String? title;
  final String? imageUrl;
  final bool saved;
  final DateTime? updatedAt;

  final String? skinTypeLabel;
  final double? skinTypeProb;

  final List<ConcernScore> skinConcerns;
  final List<ConcernScore> otherConcerns;
  final List<ConcernScore> lowConcerns;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final children = <Widget>[];

    if (title != null && title!.trim().isNotEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            title!,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
      );
    }

    if ((imageUrl ?? '').isNotEmpty) {
      children.add(
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: AspectRatio(
            aspectRatio: 1,
            child: Image.network(
              imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: cs.surfaceContainerHighest,
                alignment: Alignment.center,
                child: Icon(Icons.broken_image_outlined, color: cs.onSurfaceVariant),
              ),
            ),
          ),
        ),
      );
      children.add(const SizedBox(height: 12));
    }

    final meta = <Widget>[];
    meta.add(_Chip(label: saved ? 'Saved to profile' : 'Temporary', color: saved ? cs.primary : cs.tertiary));
    if (updatedAt != null) {
      final stamp = updatedAt!.toLocal().toString().split('.').first;
      meta.add(_Chip(label: 'Updated $stamp', color: cs.tertiary));
    }
    if (meta.isNotEmpty) {
      children.add(Wrap(spacing: 8, runSpacing: 8, children: meta));
      children.add(const SizedBox(height: 12));
    }

    children.addAll([
      _SectionHorizontal(
        title: 'Skin type',
        items: [
          if ((skinTypeLabel ?? '').isNotEmpty)
            _Pill(
              label: skinTypeLabel!,
              prob: (skinTypeProb ?? 0.0).clamp(0.0, 1.0),
              color: cs.secondary,
            ),
        ],
        emptyHint: '—',
      ),
      const SizedBox(height: 10),
      _SectionHorizontal(
        title: 'Skin concerns',
        items: skinConcerns
            .map((c) => _Pill(label: _humanize(c.label), prob: c.prob, color: cs.primary))
            .toList(),
      ),
      const SizedBox(height: 10),
      _SectionHorizontal(
        title: 'Other concerns',
        items: otherConcerns
            .map((c) => _Pill(label: _humanize(c.label), prob: c.prob, color: cs.tertiary))
            .toList(),
      ),
      const SizedBox(height: 10),
      _SectionHorizontal(
        title: 'Low concerns',
        items: lowConcerns
            .map((c) => _Pill(label: _humanize(c.label), prob: c.prob, color: cs.outline))
            .toList(),
        muted: true,
      ),
    ]);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _withSpacing(children, 8),
      ),
    );
  }

  List<Widget> _withSpacing(List<Widget> items, double gap) {
    final out = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      out.add(items[i]);
      if (i != items.length - 1) out.add(SizedBox(height: gap));
    }
    return out;
  }
}

// --- Models & small UI pieces -------------------------------------------------

class ConcernScore {
  const ConcernScore(this.label, this.prob);
  final String label;  // e.g. "Acne"
  final double prob;   // 0..1
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.prob, required this.color, this.muted = false});

  final String label;
  final double prob; // 0..1
  final Color color;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pct = (prob.clamp(0, 1) * 100).toStringAsFixed(0);
    final borderColor = muted ? cs.outlineVariant : color;
    final textColor = muted ? cs.onSurfaceVariant : color;

    return Container(
      width: 180,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: (muted ? cs.surfaceVariant : color.withOpacity(0.08)).withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(fontWeight: FontWeight.w800, color: textColor),
                ),
              ),
              Text(
                '$pct%',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(fontWeight: FontWeight.w900, color: textColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: prob.clamp(0.0, 1.0),
              minHeight: 6,
              color: textColor,
              backgroundColor: cs.surfaceContainerHighest,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHorizontal extends StatelessWidget {
  const _SectionHorizontal({
    required this.title,
    required this.items,
    this.emptyHint = 'No items',
    this.muted = false,
  });

  final String title;
  final List<Widget> items;
  final String emptyHint;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style:
              Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        if (items.isEmpty)
          Text(
            emptyHint,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: cs.onSurfaceVariant),
          )
        else
          SizedBox(
            height: 78,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => items[i],
            ),
          ),
      ],
    );
  }
}

String _humanize(String s) {
  if (s.isEmpty) return s;
  return s
      .replaceAll('_', ' ')
      .replaceAll('-', ' ')
      .split(' ')
      .where((p) => p.trim().isNotEmpty)
      .map((p) => p[0].toUpperCase() + p.substring(1))
      .join(' ');
}
