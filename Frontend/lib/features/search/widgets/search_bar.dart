// lib/features/search/widgets/search_bar.dart
//


import 'package:flutter/material.dart';

import '../../../common/widgets/text_field.dart';

class SearchBar extends StatelessWidget {
  const SearchBar({
    super.key,
    required this.controller,
    this.hint = 'Search',
    this.onSubmitted,
    this.autofocus = false,
    this.showBack = false,
    this.onBack,
    this.trailing,
    this.padding = EdgeInsets.zero,
  });

  /// Controls the search text.
  final TextEditingController controller;

  /// Placeholder to show when empty.
  final String hint;

  /// Called when the user submits from the keyboard.
  /// Signature matches `AppTextField.search` → `(String? value)`.
  final ValueChanged<String?>? onSubmitted;

  /// Whether to focus the field on build.
  final bool autofocus;

  /// Show a leading back button.
  final bool showBack;

  /// Back button callback. If null while [showBack] is true, defaults to `Navigator.maybePop`.
  final VoidCallback? onBack;

  /// Optional trailing widgets (e.g., filter/sort buttons).
  final List<Widget>? trailing;

  /// Outer padding for the whole search bar row.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final backBtn = showBack
        ? Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SizedBox(
              width: 44,
              height: 44,
              child: IconButton(
                tooltip: 'Back',
                onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            ),
          )
        : const SizedBox.shrink();

    final tail = (trailing == null || trailing!.isEmpty)
        ? const SizedBox.shrink()
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: trailing!
                .map(
                  (w) => Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: SizedBox(height: 44, child: Center(child: w)),
                  ),
                )
                .toList(),
          );

    return Padding(
      padding: padding,
      child: Row(
        children: [
          backBtn,
          // Search input
          Expanded(
            child: AppTextField.search(
              controller: controller,
              hint: hint,
              showClearButton: true,
              onSubmitted: onSubmitted,
              autofocus: autofocus,
            ),
          ),
          // Trailing actions
          if (trailing != null && trailing!.isNotEmpty) ...[
            const SizedBox(width: 8),
            tail,
          ],
        ],
      ),
    );
  }
}
