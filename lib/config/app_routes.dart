import 'package:flutter/material.dart';

import '../views/auth/login_screen.dart';
import '../views/auth/admin_login_screen.dart';
import '../views/auth/signup_screen.dart';
import '../views/home/homescreen.dart';
import '../views/scanner/scanner_screen.dart';
import '../views/rewards/reward_screen.dart';
import '../views/history/history_screen.dart';
import '../views/profile/profile_screen.dart';
import '../views/admin/admin_dashboard.dart';
import '../views/admin/bin_lcd_screen.dart';
import '../views/badges/badges_screen.dart';
import '../views/settings/settings_screen.dart';
import '../views/home/notifications_screen.dart';
import '../views/settings/share_app_screen.dart';

class AppRoutes {
  static const login = "/";
  static const adminLogin = "/admin-login";
  static const signup = "/signup";
  static const home = "/home";
  static const scanner = "/scanner";
  static const rewards = "/rewards";
  static const history = "/history";
  static const profile = "/profile";
  static const admin = "/admin";
  static const badges = "/badges";
  static const settings = "/settings";
  static const notifications = "/notifications";
  static const shareApp = "/share-app";
  static const binSimulator = "/bin-simulator";

  static Map<String, WidgetBuilder> routes = {
    login: (_) => const LoginScreen(),
    adminLogin: (_) => const AdminLoginScreen(),
    signup: (_) => const SignupScreen(),
    home: (_) => const HomeScreen(),
    scanner: (_) => const ScannerScreen(),
    rewards: (_) => const RewardsScreen(),
    history: (_) => const HistoryScreen(),
    profile: (_) => const ProfileScreen(),
    admin: (_) => const AdminDashboard(),
    badges: (_) => const BadgesScreen(),
    settings: (_) => const SettingsScreen(),
    notifications: (_) => const NotificationsScreen(),
    shareApp: (_) => const ShareAppScreen(),
    binSimulator: (_) => const BinLcdScreen(),
  };
}
