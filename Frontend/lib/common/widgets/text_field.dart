// lib/common/widgets/text_field.dart
//


import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.initialValue,
    this.label,
    this.hint,
    this.helperText,
    this.errorText, // optional direct error override (Form validator still supported)
    this.prefixIcon,
    this.suffixIcon,
    this.showClearButton = false,
    this.isPassword = false,
    this.obscureText, // if provided, overrides isPassword default
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.validator,
    this.enabled,
    this.readOnly = false,
    this.autofocus = false,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.focusNode,
    this.inputFormatters,
    this.minLines,
    this.maxLines = 1,
    this.maxLength,
    this.showCounter = false,
    this.contentPadding,
    this.fillColor,
    this.borderRadius,
  })  : assert(
          controller == null || initialValue == null,
          'Provide either a controller OR an initialValue, not both.',
        ),
        assert(
          !(isPassword == true && (maxLines != null && maxLines != 1)),
          'Password fields must be single-line (maxLines should be 1).',
        );

  // ---------------- Named factory constructors (so you can call AppTextField.email / .password) ----------------

  factory AppTextField.email({
    Key? key,
    TextEditingController? controller,
    String? initialValue,
    String? label = 'Email',
    String? hint = 'you@example.com',
    FormFieldValidator<String>? validator,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
    bool autofocus = false,
    bool? enabled,
    bool readOnly = false,
    bool showClearButton = true,
    Widget? prefixIcon,
  }) {
    return AppTextField(
      key: key,
      controller: controller,
      initialValue: controller == null ? initialValue : null,
      label: label,
      hint: hint,
      prefixIcon: prefixIcon ?? const Icon(Icons.alternate_email_rounded),
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      validator: validator,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      autofocus: autofocus,
      enabled: enabled,
      readOnly: readOnly,
      showClearButton: showClearButton,
      maxLines: 1,
    );
  }

  factory AppTextField.password({
    Key? key,
    TextEditingController? controller,
    String? initialValue,
    String? label = 'Password',
    String? hint,
    FormFieldValidator<String>? validator,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
    bool autofocus = false,
    bool? enabled,
    bool readOnly = false,
    Widget? prefixIcon,
  }) {
    return AppTextField(
      key: key,
      controller: controller,
      initialValue: controller == null ? initialValue : null,
      label: label,
      hint: hint,
      prefixIcon: prefixIcon ?? const Icon(Icons.lock_outline_rounded),
      isPassword: true,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: TextInputAction.done,
      validator: validator,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      autofocus: autofocus,
      enabled: enabled,
      readOnly: readOnly,
      maxLines: 1,
    );
  }

  factory AppTextField.search({
    Key? key,
    TextEditingController? controller,
    String? initialValue,
    String? label,
    String? hint = 'Search products',
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
    bool autofocus = false,
    bool? enabled,
    bool readOnly = false,
    bool showClearButton = true,
    TextInputAction textInputAction = TextInputAction.search,
    Widget? prefixIcon,
  }) {
    return AppTextField(
      key: key,
      controller: controller,
      initialValue: controller == null ? initialValue : null,
      label: label,
      hint: hint,
      prefixIcon: prefixIcon ?? const Icon(Icons.search_rounded),
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      autofocus: autofocus,
      enabled: enabled,
      readOnly: readOnly,
      showClearButton: showClearButton,
      keyboardType: TextInputType.text,
      textInputAction: textInputAction,
      maxLines: 1,
    );
  }

  /// Controller for the field. If null, an internal controller is created.
  final TextEditingController? controller;

  /// Initial value if no controller is provided.
  final String? initialValue;

  /// Label text shown as the floating label.
  final String? label;

  /// Hint text shown inside the field when empty.
  final String? hint;

  /// Helper text below the field.
  final String? helperText;

  /// Direct error text (useful for server errors). If provided, it overrides validator’s message.
  final String? errorText;

  /// Leading icon inside the field.
  final Widget? prefixIcon;

  /// Trailing icon inside the field (before clear/visibility buttons).
  final Widget? suffixIcon;

  /// Shows a one-tap clear button when there is text and a controller is present.
  final bool showClearButton;

  /// If true, the field behaves like a password field (with visibility toggle).
  final bool isPassword;

  /// Explicit control over obscureText; if null, uses [isPassword].
  final bool? obscureText;

  /// Callbacks
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;

  /// Validator for use inside a Form.
  final FormFieldValidator<String>? validator;

  /// Enable/disable the field.
  final bool? enabled;

  /// Read-only (still focusable unless also disabled).
  final bool readOnly;

  /// Auto-focus on mount.
  final bool autofocus;

  /// Keyboard behavior
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;

  /// Focus / formatting
  final FocusNode? focusNode;
  final List<TextInputFormatter>? inputFormatters;

  /// Layout
  final int? minLines;
  final int? maxLines;
  final int? maxLength;
  final bool showCounter; // show "x / max" counter if true and maxLength given
  final EdgeInsetsGeometry? contentPadding;
  final Color? fillColor;
  final double? borderRadius;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late final TextEditingController _internalController;
  TextEditingController get _controller =>
      widget.controller ?? _internalController;

  late bool _obscure;

  @override
  void initState() {
    super.initState();
    _internalController = TextEditingController(text: widget.initialValue);
    _obscure = widget.obscureText ?? widget.isPassword;
    // rebuild to show/hide clear button dynamically
    _controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant AppTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update listeners if controller instance changed
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onControllerChanged);
      _controller.addListener(_onControllerChanged);
    }
    // Update obscure if externally controlled
    if (widget.obscureText != null && widget.obscureText != _obscure) {
      setState(() => _obscure = widget.obscureText!);
    }
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    // Only dispose the internal controller we created
    if (widget.controller == null) {
      _internalController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final radius = widget.borderRadius ?? 14.0;

    // Compose suffix: user-provided suffixIcon, optional clear, optional visibility toggle.
    final suffixes = <Widget>[];
    if (widget.suffixIcon != null) {
      suffixes.add(widget.suffixIcon!);
    }
    if (widget.showClearButton &&
        widget.controller != null &&
        _controller.text.isNotEmpty) {
      suffixes.add(_iconButton(
        context,
        icon: Icons.close_rounded,
        tooltip: 'Clear',
        onTap: () {
          _controller.clear();
          widget.onChanged?.call('');
        },
      ));
    }
    if (widget.isPassword) {
      suffixes.add(_iconButton(
        context,
        icon:
            _obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded,
        tooltip: _obscure ? 'Show password' : 'Hide password',
        onTap: () => setState(() => _obscure = !_obscure),
      ));
    }

    final decoration = InputDecoration(
      labelText: widget.label,
      hintText: widget.hint,
      helperText: widget.helperText,
      errorText: widget.errorText,
      prefixIcon: widget.prefixIcon,
      suffixIcon: suffixes.isEmpty
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < suffixes.length; i++) ...[
                  if (i > 0) const SizedBox(width: 4),
                  suffixes[i],
                ],
              ],
            ),
      filled: true,
      fillColor: widget.fillColor ?? theme.inputDecorationTheme.fillColor,
      contentPadding: widget.contentPadding ??
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      counterText:
          (widget.maxLength != null && widget.showCounter) ? null : '',
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide(color: cs.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide(color: cs.primary, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide(color: cs.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide(color: cs.error, width: 1.4),
      ),
    );

    return TextFormField(
      controller: widget.controller != null ? widget.controller : _internalController,
      initialValue: widget.controller == null ? null : null, // must be null when controller is used
      onTap: widget.onTap,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onSubmitted,
      validator: widget.validator,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      autofocus: widget.autofocus,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      textCapitalization: widget.textCapitalization,
      focusNode: widget.focusNode,
      inputFormatters: widget.inputFormatters,
      minLines: widget.minLines,
      maxLines: widget.isPassword ? 1 : widget.maxLines,
      maxLength: widget.maxLength,
      obscureText: _obscure,
      decoration: decoration,
    );
  }

  Widget _iconButton(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 20,
        child: Icon(icon, size: 20, color: cs.onSurfaceVariant),
      ),
    );
    // Using InkResponse (instead of IconButton) keeps suffix height compact.
  }
}
