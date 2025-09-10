// lib/features/auth/register/screens/register_screen.dart
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

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _submitting = false;
  bool _agreed = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  String get _baseUrl {
    const fromEnv = String.fromEnvironment(Api.envBaseUrlKey, defaultValue: '');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (Platform.isIOS || Platform.isMacOS) return Api.defaultBaseUrlIosSimulator;
    return Api.defaultBaseUrlAndroidEmulator;
  }

  Future<void> _handleRegister() async {
    final form = _formKey.currentState;
    if (form == null) return;

    AppSnackbars.dismiss(context);

    if (!form.validate()) {
      AppSnackbars.warning(context, 'Please fix the errors and try again.');
      return;
    }

    setState(() => _submitting = true);

    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    final uri = Uri.parse('$_baseUrl${Api.authRegister}');
    final client = HttpClient();

    try {
      final req = await client.postUrl(uri);
      req.headers
        ..set('Accept', 'application/json')
        ..contentType = ContentType.json;
      req.add(utf8.encode(jsonEncode(<String, dynamic>{
        'name': name,
        'email': email,
        'password': password,
      })));

      final resp = await req.close();
      final body = await resp.transform(utf8.decoder).join();

      Map<String, dynamic> data = {};
      try {
        data = (jsonDecode(body) as Map).cast<String, dynamic>();
      } catch (_) {}

      if (!mounted) return;

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        AppSnackbars.success(context, 'Account created!', title: 'Welcome');
        // Expected: {access_token, refresh_token, user: {...}}
        // TODO: Persist tokens & user securely for your app.
        context.go(Routes.home);
      } else {
        final err =
            (data['error'] ?? data['message'] ?? 'Registration failed.').toString();
        AppSnackbars.error(context, err, title: 'Sign up failed');
      }
    } catch (_) {
      if (!mounted) return;
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
      backgroundColor: Colors.white,
      appBar: const AppBarPrimary(title: 'Create account'),
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
                    // Logo + Header (matches Login)
                    Center(
                      child: Column(
                        children: [
                          Image.asset(
                            'assets/images/logo.png',
                            width: 180,
                            height: 180,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const SizedBox(height: 96),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Create your account',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Join ${AppInfo.appName} to start shopping.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 22),

                    // Full name
                    AppTextField(
                      controller: _nameCtrl,
                      label: 'Full name',
                      hint: 'John Doe',
                      prefixIcon: const Icon(Icons.person_outline_rounded),
                      validator: Validators.compose([
                        Validators.required(message: 'Name is required.'),
                        Validators.minLength(2, message: 'Enter your full name.'),
                      ]),
                    ),
                    const SizedBox(height: 14),

                    // Email
                    AppTextField.email(
                      controller: _emailCtrl,
                      validator: Validators.compose([
                        Validators.required(message: 'Email is required.'),
                        Validators.email(),
                      ]),
                      autofocus: false,
                    ),
                    const SizedBox(height: 14),

                    // Password
                    AppTextField.password(
                      controller: _passwordCtrl,
                      validator: Validators.compose([
                        Validators.required(message: 'Password is required.'),
                        Validators.passwordStrong(minLength: 8),
                      ]),
                      onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                    ),
                    const SizedBox(height: 14),

                    // Confirm Password (use base field to avoid constructor mismatch)
                    AppTextField(
                      controller: _confirmCtrl,
                      label: 'Confirm password',
                      hint: 'Re-enter password',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      obscureText: true,
                      validator: Validators.compose([
                        Validators.required(message: 'Please confirm password.'),
                        Validators.matchController(
                          _passwordCtrl,
                          message: 'Passwords do not match.',
                        ),
                      ]),
                      onSubmitted: (_) {
                        if (!_submitting) _handleRegister();
                      },
                    ),

                    const SizedBox(height: 12),

                    // Terms checkbox (must be checked)
                    FormField<bool>(
                      initialValue: _agreed,
                      validator: Validators.mustBeTrue(
                        message: 'Please accept the Terms to continue.',
                      ),
                      builder: (state) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CheckboxListTile(
                              value: _agreed,
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              title: Text.rich(
                                TextSpan(
                                  text: 'I agree to the ',
                                  style: theme.textTheme.bodyMedium,
                                  children: [
                                    TextSpan(
                                      text: 'Terms & Conditions',
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: cs.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const TextSpan(text: ' and '),
                                    TextSpan(
                                      text: 'Privacy Policy',
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: cs.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              onChanged: (v) {
                                setState(() {
                                  _agreed = v ?? false;
                                });
                                state.didChange(v);
                              },
                            ),
                            if (state.hasError)
                              Padding(
                                padding: const EdgeInsets.only(left: 12, top: 4),
                                child: Text(
                                  state.errorText!,
                                  style: theme.textTheme.bodySmall
                                      ?.copyWith(color: cs.error),
                                ),
                              ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 10),

                    // Submit
                    PrimaryButton(
                      label: _submitting ? 'Creating account…' : 'Create account',
                      loading: _submitting,
                      fullWidth: true,
                      onPressed: _submitting ? null : _handleRegister,
                    ),

                    const SizedBox(height: 16),

                    // Already have an account
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Already have an account?', style: theme.textTheme.bodyMedium),
                        TextButton(
                          onPressed: () => context.push(Routes.login),
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
