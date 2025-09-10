// lib/features/auth/login/widgets/login_form.dart


import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../../app/app_constants.dart';
import '../../../../../common/utils/snackbar.dart';
import '../../../../../common/utils/validators.dart';
import '../../../../../common/widgets/primary_button.dart';
import '../../../../../common/widgets/text_field.dart';

class LoginForm extends StatefulWidget {
  const LoginForm({
    super.key,
    this.onSuccess,
    this.initialEmail,
    this.showHeader = false,
    this.animated = true,
  });

  /// Called on success with `{access_token, refresh_token, user}`.
  final void Function(Map<String, dynamic> authPayload)? onSuccess;

  /// Optional pre-filled email.
  final String? initialEmail;

  /// If true, shows a small header text above fields.
  final bool showHeader;

  /// If false, renders instantly (no entrance animations).
  final bool animated;

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _emailCtrl =
      TextEditingController(text: widget.initialEmail ?? '');
  final _passwordCtrl = TextEditingController();

  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );

  late final Animation<double> _fadeAll =
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);

  late final Animation<Offset> _slideEmail =
      Tween(begin: const Offset(0, .18), end: Offset.zero)
          .animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.55, curve: Curves.easeOut)));

  late final Animation<Offset> _slidePass =
      Tween(begin: const Offset(0, .20), end: Offset.zero)
          .animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0.15, 0.70, curve: Curves.easeOut)));

  late final Animation<Offset> _slideHelpers =
      Tween(begin: const Offset(0, .22), end: Offset.zero)
          .animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0.30, 0.82, curve: Curves.easeOut)));

  late final Animation<Offset> _slideButton =
      Tween(begin: const Offset(0, .24), end: Offset.zero)
          .animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0.45, 1.0, curve: Curves.easeOut)));

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.animated) {
      // Small delay for nicer entrance when page changes.
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _ctrl.forward();
      });
    } else {
      _ctrl.value = 1.0;
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  String get _baseUrl {
    const fromEnv = String.fromEnvironment(Api.envBaseUrlKey, defaultValue: '');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (Platform.isIOS || Platform.isMacOS) return Api.defaultBaseUrlIosSimulator;
    return Api.defaultBaseUrlAndroidEmulator;
  }

  Future<void> _handleLogin() async {
    final form = _formKey.currentState;
    if (form == null) return;

    AppSnackbars.dismiss(context);

    if (!form.validate()) {
      AppSnackbars.warning(context, 'Please fix the errors and try again.');
      return;
    }

    setState(() => _submitting = true);

    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    final uri = Uri.parse('$_baseUrl${Api.authLogin}');
    final client = HttpClient();

    try {
      final req = await client.postUrl(uri);
      req.headers.set('Accept', 'application/json');
      req.headers.contentType = ContentType.json;
      req.add(utf8.encode(jsonEncode(<String, dynamic>{
        'email': email,
        'password': password,
      })));

      final resp = await req.close();
      final body = await resp.transform(utf8.decoder).join();

      Map<String, dynamic> data = {};
      try {
        data = (jsonDecode(body) as Map).cast<String, dynamic>();
      } catch (_) {}

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        AppSnackbars.success(context, 'Welcome back!', title: 'Signed in');
        widget.onSuccess?.call(data);
      } else {
        final err = (data['error'] ?? data['message'] ?? 'Login failed.').toString();
        AppSnackbars.error(context, err, title: 'Sign in failed');
      }
    } catch (_) {
      AppSnackbars.error(
        context,
        'Could not connect to the server. Please check your connection.',
        title: 'Network error',
      );
    } finally {
      client.close(force: true);
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return FadeTransition(
      opacity: _fadeAll,
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.showHeader) ...[
                Text(
                  'Welcome back',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  'Sign in to continue shopping.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 20),
              ],

              // Email
              SlideTransition(
                position: _slideEmail,
                child: AppTextField.email(
                  controller: _emailCtrl,
                  validator: Validators.compose([
                    Validators.required(message: 'Email is required.'),
                    Validators.email(),
                  ]),
                  autofocus: !widget.showHeader,
                ),
              ),
              const SizedBox(height: 12),

              // Password
              SlideTransition(
                position: _slidePass,
                child: AppTextField.password(
                  controller: _passwordCtrl,
                  validator: Validators.compose([
                    Validators.required(message: 'Password is required.'),
                    Validators.minLength(8, message: 'Use at least 8 characters.'),
                  ]),
                  onSubmitted: (_) {
                    if (!_submitting) _handleLogin();
                  },
                ),
              ),

              // Forgot
              const SizedBox(height: 8),
              SlideTransition(
                position: _slideHelpers,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => context.push(Routes.forgot),
                    child: const Text('Forgot password?'),
                  ),
                ),
              ),

              // Submit
              const SizedBox(height: 6),
              SlideTransition(
                position: _slideButton,
                child: PrimaryButton(
                  label: _submitting ? 'Signing in…' : 'Sign in',
                  loading: _submitting,
                  fullWidth: true,
                  onPressed: _submitting ? null : _handleLogin,
                ),
              ),

              // Create account
              const SizedBox(height: 18),
              SlideTransition(
                position: _slideHelpers,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('New here?', style: theme.textTheme.bodyMedium),
                    TextButton(
                      onPressed: () => context.push(Routes.register),
                      child: const Text('Create an account'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
