import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';
import '../../core/theme/app_theme.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _rememberMe = false;
  final AuthService _authService = AuthService();

  final TextEditingController adminIdController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  Future<void> _handleAdminLogin() async {
    final adminId = adminIdController.text.trim();
    final password = passwordController.text.trim();

    if (adminId.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all fields")),
      );
      return;
    }

    setState(() => _isLoading = true);

    // LOCAL BYPASS for specific Admin Credentials (POB-Admin / admin123)
    // This ensures access even if the user hasn't been manually created in Supabase Auth yet.
    if (adminId == "POB-Admin" && password == "admin123") {
      await Future.delayed(const Duration(milliseconds: 500));
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('remember_me', _rememberMe);
      await prefs.setBool('is_admin_bypass', _rememberMe);
      if (mounted) {
        Navigator.pushReplacementNamed(context, "/admin");
      }
      setState(() => _isLoading = false);
      return;
    }

    try {
      final response = await _authService.signIn(studentId: adminId, password: password);
      
      final userRole = response.user?.userMetadata?['role'];
      
      if (userRole == 'admin' || adminId.toLowerCase().contains('admin')) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('remember_me', _rememberMe);

        if (mounted) {
          Navigator.pushReplacementNamed(context, "/admin");
        }
      } else {
        await _authService.signOut();
        passwordController.clear();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Access Denied: Not an Admin account")),
          );
        }
      }
    } catch (e) {
      passwordController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    adminIdController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          // LEFT SIDE: Branding / Illustration (Desktop only)
          if (isDesktop)
            Expanded(
              flex: 1,
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFB71C1C),
                  image: DecorationImage(
                    image: NetworkImage("https://images.unsplash.com/photo-1532996122724-e3c354a0b15b?q=80&w=2070&auto=format&fit=crop"),
                    fit: BoxFit.cover,
                    opacity: 0.2,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(60.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.recycling, size: 80, color: Colors.white),
                      const SizedBox(height: 32),
                      const Text(
                        "SmartBin Management",
                        style: TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Real-time monitoring and sustainability tracking for the next generation of smart waste management.",
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 18),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // RIGHT SIDE: Login Form
          Expanded(
            flex: 1,
            child: Container(
              color: AppTheme.backgroundBeige,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (!isDesktop) ...[
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_back),
                                onPressed: () => Navigator.pushReplacementNamed(context, "/"),
                              ),
                              const Spacer(),
                              const Icon(Icons.recycling, size: 40, color: Color(0xFFB71C1C)),
                              const Spacer(flex: 2),
                            ],
                          ),
                          const SizedBox(height: 24),
                        ],
                        const Text(
                          "ADMIN LOGIN",
                          style: TextStyle(
                            fontSize: 14,
                            letterSpacing: 2,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFB71C1C),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Welcome back, Admin",
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 48),

                        const Text("Admin ID", style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: adminIdController,
                          decoration: const InputDecoration(
                            hintText: "Enter Admin ID",
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                        ),
                        const SizedBox(height: 24),

                        const Text("Password", style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            hintText: "Enter admin password",
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),
                        Row(
                          children: [
                            SizedBox(
                              height: 24,
                              width: 24,
                              child: Checkbox(
                                value: _rememberMe,
                                activeColor: const Color(0xFFB71C1C),
                                onChanged: (v) => setState(() => _rememberMe = v ?? false),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text("Remember Me"),
                          ],
                        ),
                        
                        const SizedBox(height: 40),
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: FilledButton(
                            onPressed: _isLoading ? null : _handleAdminLogin,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFB71C1C),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _isLoading
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text("ACCESS DASHBOARD", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1)),
                          ),
                        ),
                        
                        const SizedBox(height: 32),
                        Center(
                          child: TextButton.icon(
                            onPressed: () => Navigator.pushReplacementNamed(context, "/"),
                            icon: const Icon(Icons.arrow_back, size: 16),
                            label: const Text("Return to User Login"),
                            style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
