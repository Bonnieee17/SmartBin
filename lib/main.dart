import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/providers/language_provider.dart';
import 'core/constants/supabase_constants.dart';
import 'services/deep_link_service.dart';

import 'config/app_routes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase in background (non-blocking) for instant app startup
  Supabase.initialize(
    url: SupabaseConstants.url,
    publishableKey: SupabaseConstants.anonKey,
  );

  final prefs = await SharedPreferences.getInstance();
  final rememberMe = prefs.getBool('remember_me') ?? false;
  final isAdminBypass = prefs.getBool('is_admin_bypass') ?? false;

  String initialRoute = AppRoutes.login;

  if (isAdminBypass && rememberMe) {
    initialRoute = AppRoutes.admin;
  }

  DeepLinkService.init();

  runApp(MyApp(initialRoute: initialRoute));
}

class MyApp extends StatelessWidget {
  final String initialRoute;
  const MyApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
      ],
      child: Consumer2<ThemeProvider, LanguageProvider>(
        builder: (context, themeProvider, languageProvider, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'SmartBin',

            theme: AppTheme.getLightTheme(
              highContrast: themeProvider.highContrast,
              reduceMotion: themeProvider.reduceMotion,
            ),

            darkTheme: AppTheme.getDarkTheme(
              highContrast: themeProvider.highContrast,
              reduceMotion: themeProvider.reduceMotion,
            ),

            themeMode: themeProvider.themeMode,

            builder: (context, child) {
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(themeProvider.fontSizeFactor),
                ),
                child: child!,
              );
            },

            initialRoute: initialRoute,
            routes: AppRoutes.routes,
          );
        },
      ),
    );
  }
}
