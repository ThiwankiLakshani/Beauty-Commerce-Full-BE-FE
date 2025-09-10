// lib/features/auth/forgot_password/screens/password_reset_screen.dart

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

class PasswordResetScreen extends StatefulWidget {
  const PasswordResetScreen({super.key, this.prefilledToken});

  /// If you deep-link to this page with a known token, pass it here to prefill.
  final String? prefilledToken;

  @override
  State<PasswordResetScreen> createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends State<PasswordResetScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _tokenCtrl =
      TextEditingController(text: widget.prefilledToken ?? '');
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _submitting = false;

  @override
  void dispose() {
    _tokenCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  String get _baseUrl {
    const fromEnv = String.fromEnvironment(Api.envBaseUrlKey, defaultValue: '');
    if (fromEnv.isNotEmpty) return fromEnv;
    // Local dev sensible defaults
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

    final token = _tokenCtrl.text.trim();
    final newPassword = _passwordCtrl.text;

    final uri = Uri.parse('$_baseUrl${Api.authPasswordReset}');
    final client = HttpClient();

    try {
      final req = await client.postUrl(uri);
      req.headers.contentType = ContentType.json;
      req.headers.set('Accept', 'application/json');
      req.add(utf8.encode(jsonEncode(<String, dynamic>{
        'token': token,
        'password': newPassword,
      })));

      final resp = await req.close();
      final body = await resp.transform(utf8.decoder).join();

      Map<String, dynamic> data = {};
      try {
        data = (jsonDecode(body) as Map).cast<String, dynamic>();
      } catch (_) {
        // non-JSON; keep empty to show generic msg if needed
      }

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        AppSnackbars.success(
          context,
          'Your password has been updated.',
          title: 'Success',
        );
        if (mounted) context.go(Routes.login);
      } else {
        final err = (data['error'] ?? data['message'] ?? 'Reset failed.')
            .toString();
        AppSnackbars.error(context, err, title: 'Couldn’t reset password');
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
      appBar: const AppBarPrimary(title: 'Reset password'),
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
                      'Choose a new password',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Paste the reset code from your email, then set a new password.',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 24),

                    // Token
                    AppTextField(
                      controller: _tokenCtrl,
                      label: 'Reset code',
                      hint: 'e.g. ab12cd34ef56',
                      prefixIcon:
                          const Icon(Icons.vpn_key_outlined, size: 22),
                      textInputAction: TextInputAction.next,
                      validator: Validators.required(
                          message: 'Reset code is required.'),
                      autofocus: widget.prefilledToken == null,
                      showClearButton: true,
                    ),
                    const SizedBox(height: 14),

                    // New password
                    AppTextField.password(
                      controller: _passwordCtrl,
                      label: 'New password',
                      validator: Validators.compose([
                        Validators.required(message: 'Password is required.'),
                        Validators.passwordStrong(minLength: 8),
                      ]),
                      onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                    ),
                    const SizedBox(height: 14),

                    // Confirm password
                    AppTextField.password(
                      controller: _confirmCtrl,
                      label: 'Confirm new password',
                      validator: Validators.compose([
                        Validators.required(
                            message: 'Please confirm your password.'),
                        Validators.matchController(_passwordCtrl,
                            message: 'Passwords do not match.'),
                      ]),
                      onSubmitted: (_) {
                        if (!_submitting) _submit();
                      },
                    ),

                    const SizedBox(height: 16),

                    // Submit
                    PrimaryButton(
                      label: _submitting ? 'Updating…' : 'Update password',
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
