import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';
import '../../core/theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _rememberMe = false;
  final AuthService _authService = AuthService();

  final TextEditingController studentIdController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  Future<void> _handleLogin() async {
    final studentId = studentIdController.text.trim();
    final password = passwordController.text.trim();

    if (studentId.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all fields")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _authService.signIn(studentId: studentId, password: password);
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('remember_me', _rememberMe);
      await prefs.remove('is_admin_bypass'); // Clear admin bypass if student logs in

      if (mounted) {
        Navigator.pushReplacementNamed(context, "/home");
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
    studentIdController.dispose();
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
                  color: AppTheme.primaryGreen,
                  image: DecorationImage(
                    image: NetworkImage("https://images.unsplash.com/photo-1542601906990-b4d3fb778b09?q=80&w=2013&auto=format&fit=crop"),
                    fit: BoxFit.cover,
                    opacity: 0.3,
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
                        "Join the Green Revolution",
                        style: TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Recycle smart, earn points, and make a real impact on our environment with SmartBin.",
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
                        if (!isDesktop)
                          Center(
                            child: GestureDetector(
                              onLongPress: () => Navigator.pushNamed(context, "/admin-login"),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.secondarySage.withValues(alpha: 0.5),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.recycling,
                                  size: 32,
                                  color: AppTheme.primaryGreen,
                                ),
                              ),
                            ),
                          )
                        else
                          // Secret long press area for desktop on a small invisible widget or the icon
                          GestureDetector(
                            onLongPress: () => Navigator.pushNamed(context, "/admin-login"),
                            child: const Icon(Icons.recycling, size: 40, color: AppTheme.primaryGreen),
                          ),
                        const SizedBox(height: 24),
                        const Text(
                          "USER LOGIN",
                          style: TextStyle(
                            fontSize: 14,
                            letterSpacing: 2,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Welcome back",
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                        const SizedBox(height: 48),

                        const Text("Student ID", style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: studentIdController,
                          decoration: const InputDecoration(
                            hintText: "Enter your Student ID",
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
                            hintText: "Enter your password",
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
                                onChanged: (v) => setState(() => _rememberMe = v ?? false),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text("Remember Me"),
                            const Spacer(),
                            TextButton(
                              onPressed: () {},
                              child: const Text("Forgot password?"),
                            ),
                          ],
                        ),

                        const SizedBox(height: 40),
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: FilledButton(
                            onPressed: _isLoading ? null : _handleLogin,
                            style: FilledButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _isLoading
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text("SIGN IN", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1)),
                          ),
                        ),
                        
                        const SizedBox(height: 40),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text("Don't have an account? "),
                            GestureDetector(
                              onTap: () => Navigator.pushNamed(context, "/signup"),
                              child: const Text(
                                "Create Account",
                                style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
                              ),
                            ),
                          ],
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
