import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/providers/language_provider.dart';
import 'core/constants/supabase_constants.dart';

import 'config/app_routes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConstants.url,
    publishableKey: SupabaseConstants.anonKey,
  );

  // Check if session exists and Remember Me is active to handle auto-login
  final session = Supabase.instance.client.auth.currentSession;
  final prefs = await SharedPreferences.getInstance();
  final rememberMe = prefs.getBool('remember_me') ?? false;
  final isAdminBypass = prefs.getBool('is_admin_bypass') ?? false;

  String initialRoute = AppRoutes.login;
  
  if (isAdminBypass && rememberMe) {
    initialRoute = AppRoutes.admin;
  } else if (session != null) {
    if (rememberMe) {
      final userRole = session.user.userMetadata?['role'];
      if (userRole == 'admin') {
        initialRoute = AppRoutes.admin;
      } else {
        initialRoute = AppRoutes.home;
      }
    } else {
      // If there is a session but user didn't want to be remembered, sign them out
      await Supabase.instance.client.auth.signOut();
    }
  }

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
            ),
            darkTheme: AppTheme.getDarkTheme(
              highContrast: themeProvider.highContrast,
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
