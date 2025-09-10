// lib/app/theme_controller.dart
import 'package:flutter/material.dart';

/// Simple app-wide theme controller (singleton).
class ThemeController extends ChangeNotifier {
  ThemeController._internal();
  /// Global instance you can access anywhere.
  static final ThemeController instance = ThemeController._internal();

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  /// Set a new ThemeMode and notify listeners.
  void setMode(ThemeMode mode) {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
  }

  /// Optional helper to cycle themes (not required).
  void cycle() {
    switch (_mode) {
      case ThemeMode.system:
        setMode(ThemeMode.light);
        break;
      case ThemeMode.light:
        setMode(ThemeMode.dark);
        break;
      case ThemeMode.dark:
        setMode(ThemeMode.system);
        break;
    }
  }
}
