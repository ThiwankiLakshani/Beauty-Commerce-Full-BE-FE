// lib/features/reviews/sheets/write_review_sheet.dart
//


import 'package:flutter/material.dart';

import '../../product/widgets/rating_bar.dart'; // for RatingPicker

/// Data returned from the sheet.
class ReviewDraft {
  ReviewDraft({
    required this.rating,
    required this.title,
    required this.body,
  });

  /// 1..5 (or 0 if not selected and enforcement is disabled).
  final int rating;

  /// Optional short title (<= 60 by default).
  final String title;

  /// Optional review text (<= 500 by default).
  final String body;
}

class WriteReviewSheet extends StatefulWidget {
  const WriteReviewSheet({
    super.key,
    this.initialRating = 0,
    this.initialTitle = '',
    this.initialBody = '',
    this.maxTitleLength = 60,
    this.maxBodyLength = 500,
    this.enforceRating = true,
    this.submitLabel = 'Submit',
    this.cancelLabel = 'Cancel',
    this.titleText = 'Write a review',
  });

  final int initialRating;
  final String initialTitle;
  final String initialBody;

  /// Max characters allowed in title.
  final int maxTitleLength;

  /// Max characters allowed in body.
  final int maxBodyLength;

  /// If true, prevents submission when rating == 0.
  final bool enforceRating;

  /// Primary button text.
  final String submitLabel;

  /// Cancel button text.
  final String cancelLabel;

  /// Sheet header title.
  final String titleText;

  @override
  State<WriteReviewSheet> createState() => _WriteReviewSheetState();
}

class _WriteReviewSheetState extends State<WriteReviewSheet> {
  late int _rating;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _bodyCtrl;

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _rating = _clampRating(widget.initialRating);
    _titleCtrl = TextEditingController(text: widget.initialTitle);
    _bodyCtrl = TextEditingController(text: widget.initialBody);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  int _clampRating(int v) {
    if (v < 0) return 0;
    if (v > 5) return 5;
    return v;
  }

  void _onSubmit() {
    if (_submitting) return;

    final ttl = _titleCtrl.text.trim();
    final bdy = _bodyCtrl.text.trim();

    if (widget.enforceRating && _rating == 0) {
      // Local, unobtrusive feedback without external helpers.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a rating.')),
      );
      return;
    }

    setState(() => _submitting = true);

    // Return the draft to the caller; they perform the API request.
    Navigator.of(context).pop(
      ReviewDraft(
        rating: _rating,
        title: ttl,
        body: bdy,
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

            Text(widget.titleText, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),

            // Rating picker
            Row(
              children: [
                Text('Your rating:', style: theme.textTheme.bodyMedium),
                const SizedBox(width: 8),
                RatingPicker(
                  value: _rating,
                  onChanged: (v) => setState(() => _rating = v),
                  size: 28,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Title
            TextField(
              controller: _titleCtrl,
              textInputAction: TextInputAction.next,
              maxLength: widget.maxTitleLength,
              decoration: InputDecoration(
                labelText: 'Title (optional)',
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Body
            TextField(
              controller: _bodyCtrl,
              maxLines: 5,
              maxLength: widget.maxBodyLength,
              decoration: InputDecoration(
                labelText: 'Your review (optional)',
                alignLabelWithHint: true,
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Actions
            Row(
              children: [
                TextButton(
                  onPressed: _submitting
                      ? null
                      : () => Navigator.of(context).pop<ReviewDraft>(null),
                  child: Text(widget.cancelLabel),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _submitting ? null : _onSubmit,
                  child: Text(_submitting ? 'Submitting…' : widget.submitLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
