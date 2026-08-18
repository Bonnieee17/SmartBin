import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryGreen = Color(0xFF3B5B3E);
  static const Color backgroundBeige = Color(0xFFF5F2E8);
  static const Color secondarySage = Color(0xFFD2D8B3);
  static const Color cardColor = Colors.white;

  static ThemeData getLightTheme({bool highContrast = false}) {
    final base = ThemeData.light();
    return _buildTheme(base, highContrast, Brightness.light);
  }

  static ThemeData getDarkTheme({bool highContrast = false}) {
    final base = ThemeData.dark();
    return _buildTheme(base, highContrast, Brightness.dark);
  }

  static ThemeData _buildTheme(ThemeData base, bool highContrast, Brightness brightness) {
    final Color primary = highContrast ? (brightness == Brightness.light ? Colors.black : Colors.white) : primaryGreen;
    final Color surface = brightness == Brightness.light ? backgroundBeige : Colors.grey[900]!;

    return base.copyWith(
      useMaterial3: true,
      scaffoldBackgroundColor: surface,
      colorScheme: brightness == Brightness.light
          ? ColorScheme.light(
              primary: primary,
              onPrimary: Colors.white,
              secondary: secondarySage,
              onSecondary: primary,
              surface: cardColor,
              onSurface: Colors.black,
            )
          : ColorScheme.dark(
              primary: primary,
              onPrimary: Colors.black,
              secondary: secondarySage,
              onSecondary: primary,
              surface: Colors.black,
              onSurface: Colors.white,
            ),
      textTheme: base.textTheme.apply(
        bodyColor: brightness == Brightness.light ? Colors.black87 : Colors.white70,
        displayColor: brightness == Brightness.light ? Colors.black : Colors.white,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: brightness == Brightness.light ? Colors.white : Colors.black,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  // Keeping the static themes for initial loading if needed, but they will be overridden by the provider
  static final lightTheme = getLightTheme();
  static final darkTheme = getDarkTheme();
}
