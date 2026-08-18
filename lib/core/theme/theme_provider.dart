import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = false;
  double _fontSizeFactor = 1.0;
  bool _highContrast = false;
  bool _reduceMotion = false;

  bool get isDarkMode => _isDarkMode;
  double get fontSizeFactor => _fontSizeFactor;
  bool get highContrast => _highContrast;
  bool get reduceMotion => _reduceMotion;

  ThemeProvider() {
    _loadSettings();
  }

  ThemeMode get themeMode =>
      _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  void toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
    _saveSettings();
  }

  void setThemeMode(ThemeMode mode) async {
    _isDarkMode = mode == ThemeMode.dark;
    notifyListeners();
    _saveSettings();
  }

  void setFontSizeFactor(double factor) {
    _fontSizeFactor = factor;
    notifyListeners();
    _saveSettings();
  }

  void toggleHighContrast() {
    _highContrast = !_highContrast;
    notifyListeners();
    _saveSettings();
  }

  void toggleReduceMotion() {
    _reduceMotion = !_reduceMotion;
    notifyListeners();
    _saveSettings();
  }

  void _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('darkMode', _isDarkMode);
    prefs.setDouble('fontSizeFactor', _fontSizeFactor);
    prefs.setBool('highContrast', _highContrast);
    prefs.setBool('reduceMotion', _reduceMotion);
  }

  void _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('darkMode') ?? false;
    _fontSizeFactor = prefs.getDouble('fontSizeFactor') ?? 1.0;
    _highContrast = prefs.getBool('highContrast') ?? false;
    _reduceMotion = prefs.getBool('reduceMotion') ?? false;
    notifyListeners();
  }
}