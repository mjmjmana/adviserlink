import 'package:flutter/material.dart';
import 'theme.dart';

/// ThemeProvider manages the app's theme mode and notifies listeners on change
class ThemeProvider extends ChangeNotifier {
  AppThemeMode _mode = AppThemeMode.dark;
  bool _swipeAnimation = false;

  AppThemeMode get mode => _mode;
  bool get swipeAnimation => _swipeAnimation;

  /// Loads saved theme mode from SharedPreferences
  Future<void> load() async {
    _mode = await loadThemeMode();
    notifyListeners();
  }

  /// Sets theme mode and persists it
  Future<void> setMode(AppThemeMode mode) async {
    _mode = mode;
    await saveThemeMode(mode);
    notifyListeners();
  }

  /// Toggles swipe animation (for welcome card interaction)
  void triggerSwipeAnimation() {
    _swipeAnimation = true;
    notifyListeners();
    Future.delayed(const Duration(milliseconds: 500), () {
      _swipeAnimation = false;
      notifyListeners();
    });
  }
}
