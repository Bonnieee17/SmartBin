import 'dart:async';
import 'dart:convert';
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
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      
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
                    await _uploadImage(bytes, image.name);
                  },
                  child: const Text("Save"),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error picking image: ${e.toString()}"), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _uploadImage(Uint8List bytes, String fileName) async {
    setState(() => _isUpdating = true);
    try {
      final user = _authService.currentUser;
      final prefs = await SharedPreferences.getInstance();
      final loggedId = prefs.getString('logged_student_id') ?? (user?.id ?? 'student_user');

      final ext = fileName.split('.').last.toLowerCase();
      final contentType = (ext == 'png') ? 'image/png' : 'image/jpeg';
      
      final storagePath = '${loggedId}_$fileName';

      String? publicUrl;

      // 1. Always upload directly to Supabase storage 'avatars' bucket
      try {
        await _supabase.storage.from('avatars').uploadBinary(
          storagePath,
          bytes,
          fileOptions: FileOptions(upsert: true, contentType: contentType),
        );
        publicUrl = _supabase.storage.from('avatars').getPublicUrl(storagePath);
      } catch (supabaseErr) {
        debugPrint("Supabase storage upload error: $supabaseErr");
      }
      
      // 2. Use Supabase public URL if successful, otherwise fallback to local base64 data URI
      final avatarValue = publicUrl ?? ('data:$contentType;base64,' + base64Encode(bytes));
      
      await prefs.setString('user_avatar', avatarValue);
      if (loggedId.isNotEmpty) {
        await prefs.setString('avatar_url_$loggedId', avatarValue);
      }

      // 3. Update public users table in Supabase if connected
      try {
        if (user != null) {
          await _supabase.auth.updateUser(UserAttributes(data: {'avatar_url': avatarValue}));
          await _supabase.from('users').upsert({
            'id': user.id, 
            'avatar_url': avatarValue,
          });
        } else {
          await _supabase.from('users').update({'avatar_url': avatarValue}).eq('student_id', loggedId);
        }
      } catch (_) {}
      
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Profile photo uploaded to Supabase avatars bucket!"),
            backgroundColor: AppTheme.primaryGreen,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final cleanErr = e.toString().replaceAll("Exception: ", "");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Upload Error: $cleanErr"),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 4),
          ),
        );
      }
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
          final dept = userData?['department'] ?? "CICI";

          return FutureBuilder<SharedPreferences>(
            future: SharedPreferences.getInstance(),
            builder: (context, prefsSnapshot) {
              final prefs = prefsSnapshot.data;
              final loggedId = prefs?.getString('logged_student_id');
              final localAvatar = prefs?.getString('user_avatar') ?? (loggedId != null ? prefs?.getString('avatar_url_$loggedId') : null);
              final avatarUrl = authUser?.userMetadata?['avatar_url'] ?? userData?['avatar_url'] ?? localAvatar;

              return FutureBuilder<String>(
                future: _authService.getEffectiveUserName(),
                builder: (context, nameSnapshot) {
                  final rawName = authUser?.userMetadata?['full_name'] ?? userData?['full_name'];
                  final fullName = (rawName != null && rawName.toString().trim().isNotEmpty && rawName != 'User' && rawName != 'Student')
                      ? rawName.toString().trim()
                      : (nameSnapshot.data ?? 'Student');

                  return FutureBuilder<String>(
                    future: _authService.getEffectiveStudentId(),
                    builder: (context, idSnapshot) {
                      final rawId = authUser?.userMetadata?['student_id'] ?? userData?['student_id'];
                      final studentId = (rawId != null && rawId.toString().trim().isNotEmpty && rawId != 'No ID' && rawId != 'N/A')
                          ? rawId.toString().trim()
                          : (idSnapshot.data ?? 'POB-1001');

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

                              final points = userData?['total_points'] ?? 0;

                              return _buildMainProfileUI(theme, languageProvider, fullName, studentId, dept, points, avatarUrl, totalRecycled, recyclable, nonBio, rank, history);
                            },
                          );
                        },
                      );
                    },
                  );
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

  void _showEditNameDialog(String currentName) {
    final nameController = TextEditingController(
      text: (currentName == 'Student' || currentName == 'Student User' || currentName == 'User') ? '' : currentName,
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Edit Registered Name"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Enter your registered full name:",
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: "Full Name",
                hintText: "e.g. Stephanie Perez",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final newName = nameController.text.trim();
              if (newName.isNotEmpty) {
                await _authService.updateUserName(newName);
                if (mounted) {
                  Navigator.pop(ctx);
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Registered name updated successfully!"),
                      backgroundColor: AppTheme.primaryGreen,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(ThemeData theme, String name, String id, String dept, String? avatar, bool isMobile) {
    ImageProvider? imageProvider;
    if (avatar != null && avatar.isNotEmpty) {
      if (avatar.startsWith('data:')) {
        try {
          final base64Data = avatar.split(',').last;
          final bytes = base64Decode(base64Data);
          imageProvider = MemoryImage(bytes);
        } catch (_) {}
      } else {
        imageProvider = NetworkImage(avatar);
      }
    }

    return Row(
      children: [
        GestureDetector(
          onTap: _isUpdating ? null : _pickImage,
          child: Stack(
            children: [
              CircleAvatar(
                radius: isMobile ? 36 : 48,
                backgroundColor: theme.colorScheme.secondary.withValues(alpha: 0.5),
                backgroundImage: imageProvider,
                child: imageProvider == null ? Icon(Icons.person, size: isMobile ? 36 : 48, color: theme.colorScheme.primary) : null,
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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name, 
                      style: (isMobile ? theme.textTheme.titleMedium : theme.textTheme.titleLarge)?.copyWith(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.primaryGreen),
                    tooltip: "Edit Registered Name",
                    onPressed: () => _showEditNameDialog(name),
                  ),
                ],
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
          _buildBadgeCheck(theme, lp.translate("eco_beginner"), points >= 100, 'assets/images/eco_beginner.png', Icons.eco_outlined, "100 pts"),
          _buildBadgeCheck(theme, lp.translate("eco_recycler"), points >= 250, 'assets/images/eco_recycler.png', Icons.recycling, "250 pts"),
          _buildBadgeCheck(theme, lp.translate("eco_warrior"), points >= 500, 'assets/images/eco_warrior.png', Icons.bolt, "500 pts"),
          _buildBadgeCheck(theme, lp.translate("green_guardian"), points >= 750, 'assets/images/green_guardian.png', Icons.forest, "750 pts"),
          _buildBadgeCheck(theme, lp.translate("recycling_champion"), points >= 1000, 'assets/images/recycling_champion.png', Icons.emoji_events, "1000 pts"),
          _buildBadgeCheck(theme, lp.translate("sustainability_hero"), points >= 1500, 'assets/images/sustainability_hero.png', Icons.public, "1500 pts", isLocked: points < 1500),
        ],
      ),
    );
  }

  Widget _buildBadgeCheck(ThemeData theme, String name, bool completed, String assetPath, IconData fallbackIcon, String pointsText, {bool isLocked = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isLocked ? theme.disabledColor.withValues(alpha: 0.1) : theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset(
                assetPath,
                width: 24,
                height: 24,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Icon(
                  fallbackIcon,
                  color: isLocked ? theme.disabledColor : theme.colorScheme.primary,
                  size: 22,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: isLocked ? theme.disabledColor : theme.textTheme.bodyLarge?.color,
                    fontWeight: completed ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  pointsText,
                  style: TextStyle(
                    fontSize: 11,
                    color: isLocked ? theme.disabledColor : theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            isLocked ? Icons.lock_outline : (completed ? Icons.check_circle : Icons.radio_button_unchecked),
            color: isLocked ? theme.disabledColor : (completed ? Colors.green : theme.disabledColor.withValues(alpha: 0.5)),
            size: 20,
          ),
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
