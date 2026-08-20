import 'dart:async';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/language_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _supabase = Supabase.instance.client;
  final _authService = AuthService();
  
  Stream<List<Map<String, dynamic>>>? _userStream;
  Stream<List<Map<String, dynamic>>>? _historyStream;
  Stream<List<Map<String, dynamic>>>? _allUsersStream;
  late final StreamSubscription<AuthState> _authSubscription;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _setupStreams();
    _authSubscription = _supabase.auth.onAuthStateChange.listen((data) {
      if (mounted) setState(() {});
    });
  }

  void _setupStreams() {
    final user = _authService.currentUser;
    if (user != null) {
      _userStream = _supabase
          .from('users')
          .stream(primaryKey: ['id'])
          .eq('id', user.id);
      
      _historyStream = _supabase
          .from('disposal_history')
          .stream(primaryKey: ['id'])
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      _allUsersStream = _supabase
          .from('users')
          .stream(primaryKey: ['id'])
          .order('total_points', ascending: false);
    }
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Update Profile Photo"),
            content: const Text("Do you want to save this as your new profile photo?"),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  final bytes = await image.readAsBytes();
                  _uploadImage(bytes, image.name);
                },
                child: const Text("Save"),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _uploadImage(Uint8List bytes, String fileName) async {
    setState(() => _isUpdating = true);
    try {
      final user = _authService.currentUser;
      if (user == null) return;
      
      final storagePath = 'avatars/${user.id}_$fileName';
      
      await _supabase.storage.from('avatars').uploadBinary(
        storagePath,
        bytes,
        fileOptions: const FileOptions(upsert: true),
      );
      
      final String publicUrl = _supabase.storage.from('avatars').getPublicUrl(storagePath);
      
      // Update Auth Metadata (Safe fallback)
      await _supabase.auth.updateUser(UserAttributes(data: {'avatar_url': publicUrl}));

      // Try to update public users table, but don't crash if column is missing
      try {
        await _supabase.from('users').upsert({
          'id': user.id, 
          'avatar_url': publicUrl,
        });
      } catch (e) {
        debugPrint("Note: avatar_url column might be missing in 'users' table. Using metadata instead.");
      }
      
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile photo updated!")));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Upload Error: ${e.toString()}")));
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _handleLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('remember_me');
    await prefs.remove('is_admin_bypass');
    await _authService.signOut();
    if (mounted) Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  String _getLevelName(int points, LanguageProvider lp) {
    if (points < 100) return lp.translate("eco_beginner");
    if (points < 250) return lp.translate("eco_recycler");
    if (points < 500) return lp.translate("eco_warrior");
    if (points < 750) return lp.translate("green_guardian");
    if (points < 1000) return lp.translate("recycling_champion");
    return lp.translate("sustainability_hero");
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _userStream,
        builder: (context, userSnapshot) {
          if (userSnapshot.hasError) {
            return _buildErrorState(theme, "Profile Connection Error");
          }
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final userData = userSnapshot.hasData && userSnapshot.data!.isNotEmpty ? userSnapshot.data!.first : null;
          
          final authUser = _supabase.auth.currentUser;
          final fullName = authUser?.userMetadata?['full_name'] ?? userData?['full_name'] ?? "User";
          final studentId = authUser?.userMetadata?['student_id'] ?? userData?['student_id'] ?? "No ID";
          final dept = userData?['department'] ?? "CICT";
          final points = userData?['total_points'] ?? 0;
          final avatarUrl = authUser?.userMetadata?['avatar_url'] ?? userData?['avatar_url'];

          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: _historyStream,
            builder: (context, historySnapshot) {
              final history = historySnapshot.data ?? [];
              final totalRecycled = history.length;
              
              int recyclable = 0, nonBio = 0;
              for (var item in history) {
                final type = (item['waste_type'] ?? "").toString().toLowerCase();
                if (type.contains('bottle') || type.contains('paper') || type.contains('metal') || type.contains('can') || type.contains('glass')) {
                  recyclable++;
                } else {
                  nonBio++;
                }
              }

              return StreamBuilder<List<Map<String, dynamic>>>(
                stream: _allUsersStream,
                builder: (context, allUsersSnapshot) {
                  int rank = 1;
                  if (allUsersSnapshot.hasData) {
                    final users = allUsersSnapshot.data!;
                    for (int i = 0; i < users.length; i++) {
                      if (users[i]['id'] == _authService.currentUser?.id) { rank = i + 1; break; }
                    }
                  }

                  return _buildMainProfileUI(theme, languageProvider, fullName, studentId, dept, points, avatarUrl, totalRecycled, recyclable, nonBio, rank, history);
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text("Please check your internet connection."),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: () => setState(() {}), child: const Text("Retry")),
        ],
      ),
    );
  }

  Widget _buildMainProfileUI(
    ThemeData theme, 
    LanguageProvider languageProvider, 
    String fullName, 
    String studentId, 
    String dept, 
    int points, 
    String? avatarUrl, 
    int totalRecycled, 
    int recyclable, 
    int nonBio, 
    int rank, 
    List<Map<String, dynamic>> history
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 20 : 32),
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
                Expanded(
                  child: Text(
                    "My Profile",
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: isMobile ? 20 : 24,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: isMobile ? 24 : 32),
            // 1. HEADER
            _buildProfileHeader(theme, fullName, studentId, dept, avatarUrl, isMobile),
            Divider(height: isMobile ? 40 : 64),

            // 2. REWARD SUMMARY
            _buildSectionTitle(theme, "⭐ Reward Summary"),
            _buildRewardCard(theme, points, rank, languageProvider, isMobile),
            Divider(height: isMobile ? 40 : 64),

            // 3. RECYCLING STATISTICS
            _buildSectionTitle(theme, "♻ Recycling Statistics"),
            _buildStatsCard(theme, totalRecycled, recyclable, nonBio, languageProvider),
            Divider(height: isMobile ? 40 : 64),

            // 4. ACHIEVEMENT BADGES
            _buildSectionTitle(theme, "🏅 Achievement Badges"),
            _buildBadgesList(theme, points, languageProvider),
            Divider(height: isMobile ? 40 : 64),

            // 5. RECENT ACTIVITY
            _buildSectionTitle(theme, "🕒 Recent Activity"),
            _buildActivityList(theme, history.take(3).toList()),
            Divider(height: isMobile ? 40 : 64),

            // 6. QUICK ACTIONS
            _buildSectionTitle(theme, "⚡ Quick Actions"),
            _buildQuickActions(theme, languageProvider, screenWidth),
            Divider(height: isMobile ? 40 : 64),

            // 7. LOGOUT
            _buildLogoutButton(theme),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }


  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
    );
  }

  Widget _buildProfileHeader(ThemeData theme, String name, String id, String dept, String? avatar, bool isMobile) {
    return Row(
      children: [
        GestureDetector(
          onTap: _isUpdating ? null : _pickImage,
          child: Stack(
            children: [
              CircleAvatar(
                radius: isMobile ? 36 : 48,
                backgroundColor: theme.colorScheme.secondary.withValues(alpha: 0.5),
                backgroundImage: avatar != null ? NetworkImage(avatar) : null,
                child: avatar == null ? Icon(Icons.person, size: isMobile ? 36 : 48, color: theme.colorScheme.primary) : null,
              ),
              Positioned(
                bottom: 0, 
                right: 0, 
                child: Container(
                  padding: const EdgeInsets.all(4), 
                  decoration: BoxDecoration(color: theme.colorScheme.surface, shape: BoxShape.circle, border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1))), 
                  child: Icon(Icons.camera_alt, size: isMobile ? 14 : 18, color: theme.colorScheme.primary)
                )
              ),
              if (_isUpdating) const Positioned.fill(child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
            ],
          ),
        ),
        SizedBox(width: isMobile ? 16 : 24),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name, 
                style: (isMobile ? theme.textTheme.titleMedium : theme.textTheme.titleLarge)?.copyWith(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                "Student ID: $id", 
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.textTheme.bodySmall?.color, fontSize: isMobile ? 12 : 14),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                "Department: $dept", 
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.textTheme.bodySmall?.color, fontSize: isMobile ? 12 : 14),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRewardCard(ThemeData theme, int points, int rank, LanguageProvider lp, bool isMobile) {
    double progress = (points % 1000) / 1000;
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: _buildSimpleStat(theme, "🏆 ${lp.translate("points")}", points.toString(), isMobile)),
              Expanded(child: _buildSimpleStat(theme, "🏅 ${lp.translate("rank")}", "#$rank", isMobile)),
            ],
          ),
          SizedBox(height: isMobile ? 16 : 24),
          Text("🥇 Badge: ${_getLevelName(points, lp)}", style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: isMobile ? 14 : 16)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress, 
                    minHeight: isMobile ? 10 : 14, 
                    backgroundColor: theme.colorScheme.surfaceVariant, 
                    valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary)
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text("${(progress * 100).toInt()}%", style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
            ],
          ),
          const SizedBox(height: 4),
          Text("Progress to next rank", style: theme.textTheme.bodySmall?.copyWith(fontSize: isMobile ? 10 : 12)),
        ],
      ),
    );
  }

  Widget _buildSimpleStat(ThemeData theme, String label, String value, bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodySmall?.copyWith(fontSize: isMobile ? 10 : 12)),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: isMobile ? 24 : 32)),
        ),
      ],
    );
  }


  Widget _buildStatsCard(ThemeData theme, int total, int recyclable, int nonBio, LanguageProvider lp) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1))),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(lp.translate("items_recycled"), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              Text(total.toString(), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
            ],
          ),
          Divider(height: 32, color: theme.dividerColor.withValues(alpha: 0.1)),
          _buildStatRow(theme, "Recyclable", recyclable),
          _buildStatRow(theme, "Non-Biodegradable", nonBio),
        ],
      ),
    );
  }

  Widget _buildStatRow(ThemeData theme, String label, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyLarge),
          Text(count.toString(), style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildBadgesList(ThemeData theme, int points, LanguageProvider lp) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1))),
      child: Column(
        children: [
          _buildBadgeCheck(theme, lp.translate("eco_beginner"), points >= 100),
          _buildBadgeCheck(theme, lp.translate("eco_recycler"), points >= 250),
          _buildBadgeCheck(theme, lp.translate("eco_warrior"), points >= 500),
          _buildBadgeCheck(theme, lp.translate("green_guardian"), points >= 750),
          _buildBadgeCheck(theme, lp.translate("recycling_champion"), points >= 1000),
          _buildBadgeCheck(theme, lp.translate("sustainability_hero"), points >= 1500, isLocked: points < 1500),
        ],
      ),
    );
  }

  Widget _buildBadgeCheck(ThemeData theme, String name, bool completed, {bool isLocked = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(isLocked ? Icons.lock_outline : (completed ? Icons.check_circle : Icons.radio_button_unchecked), 
               color: isLocked ? theme.disabledColor : (completed ? theme.colorScheme.primary : theme.disabledColor.withValues(alpha: 0.5)), size: 20),
          const SizedBox(width: 12),
          Text(name, style: theme.textTheme.bodyLarge?.copyWith(color: isLocked ? theme.disabledColor : theme.textTheme.bodyLarge?.color, fontWeight: completed ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  Widget _buildActivityList(ThemeData theme, List<Map<String, dynamic>> activities) {
    if (activities.isEmpty) return Center(child: Text("No recent activity", style: theme.textTheme.bodySmall));
    return Container(
      decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1))),
      child: Column(
        children: activities.map((item) {
          return ListTile(
            title: Text(item['waste_type'] ?? "Activity", style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500)),
            trailing: Text("+${item['points_earned']} pts", style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildQuickActions(ThemeData theme, LanguageProvider lp, double screenWidth) {
    return GridView.count(
      crossAxisCount: screenWidth > 600 ? 2 : 1,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: screenWidth > 600 ? 3 : 5,
      children: [
        _buildActionBtn(theme, "History", Icons.history, "/history"),
        _buildActionBtn(theme, lp.translate("rewards"), Icons.card_giftcard, "/rewards"),
        _buildActionBtn(theme, lp.translate("rank"), Icons.leaderboard, "/badges"),
        _buildActionBtn(theme, "Settings", Icons.settings, "/settings"),
      ],
    );
  }

  Widget _buildActionBtn(ThemeData theme, String title, IconData icon, String route) {
    return ElevatedButton.icon(
      onPressed: () => Navigator.pushNamed(context, route),
      icon: Icon(icon, size: 18, color: theme.colorScheme.onSurface),
      label: Text(title, style: TextStyle(color: theme.colorScheme.onSurface)),
      style: ElevatedButton.styleFrom(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        alignment: Alignment.centerLeft,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1)),
      ),
    );
  }

  Widget _buildLogoutButton(ThemeData theme) {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text("Log out"),
              content: const Text("Are you sure you want to log out?"),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                TextButton(onPressed: _handleLogout, child: const Text("Log out", style: TextStyle(color: Colors.red))),
              ],
            ),
          );
        },
        style: TextButton.styleFrom(
          backgroundColor: theme.colorScheme.surface, 
          padding: const EdgeInsets.symmetric(vertical: 16), 
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.logout, color: Colors.orangeAccent),
            SizedBox(width: 12),
            Text("Log out", style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
