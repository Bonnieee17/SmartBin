import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';
import '../../core/theme/app_theme.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  final AuthService _authService = AuthService();

  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController studentIdController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  String _passwordStrength = '';
  Color _strengthColor = Colors.grey;
  double _strengthProgress = 0.0;

  void _checkPasswordStrength(String password) {
    if (password.isEmpty) {
      setState(() {
        _passwordStrength = '';
        _strengthColor = Colors.grey;
        _strengthProgress = 0.0;
      });
      return;
    }

    bool hasUppercase = password.contains(RegExp(r'[A-Z]'));
    bool hasLowercase = password.contains(RegExp(r'[a-z]'));
    bool hasDigits = password.contains(RegExp(r'\d'));
    bool hasSpecialCharacters = password.contains(RegExp(r'[@$!%*?&#^()\-_=+\[\]{};:,.<>/?]'));

    int score = 0;
    if (password.length >= 6) score++;
    if (password.length >= 8) score++;
    if (hasUppercase && hasLowercase) score++;
    if (hasDigits) score++;
    if (hasSpecialCharacters) score++;

    if (password.length < 6 || score <= 2) {
      setState(() {
        _passwordStrength = 'Easy';
        _strengthColor = Colors.redAccent;
        _strengthProgress = 0.33;
      });
    } else if (score == 3 || score == 4) {
      setState(() {
        _passwordStrength = 'Medium';
        _strengthColor = Colors.orangeAccent;
        _strengthProgress = 0.66;
      });
    } else {
      setState(() {
        _passwordStrength = 'Strong';
        _strengthColor = AppTheme.primaryGreen;
        _strengthProgress = 1.0;
      });
    }
  }

  Future<void> _handleSignup() async {
    final studentId = studentIdController.text.trim();
    final password = passwordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    if (studentId.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all fields")),
      );
      return;
    }

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Passwords do not match")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _authService.signUp(
        studentId: studentId,
        password: password,
        metadata: {
          'full_name': fullNameController.text.trim(),
          'student_id': studentId,
          'role': 'user',
        },
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('logged_student_id', studentId);
      if (fullNameController.text.trim().isNotEmpty) {
        await prefs.setString('student_name_$studentId', fullNameController.text.trim());
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Account created successfully! Welcome to SmartBin."),
            backgroundColor: AppTheme.primaryGreen,
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.pop(context); // Return to login page
      }
    } catch (e) {
      final cleanMsg = e.toString().replaceAll("Exception: ", "");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(cleanMsg),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    fullNameController.dispose();
    studentIdController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
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
              child: Stack(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryGreen,
                      image: DecorationImage(
                        image: NetworkImage("https://images.unsplash.com/photo-1542601098-38add12601d9?q=80&w=2070&auto=format&fit=crop"),
                        fit: BoxFit.cover,
                        opacity: 0.3,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(60.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.recycling, size: 80, color: Colors.white),
                        const SizedBox(height: 32),
                        const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            "Be part of the change",
                            style: TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Create your account and start your journey towards a cleaner campus. Earn points for every item you recycle.",
                          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 18),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // RIGHT SIDE: Signup Form
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
                          Row(
                            children: [
                              IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
                              const Spacer(),
                              const Icon(Icons.recycling, size: 40, color: AppTheme.primaryGreen),
                              const Spacer(flex: 2),
                            ],
                          ),
                        const SizedBox(height: 24),
                        Text(
                          "Create Account",
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Register with your Student ID to start earning rewards.",
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 32),

                        // FULL NAME
                        TextField(
                          controller: fullNameController,
                          textInputAction: TextInputAction.next,
                          onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                          decoration: InputDecoration(
                            labelText: "Full Name",
                            prefixIcon: const Icon(Icons.person_outline),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // STUDENT ID
                        TextField(
                          controller: studentIdController,
                          textInputAction: TextInputAction.next,
                          onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                          decoration: InputDecoration(
                            labelText: "Student ID",
                            prefixIcon: const Icon(Icons.badge_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // PASSWORD
                        TextField(
                          controller: passwordController,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.next,
                          onChanged: _checkPasswordStrength,
                          onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                          decoration: InputDecoration(
                            labelText: "Password",
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                              ),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                        if (_passwordStrength.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: _strengthProgress,
                                    backgroundColor: Colors.grey.shade300,
                                    color: _strengthColor,
                                    minHeight: 6,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                "Strength: $_passwordStrength",
                                style: TextStyle(
                                  color: _strengthColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Use letters, numbers, and special characters (!@#\$%^&*) for a strong password.",
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                          ),
                        ],
                        const SizedBox(height: 16),

                        // CONFIRM PASSWORD
                        TextField(
                          controller: confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          textInputAction: TextInputAction.go,
                          onSubmitted: (_) => _handleSignup(),
                          decoration: InputDecoration(
                            labelText: "Confirm Password",
                            prefixIcon: const Icon(Icons.lock_reset),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                              ),
                              onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // REGISTER BUTTON
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: FilledButton(
                            onPressed: _isLoading ? null : _handleSignup,
                            style: FilledButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text("REGISTER", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                          ),
                        ),
                        const SizedBox(height: 24),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text("Already have an account? "),
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text("Sign In", style: TextStyle(fontWeight: FontWeight.bold)),
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
