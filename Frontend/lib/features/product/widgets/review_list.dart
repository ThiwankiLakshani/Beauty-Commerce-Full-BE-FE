// lib/features/product/widgets/review_list.dart
//


import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../app/app_constants.dart';
import '../../../common/utils/snackbar.dart';

class ReviewList extends StatefulWidget {
  const ReviewList({
    super.key,
    required this.productId,
    this.accessToken,
    this.padding = const EdgeInsets.all(16),
    this.allowWrite = true,
  });

  /// Product id (Mongo string id).
  final String productId;

  /// Optional JWT; when present and [allowWrite] is true, shows "Write a review".
  final String? accessToken;

  /// Outer padding for the whole section.
  final EdgeInsetsGeometry padding;

  /// Whether to show the "Write a review" action when authenticated.
  final bool allowWrite;

  @override
  State<ReviewList> createState() => _ReviewListState();
}

class _ReviewListState extends State<ReviewList> {
  bool _loading = true;
  String? _error;
  List<ProductReview> _items = const [];

  String get _baseUrl {
    const fromEnv = String.fromEnvironment(Api.envBaseUrlKey, defaultValue: '');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (Platform.isIOS || Platform.isMacOS) {
      return Api.defaultBaseUrlIosSimulator; // http://localhost:5000
    }
    return Api.defaultBaseUrlAndroidEmulator; // http://10.0.2.2:5000
  }

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
      _items = const [];
    });

    final client = HttpClient();
    try {
      final uri = Uri.parse('$_baseUrl${Api.products}/${widget.productId}/reviews');
      final req = await client.getUrl(uri);
      req.headers.set('Accept', 'application/json');
      final resp = await req.close();
      final body = await resp.transform(utf8.decoder).join();
      if (!mounted) return;

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final map = (jsonDecode(body) as Map).cast<String, dynamic>();
        final items = (map['items'] as List? ?? [])
            .whereType<Map>()
            .map((m) => ProductReview.fromApi(m.cast<String, dynamic>()))
            .toList();
        setState(() {
          _items = items;
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Could not load reviews.';
          _loading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Network problem. Please try again.';
        _loading = false;
      });
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _openWriteSheet() async {
    if ((widget.accessToken ?? '').isEmpty) {
      AppSnackbars.info(context, 'Please log in to write a review.');
      return;
    }

    final submitted = await showModalBottomSheet<_ReviewDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => _WriteReviewSheet(),
    );

    if (submitted == null) return; // canceled

    if (submitted.rating < 1 || submitted.rating > 5) {
      AppSnackbars.warning(context, 'Please select a rating.');
      return;
    }

    final ok = await _submitReview(submitted);
    if (ok && mounted) {
      AppSnackbars.success(context, 'Review posted');
      _fetch();
    }
  }

  Future<bool> _submitReview(_ReviewDraft draft) async {
    final token = widget.accessToken ?? '';
    if (token.isEmpty) return false;

    final client = HttpClient();
    try {
      final uri = Uri.parse('$_baseUrl${Api.products}/${widget.productId}/reviews');
      final req = await client.postUrl(uri);
      req.headers.set('Accept', 'application/json');
      req.headers.set('Content-Type', 'application/json');
      req.headers.set('Authorization', 'Bearer $token');
      req.add(utf8.encode(jsonEncode({
        'rating': draft.rating,
        'title': draft.title.trim(),
        'body': draft.body.trim(),
      })));

      final resp = await req.close();
      await resp.transform(utf8.decoder).join();
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        return true;
      }
      if (mounted) {
        AppSnackbars.error(context, 'Could not post review (${resp.statusCode}).');
      }
      return false;
    } catch (_) {
      if (mounted) AppSnackbars.error(context, 'Network problem. Try again.');
      return false;
    } finally {
      client.close(force: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final canWrite = widget.allowWrite && (widget.accessToken ?? '').isNotEmpty;

    return Padding(
      padding: widget.padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Text('Reviews', style: theme.textTheme.titleMedium),
              const Spacer(),
              if (canWrite)
                OutlinedButton.icon(
                  onPressed: _openWriteSheet,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Write a review'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Body
          if (_loading) const _ReviewsSkeleton()
          else if (_error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Text(
                _error!,
                style: theme.textTheme.bodyMedium?.copyWith(color: cs.error),
              ),
            )
          else if (_items.isEmpty)
            Text(
              'No reviews yet.',
              style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            )
          else
            RefreshIndicator(
              color: cs.primary,
              onRefresh: _fetch,
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: _items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _ReviewTile(_items[i]),
              ),
            ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Model
// -----------------------------------------------------------------------------

class ProductReview {
  final String id;
  final int rating;
  final String userName;
  final String title;
  final String body;
  final DateTime? createdAt;

  ProductReview({
    required this.id,
    required this.rating,
    required this.userName,
    required this.title,
    required this.body,
    required this.createdAt,
  });

  factory ProductReview.fromApi(Map<String, dynamic> m) {
    int _toI(v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
    DateTime? _parse(String? s) {
      if (s == null) return null;
      try {
        return DateTime.tryParse(s);
      } catch (_) {
        return null;
      }
    }

    final user = (m['user_name'] as String?)?.trim() ?? '';
    final ttl = (m['title'] as String?)?.trim() ?? '';
    final bdy = (m['body'] as String?)?.trim() ?? '';

    return ProductReview(
      id: (m['id'] ?? '').toString(),
      rating: _toI(m['rating']),
      userName: user.isEmpty ? 'Anonymous' : user,
      title: ttl,
      body: bdy,
      createdAt: _parse((m['created_at'] as String?)?.toString()),
    );
  }
}

// -----------------------------------------------------------------------------
// Write review bottom sheet
// -----------------------------------------------------------------------------

class _ReviewDraft {
  _ReviewDraft({required this.rating, required this.title, required this.body});
  int rating;
  String title;
  String body;
}

class _WriteReviewSheet extends StatefulWidget {
  @override
  State<_WriteReviewSheet> createState() => _WriteReviewSheetState();
}

class _WriteReviewSheetState extends State<_WriteReviewSheet> {
  int _rating = 0;
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_submitting) return;
    setState(() => _submitting = true);
    // Pop immediately with the draft; parent handles API call and errors.
    Navigator.of(context).pop(
      _ReviewDraft(
        rating: _rating,
        title: _titleCtrl.text,
        body: _bodyCtrl.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.only(bottom: insets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sheet handle
            Center(
              child: Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Text('Write a review', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),

            // Rating picker
            Row(
              children: [
                const Text('Your rating:'),
                const SizedBox(width: 8),
                _StarPicker(
                  value: _rating,
                  onChanged: (v) => setState(() => _rating = v),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Title
            TextField(
              controller: _titleCtrl,
              textInputAction: TextInputAction.next,
              maxLength: 60,
              decoration: InputDecoration(
                labelText: 'Title (optional)',
                counterText: '',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 10),

            // Body
            TextField(
              controller: _bodyCtrl,
              maxLines: 5,
              maxLength: 500,
              decoration: InputDecoration(
                labelText: 'Your review (optional)',
                alignLabelWithHint: true,
                counterText: '',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 14),

            // Actions
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _submitting ? null : _submit,
                    child: const Text('Submit'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Simple interactive star picker (1–5)
class _StarPicker extends StatelessWidget {
  const _StarPicker({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: List.generate(5, (i) {
        final idx = i + 1;
        final filled = idx <= value;
        return InkWell(
          onTap: () => onChanged(idx),
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Icon(
              filled ? Icons.star_rounded : Icons.star_border_rounded,
              color: filled ? cs.primary : cs.outline,
              size: 24,
            ),
          ),
        );
      }),
    );
  }
}

// -----------------------------------------------------------------------------
// Tiles & Skeletons
// -----------------------------------------------------------------------------

class _ReviewTile extends StatelessWidget {
  const _ReviewTile(this.item);
  final ProductReview item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final dt = item.createdAt;
    final dateStr = dt == null
        ? ''
        : '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: name + rating + date
          Row(
            children: [
              Expanded(
                child: Text(
                  item.userName, // never null/empty (defaults to "Anonymous")
                  style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Row(
                children: List.generate(5, (i) {
                  return Icon(
                    i < item.rating ? Icons.star_rounded : Icons.star_border_rounded,
                    size: 16,
                    color: cs.primary,
                  );
                }),
              ),
              if (dateStr.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  dateStr,
                  style: theme.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ],
          ),
          if (item.title.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              item.title,
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
          if (item.body.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(item.body, style: theme.textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}

class _ReviewsSkeleton extends StatelessWidget {
  const _ReviewsSkeleton();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: List.generate(3, (_) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _bar(cs, 120, 14),
                const SizedBox(height: 8),
                _bar(cs, double.infinity, 12),
                const SizedBox(height: 6),
                _bar(cs, 200, 12),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _bar(ColorScheme cs, double w, double h) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}
