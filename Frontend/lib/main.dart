// lib/main.dart
import 'package:flutter/material.dart';

import 'app/app_theme.dart';
import 'app/app_router.dart';
import 'features/auth/state/auth_state.dart';
import 'app/theme_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Simple in-memory auth store for this session.
  final auth = AuthState();

  runApp(
    AuthScope( // provides AuthState to the whole app
      notifier: auth,
      child: const BeautyCommerceApp(),
    ),
  );
}

class BeautyCommerceApp extends StatefulWidget {
  const BeautyCommerceApp({super.key});

  @override
  State<BeautyCommerceApp> createState() => _BeautyCommerceAppState();
}

class _BeautyCommerceAppState extends State<BeautyCommerceApp> {
  final ThemeController _theme = ThemeController.instance;

  @override
  Widget build(BuildContext context) {
    // Rebuild MaterialApp whenever the theme mode changes.
    return AnimatedBuilder(
      animation: _theme,
      builder: (context, _) {
        return MaterialApp.router(
          debugShowCheckedModeBanner: false,
          title: 'Beauty Commerce',
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: _theme.mode, // live theme switching
          routerConfig: AppRouter.router, // your existing go_router instance
        );
      },
    );
  }
}
