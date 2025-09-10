// lib/features/auth/login/screens/login_screen.dart


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
import '../../../auth/state/auth_state.dart'; // <-- add this
import '../../../../app/app_router.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _submitting = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
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
      req.headers
        ..set('Accept', 'application/json')
        ..contentType = ContentType.json;
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

      if (!mounted) return;

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final access = (data['access_token'] as String?) ?? '';
        final refresh = (data['refresh_token'] as String?) ?? '';

        // IMPORTANT: let the router know
        AppRouter.setAccessToken(access);

        // (optional) persist to secure storage here

        AppSnackbars.success(context, 'Welcome back!', title: 'Signed in');
        context.go(Routes.home);
      }  else {
        final err = (data['error'] ?? data['message'] ?? 'Login failed.').toString();
        AppSnackbars.error(context, err, title: 'Sign in failed');
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
      appBar: const AppBarPrimary(title: 'Sign in'),
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
                    // Logo + Header
                    Center(
                      child: Column(
                        children: [
                          // Ensure this path exists and is declared in pubspec.yaml
                          Image.asset(
                            'assets/images/logo.png',
                            width: 180,
                            height: 180,
                            fit: BoxFit.contain,
                            // keeps UI clean if asset is missing during dev
                            errorBuilder: (_, __, ___) => const SizedBox(height: 96),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Welcome back',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Sign in to continue shopping.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 22),

                    // Email
                    AppTextField.email(
                      controller: _emailCtrl,
                      validator: Validators.compose([
                        Validators.required(message: 'Email is required.'),
                        Validators.email(),
                      ]),
                      autofocus: true,
                    ),
                    const SizedBox(height: 14),

                    // Password
                    AppTextField.password(
                      controller: _passwordCtrl,
                      validator: Validators.compose([
                        Validators.required(message: 'Password is required.'),
                        Validators.minLength(8, message: 'Use at least 8 characters.'),
                      ]),
                      onSubmitted: (_) {
                        if (!_submitting) _handleLogin();
                      },
                    ),

                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => context.push(Routes.forgot),
                        child: const Text('Forgot password?'),
                      ),
                    ),

                    const SizedBox(height: 8),
                    PrimaryButton(
                      label: _submitting ? 'Signing in…' : 'Sign in',
                      loading: _submitting,
                      fullWidth: true,
                      onPressed: _submitting ? null : _handleLogin,
                    ),

                    const SizedBox(height: 16),

                    // Create account
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('New here?', style: theme.textTheme.bodyMedium),
                        TextButton(
                          onPressed: () => context.push(Routes.register),
                          child: const Text('Create an account'),
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
