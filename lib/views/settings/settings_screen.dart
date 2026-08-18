import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/providers/language_provider.dart';
import '../../services/auth_service.dart';
import '../../core/theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _supabase = Supabase.instance.client;
  final _authService = AuthService();
  
  final _nameController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isUpdating = false;

  bool _pushNotifications = true;
  bool _rewardAlerts = true;
  bool _badgeNotifications = true;
  bool _biometricLogin = false;
  bool _pinLock = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _loadCurrentData() async {
    final user = _authService.currentUser;
    if (user != null) {
      try {
        final data = await _supabase.from('users').select('full_name').eq('id', user.id).single();
        setState(() {
          _nameController.text = data['full_name'] ?? "";
        });
      } catch (e) {}
    }
  }

  Future<void> _updateName() async {
    if (_nameController.text.trim().isEmpty) return;
    setState(() => _isUpdating = true);
    try {
      final user = _authService.currentUser;
      if (user != null) {
        final newName = _nameController.text.trim();
        await _supabase.from('users').upsert({
          'id': user.id,
          'full_name': newName,
          'student_id': user.userMetadata?['student_id'],
        });
        await _supabase.auth.updateUser(UserAttributes(data: {'full_name': newName}));
        if (mounted) {
          final lp = Provider.of<LanguageProvider>(context, listen: false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lp.translate("update_profile"))));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${e.toString()}")));
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _updatePassword() async {
    if (_newPasswordController.text.isEmpty || _confirmPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill in the new password fields")));
      return;
    }
    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Passwords do not match")));
      return;
    }
    setState(() => _isUpdating = true);
    try {
      await _supabase.auth.updateUser(UserAttributes(password: _newPasswordController.text.trim()));
      if (mounted) {
        final lp = Provider.of<LanguageProvider>(context, listen: false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lp.translate("update_password"))));
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${e.toString()}")));
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  void _showLanguageDialog(LanguageProvider lp) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(lp.translate("language")),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ["English", "Filipino", "Hiligaynon"].map((lang) => RadioListTile<String>(
            title: Text(lang),
            value: lang,
            groupValue: lp.currentLanguage,
            onChanged: (val) {
              lp.setLanguage(val!);
              Navigator.pop(context);
            },
          )).toList(),
        ),
      ),
    );
  }

  void _showCertificationsDialog(LanguageProvider lp) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.verified_outlined, color: AppTheme.primaryGreen),
            const SizedBox(width: 12),
            Text(lp.translate("certifications")),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "SmartBin Excellence 2025",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            _buildCertItem("ISO 14001:2015", "Environmental Management System"),
            _buildCertItem("CE Marking", "Compliance with health, safety, and environmental protection"),
            _buildCertItem("RoHS Certified", "Restriction of Hazardous Substances"),
            _buildCertItem("FCC Compliant", "Electromagnetic interference standards"),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              "Published: September 2025",
              style: TextStyle(color: Colors.grey[600], fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close")),
        ],
      ),
    );
  }

  void _showTermsDialog(LanguageProvider lp) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(lp.translate("terms_conditions")),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text(
                "Welcome to SmartBin 2025. By using this app, you agree to:\n\n"
                "1. User Conduct: You will use the smart bins responsibly and only for intended waste materials.\n\n"
                "2. Points & Rewards: Points are earned based on verified disposal and have no monetary value outside the SmartBin ecosystem.\n\n"
                "3. Account Security: You are responsible for maintaining the confidentiality of your login credentials.\n\n"
                "4. Service Changes: SmartBin reserves the right to modify or discontinue features to improve campus sustainability.",
              ),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))],
      ),
    );
  }

  void _showPrivacyDialog(LanguageProvider lp) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(lp.translate("privacy_policy")),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text(
                "Your privacy is important to us. SmartBin 2025 collects:\n\n"
                "- Profile Info: Name and Student ID to manage your rewards.\n\n"
                "- Usage Data: Records of your recycling activity to track campus impact.\n\n"
                "- Location Data: Only used to identify which bin you are interacting with.\n\n"
                "We do not sell your data. Information is shared only with campus administration for sustainability reporting.",
              ),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))],
      ),
    );
  }

  void _showFAQDialog(LanguageProvider lp) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(lp.translate("faq")),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildFAQItem("How do I earn points?", "Generate a QR code in the app, scan it at a SmartBin, and dispose of your items."),
              _buildFAQItem("What can I recycle?", "The bins accept plastic bottles, paper, and metal cans. Check the 'History' tab for details."),
              _buildFAQItem("Where can I use my rewards?", "Redeem your points in the 'Rewards' tab for campus-affiliated perks."),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))],
      ),
    );
  }

  Widget _buildFAQItem(String q, String a) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(q, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(a, style: const TextStyle(fontSize: 13, color: Colors.black87)),
        ],
      ),
    );
  }

  void _showContactSupportDialog(LanguageProvider lp) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(lp.translate("contact_support")),
        content: const Text("For technical assistance, please email:\n\nsupport@smartbin-campus.edu\n\nResponse time: 24-48 hours."),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))],
      ),
    );
  }

  void _showReportProblemDialog(LanguageProvider lp) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Report a Problem"),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(hintText: "Describe the issue..."),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Thank you. Report submitted.")));
            },
            child: const Text("Submit"),
          ),
        ],
      ),
    );
  }

  void _showActiveSessionsDialog(LanguageProvider lp) {
    final session = _supabase.auth.currentSession;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(lp.translate("active_sessions")),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Current Session:", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text("Device: Web/Mobile App"),
            Text("Last Login: ${session?.user.lastSignInAt ?? "Unknown"}"),
            const SizedBox(height: 16),
            const Text("Note: Logging out will terminate this session.", style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))],
      ),
    );
  }

  void _showFontSizeDialog(LanguageProvider lp, ThemeProvider tp) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(lp.translate("text_size")),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildFontOption("Small", 0.8, tp),
            _buildFontOption("Normal", 1.0, tp),
            _buildFontOption("Large", 1.2, tp),
            _buildFontOption("Extra Large", 1.4, tp),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))],
      ),
    );
  }

  void _showVersionDialog(LanguageProvider lp) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(lp.translate("app_version")),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.recycling, size: 64, color: AppTheme.primaryGreen),
            const SizedBox(height: 16),
            const Text("SmartBin", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            const Text("Sustainability Tracker"),
            const SizedBox(height: 24),
            _buildVersionInfo("Version", "1.0.0"),
            _buildVersionInfo("Build", "2025.08.18"),
            _buildVersionInfo("Channel", "Stable"),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            const Text(
              "© 2025 SmartBin Project. All rights reserved.",
              style: TextStyle(fontSize: 10, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))],
      ),
    );
  }

  Widget _buildVersionInfo(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildFontOption(String label, double factor, ThemeProvider tp) {
    return RadioListTile<double>(
      title: Text(label),
      value: factor,
      groupValue: tp.fontSizeFactor,
      onChanged: (val) => tp.setFontSizeFactor(val!),
    );
  }

  Widget _buildCertItem(String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          Text(desc, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    languageProvider.translate("settings_title"),
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              _buildSectionHeader(languageProvider.translate("edit_profile")),
              _buildInputCard(languageProvider.translate("full_name"), _nameController, languageProvider.translate("full_name")),
              const SizedBox(height: 12),
              _buildReadOnlyCard(languageProvider.translate("email"), _authService.currentUser?.email ?? "No Email"),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isUpdating ? null : _updateName,
                  child: _isUpdating ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(languageProvider.translate("update_profile")),
                ),
              ),

              const SizedBox(height: 40),
              _buildSectionHeader(languageProvider.translate("change_password")),
              _buildPasswordInput(languageProvider.translate("new_password"), _newPasswordController),
              const SizedBox(height: 12),
              _buildPasswordInput(languageProvider.translate("confirm_password"), _confirmPasswordController),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _isUpdating ? null : _updatePassword,
                  child: Text(languageProvider.translate("update_password")),
                ),
              ),

              const SizedBox(height: 40),
              
              // --- NOTIFICATIONS ---
              _buildSettingsGroup(Icons.notifications_outlined, languageProvider.translate("notifications"), [
                _buildSwitchItem(languageProvider.translate("push_notifications"), _pushNotifications, (v) => setState(() => _pushNotifications = v)),
                _buildSwitchItem(languageProvider.translate("reward_alerts"), _rewardAlerts, (v) => setState(() => _rewardAlerts = v)),
                _buildSwitchItem(languageProvider.translate("badge_notifications"), _badgeNotifications, (v) => setState(() => _badgeNotifications = v)),
              ]),

              // --- SECURITY ---
              _buildSettingsGroup(Icons.security_outlined, languageProvider.translate("security"), [
                _buildSwitchItem(languageProvider.translate("biometric_login"), _biometricLogin, (v) => setState(() => _biometricLogin = v)),
                _buildSwitchItem(languageProvider.translate("pin_lock"), _pinLock, (v) => setState(() => _pinLock = v)),
                _buildSubItem(languageProvider.translate("active_sessions"), () => _showActiveSessionsDialog(languageProvider)),
              ]),

              // --- APPEARANCE ---
              _buildSettingsGroup(Icons.palette_outlined, languageProvider.translate("appearance"), [
                _buildSwitchItem(languageProvider.translate("dark_mode"), themeProvider.isDarkMode, (v) => themeProvider.toggleTheme()),
                _buildSubItem(languageProvider.translate("text_size"), () => _showFontSizeDialog(languageProvider, themeProvider)),
              ]),

              // --- LANGUAGE ---
              _buildSettingsGroup(Icons.language_outlined, languageProvider.translate("language"), [
                _buildSubItem("${languageProvider.translate("language")}: ${languageProvider.currentLanguage}", () => _showLanguageDialog(languageProvider)),
              ]),

              // --- REWARDS ---
              _buildSettingsGroup(Icons.card_giftcard_outlined, languageProvider.translate("rewards"), [
                _buildSubItem(languageProvider.translate("my_points"), () => Navigator.pushNamed(context, "/rewards")),
                _buildSubItem(languageProvider.translate("redemption_history"), () {}),
                _buildSubItem(languageProvider.translate("badge_progress"), () => Navigator.pushNamed(context, "/badges")),
              ]),

              // --- ACCESSIBILITY ---
              _buildSettingsGroup(Icons.accessibility_new_outlined, languageProvider.translate("accessibility"), [
                _buildSwitchItem(languageProvider.translate("high_contrast"), themeProvider.highContrast, (v) => themeProvider.toggleHighContrast()),
                _buildSwitchItem(languageProvider.translate("reduce_motion"), themeProvider.reduceMotion, (v) => themeProvider.toggleReduceMotion()),
              ]),

              // --- HELP & SUPPORT ---
              _buildSettingsGroup(Icons.help_outline, languageProvider.translate("help_support"), [
                _buildSubItem(languageProvider.translate("faq"), () => _showFAQDialog(languageProvider)),
                _buildSubItem(languageProvider.translate("contact_support"), () => _showContactSupportDialog(languageProvider)),
                _buildSubItem(languageProvider.translate("report_problem"), () => _showReportProblemDialog(languageProvider)),
              ]),

              // --- ABOUT ---
              _buildSettingsGroup(Icons.info_outline, languageProvider.translate("about"), [
                _buildSubItem(languageProvider.translate("app_version"), () => _showVersionDialog(languageProvider)),
                _buildSubItem(languageProvider.translate("certifications"), () => _showCertificationsDialog(languageProvider)),
                _buildSubItem(languageProvider.translate("terms_conditions"), () => _showTermsDialog(languageProvider)),
                _buildSubItem(languageProvider.translate("privacy_policy"), () => _showPrivacyDialog(languageProvider)),
              ]),

              const SizedBox(height: 40),
              Center(
                child: TextButton(
                  onPressed: () {},
                  child: Text(languageProvider.translate("delete_account"), style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
    );
  }

  Widget _buildInputCard(String label, TextEditingController controller, String hint) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
          TextField(controller: controller, decoration: InputDecoration(hintText: hint, border: InputBorder.none, isDense: true)),
        ],
      ),
    );
  }

  Widget _buildReadOnlyCard(String label, String value) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      width: double.infinity,
      decoration: BoxDecoration(color: theme.colorScheme.surface.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(20), border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _buildPasswordInput(String label, TextEditingController controller) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
          TextField(controller: controller, obscureText: true, decoration: const InputDecoration(hintText: "••••••••", border: InputBorder.none, isDense: true)),
        ],
      ),
    );
  }

  Widget _buildSettingsGroup(IconData icon, String title, List<Widget> children) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1))),
      child: ExpansionTile(
        leading: Icon(icon, color: theme.colorScheme.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        shape: const Border(),
        children: children,
      ),
    );
  }

  Widget _buildSwitchItem(String title, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(fontSize: 14)),
      value: value,
      activeThumbColor: AppTheme.primaryGreen,
      onChanged: onChanged,
    );
  }

  Widget _buildSubItem(String title, VoidCallback onTap) {
    return ListTile(
      title: Text(title, style: const TextStyle(fontSize: 14)),
      trailing: const Icon(Icons.chevron_right, size: 18),
      onTap: onTap,
    );
  }
}
