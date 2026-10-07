import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/theme_provider.dart';

class ThemeToggleIconButton extends StatelessWidget {
  final Color? color;
  final String? tooltip;

  const ThemeToggleIconButton({super.key, this.color, this.tooltip});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return IconButton(
      icon: Icon(
        isDark ? Icons.wb_sunny_outlined : Icons.dark_mode_outlined,
        color: color ?? Theme.of(context).iconTheme.color,
      ),
      tooltip: tooltip ?? (isDark ? "Switch to Light Mode" : "Switch to Dark Mode"),
      onPressed: () => themeProvider.toggleTheme(),
    );
  }
}
