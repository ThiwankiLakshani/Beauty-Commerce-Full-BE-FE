// lib/features/auth/forgot_password/screens/password_request_screen.dart
//


import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_constants.dart';
import '../../../../common/utils/snackbar.dart';
import '../../../../common/utils/validators.dart';
import '../../../../common/widgets/app_bar_primary.dart';
import '../../../../common/widgets/primary_button.dart';
import '../../../../common/widgets/text_field.dart';

class PasswordRequestScreen extends StatefulWidget {
  const PasswordRequestScreen({super.key});

  @override
  State<PasswordRequestScreen> createState() => _PasswordRequestScreenState();
}

class _PasswordRequestScreenState extends State<PasswordRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();

  bool _submitting = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  String get _baseUrl {
    const fromEnv = String.fromEnvironment(Api.envBaseUrlKey, defaultValue: '');
    if (fromEnv.isNotEmpty) return fromEnv;
    // Sensible defaults for local dev
    if (Platform.isIOS || Platform.isMacOS) {
      return Api.defaultBaseUrlIosSimulator; // http://localhost:5000
    }
    return Api.defaultBaseUrlAndroidEmulator; // http://10.0.2.2:5000
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null) return;

    AppSnackbars.dismiss(context);

    if (!form.validate()) {
      AppSnackbars.warning(context, 'Please fix the errors and try again.');
      return;
    }

    setState(() => _submitting = true);

    final email = _emailCtrl.text.trim();
    final uri = Uri.parse('$_baseUrl${Api.authPasswordRequestReset}');
    final client = HttpClient();

    try {
      final req = await client.postUrl(uri);
      req.headers.contentType = ContentType.json;
      req.headers.set('Accept', 'application/json');
      req.add(utf8.encode(jsonEncode(<String, dynamic>{'email': email})));

      final resp = await req.close();
      final body = await resp.transform(utf8.decoder).join();

      Map<String, dynamic> data = {};
      try {
        data = (jsonDecode(body) as Map).cast<String, dynamic>();
      } catch (_) {
        // non-JSON; leave empty to fall back to generic copy
      }

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        // Backend returns {"ok": true} and (TODO) will email a token
        AppSnackbars.success(
          context,
          'If that email exists, we sent a reset link.',
          title: 'Check your inbox',
        );
        if (mounted) context.pop(); // go back (usually to Login)
      } else {
        final err = (data['error'] ?? data['message'] ?? 'Request failed.')
            .toString();
        AppSnackbars.error(context, err, title: 'Couldn’t send email');
      }
    } catch (e) {
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

    return Scaffold(
      appBar: const AppBarPrimary(title: 'Forgot password'),
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.opaque,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: Form(
              key: _formKey,
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Text(
                      'Reset your password',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter your account email. We’ll send you a reset link.',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 24),

                    // Email field
                    AppTextField.email(
                      controller: _emailCtrl,
                      validator: Validators.compose([
                        Validators.required(message: 'Email is required.'),
                        Validators.email(),
                      ]),
                      autofocus: true,
                    ),

                    const SizedBox(height: 16),

                    // Submit
                    PrimaryButton(
                      label: _submitting ? 'Sending…' : 'Send reset link',
                      loading: _submitting,
                      fullWidth: true,
                      onPressed: _submitting ? null : _submit,
                    ),

                    const SizedBox(height: 16),

                    // Back to login
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Remembered your password? ',
                          style: theme.textTheme.bodyMedium,
                        ),
                        TextButton(
                          onPressed: () => context.go(Routes.login),
                          child: const Text('Sign in'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
