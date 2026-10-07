import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryGreen = Color(0xFF3B5B3E);
  static const Color backgroundBeige = Color(0xFFF5F2E8);
  static const Color secondarySage = Color(0xFFD2D8B3);
  static const Color cardColor = Colors.white;

  static ThemeData getLightTheme({bool highContrast = false, bool reduceMotion = false}) {
    final base = ThemeData.light();
    return _buildTheme(base, highContrast, reduceMotion, Brightness.light);
  }

  static ThemeData getDarkTheme({bool highContrast = false, bool reduceMotion = false}) {
    final base = ThemeData.dark();
    return _buildTheme(base, highContrast, reduceMotion, Brightness.dark);
  }

  static ThemeData _buildTheme(ThemeData base, bool highContrast, bool reduceMotion, Brightness brightness) {
    final bool isLight = brightness == Brightness.light;
    final Color primary = highContrast
        ? (isLight ? Colors.black : Colors.white)
        : (isLight ? primaryGreen : const Color(0xFF4CAF50));
    
    final Color backgroundSurface = highContrast
        ? (isLight ? Colors.white : Colors.black)
        : (isLight ? backgroundBeige : const Color(0xFF121212));
        
    final Color cardSurface = highContrast
        ? (isLight ? Colors.white : const Color(0xFF1A1A1A))
        : (isLight ? Colors.white : const Color(0xFF1E1E1E));

    final Color textColor = highContrast
        ? (isLight ? Colors.black : Colors.white)
        : (isLight ? Colors.black87 : Colors.white70);

    return base.copyWith(
      scaffoldBackgroundColor: backgroundSurface,
      cardColor: cardSurface,
      colorScheme: isLight
          ? ColorScheme.light(
              primary: primary,
              onPrimary: Colors.white,
              secondary: secondarySage,
              onSecondary: primary,
              surface: backgroundSurface,
              onSurface: textColor,
              surfaceContainerHighest: cardSurface,
            )
          : ColorScheme.dark(
              primary: primary,
              onPrimary: Colors.black,
              secondary: const Color(0xFF2C3E2E),
              onSecondary: Colors.white,
              surface: backgroundSurface,
              onSurface: textColor,
              surfaceContainerHighest: cardSurface,
            ),
      cardTheme: CardThemeData(
        color: cardSurface,
        elevation: highContrast ? 4 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: highContrast ? BorderSide(color: textColor, width: 2) : BorderSide.none,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cardSurface,
        surfaceTintColor: Colors.transparent,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: highContrast ? (isLight ? Colors.black : const Color(0xFF1A1A1A)) : (isLight ? primaryGreen : const Color(0xFF1E1E1E)),
        foregroundColor: Colors.white,
        elevation: highContrast ? 4 : 0,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: cardSurface,
        selectedItemColor: primary,
        unselectedItemColor: isLight ? Colors.grey[700] : Colors.white54,
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: cardSurface,
      ),
      iconTheme: IconThemeData(
        color: textColor,
        size: 24,
      ),
      dividerTheme: DividerThemeData(
        color: highContrast ? textColor : (isLight ? Colors.black26 : Colors.white24),
        thickness: highContrast ? 2 : 1,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: textColor,
        displayColor: textColor,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: highContrast 
            ? (isLight ? Colors.white : const Color(0xFF2A2A2A)) 
            : (isLight ? Colors.grey[200] : const Color(0xFF2A2A2A)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: highContrast ? BorderSide(color: textColor, width: 2) : BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: highContrast ? BorderSide(color: textColor, width: 1.5) : BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        labelStyle: TextStyle(
          color: textColor,
          fontWeight: highContrast ? FontWeight.bold : FontWeight.normal,
        ),
        hintStyle: TextStyle(
          color: isLight ? Colors.black54 : Colors.white54,
        ),
        prefixIconColor: textColor,
        suffixIconColor: textColor,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: isLight ? Colors.white : Colors.black,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: highContrast ? BorderSide(color: textColor, width: 2) : BorderSide.none,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: isLight ? Colors.white : Colors.black,
          minimumSize: const Size(double.infinity, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: highContrast ? BorderSide(color: textColor, width: 2) : BorderSide.none,
          ),
          textStyle: TextStyle(
            fontSize: 16,
            fontWeight: highContrast ? FontWeight.w900 : FontWeight.bold,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textColor,
          side: BorderSide(color: primary, width: highContrast ? 2.5 : 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: TextStyle(fontWeight: highContrast ? FontWeight.bold : FontWeight.normal),
        ),
      ),
    );
  }

  static final lightTheme = getLightTheme();
  static final darkTheme = getDarkTheme();
}
