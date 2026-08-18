import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/database_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/language_provider.dart';

class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  final _databaseService = DatabaseService();
  final _supabase = Supabase.instance.client;
  
  Stream<List<Map<String, dynamic>>>? _userStream;
  Stream<List<Map<String, dynamic>>>? _rewardsStream;
  Stream<List<Map<String, dynamic>>>? _leaderboardStream;

  @override
  void initState() {
    super.initState();
    final user = _supabase.auth.currentUser;
    if (user != null) {
      _userStream = _supabase
          .from('users')
          .stream(primaryKey: ['id'])
          .eq('id', user.id);
    }
    
    _rewardsStream = _supabase.from('rewards').stream(primaryKey: ['id']).order('points_required');
    _leaderboardStream = _supabase.from('users').stream(primaryKey: ['id']).order('total_points', ascending: false).limit(5);
  }

  String _getLevelName(int points, LanguageProvider lp) {
    if (points < 100) return "New Recycler";
    if (points < 250) return lp.translate("eco_beginner");
    if (points < 500) return lp.translate("eco_recycler");
    if (points < 750) return lp.translate("eco_warrior");
    if (points < 1000) return lp.translate("green_guardian");
    return lp.translate("recycling_champion");
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
          final userData = userSnapshot.hasData && userSnapshot.data!.isNotEmpty 
              ? userSnapshot.data!.first 
              : null;
          final userPoints = userData?['total_points'] ?? 0;

          return SafeArea(
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
                        languageProvider.translate("rewards"),
                        style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    "$userPoints ${languageProvider.translate("points")} available",
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                  ),
                  const SizedBox(height: 24),
                  
                  // BADGES ROW
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildBadgeItem(theme, "Beginner", "100 pts", userPoints >= 100),
                      _buildBadgeItem(theme, "Recycler", "250 pts", userPoints >= 250),
                      _buildBadgeItem(theme, "Warrior", "500 pts", userPoints >= 500),
                      _buildBadgeItem(theme, "Guardian", "750 pts", userPoints >= 750),
                    ],
                  ),
                  
                  const SizedBox(height: 40),
                  Text(
                    "REDEEM",
                    style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold, color: theme.textTheme.bodySmall?.color, letterSpacing: 1),
                  ),
                  const SizedBox(height: 16),
                  
                  StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _rewardsStream,
                    builder: (context, rewardsSnapshot) {
                      if (rewardsSnapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!rewardsSnapshot.hasData || rewardsSnapshot.data!.isEmpty) {
                        return const Text("No rewards available at the moment.");
                      }
                      return Column(
                        children: rewardsSnapshot.data!.map((reward) {
                          final cost = reward['points_required'] ?? 0;
                          final canRedeem = userPoints >= cost;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildRedeemItem(
                              theme,
                              reward['reward_name'], 
                              "$cost pts", 
                              canRedeem ? "Redeem" : "Locked", 
                              isLocked: !canRedeem
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 40),
                  Text(
                    "THIS WEEK'S TOP RECYCLERS",
                    style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold, color: theme.textTheme.bodySmall?.color, letterSpacing: 1),
                  ),
                  const SizedBox(height: 16),
                  
                  StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _leaderboardStream,
                    builder: (context, leaderboardSnapshot) {
                      if (!leaderboardSnapshot.hasData || leaderboardSnapshot.data!.isEmpty) {
                        return const Text("Leaderboard is empty.");
                      }
                      return Column(
                        children: List.generate(leaderboardSnapshot.data!.length, (index) {
                          final user = leaderboardSnapshot.data![index];
                          return _buildLeaderboardItem(
                            theme,
                            index + 1, 
                            user['full_name'] ?? "Unknown", 
                            "${user['total_points'] ?? 0}", 
                            _getLevelName(user['total_points'] ?? 0, languageProvider)
                          );
                        }),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBadgeItem(ThemeData theme, String name, String pts, bool isEarned) {
    return Column(
      children: [
        Container(
          height: 60,
          width: 60,
          decoration: BoxDecoration(
            color: isEarned ? theme.colorScheme.primary : theme.disabledColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.emoji_events, color: isEarned ? theme.colorScheme.onPrimary : theme.disabledColor),
        ),
        const SizedBox(height: 8),
        Text(name, style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold, color: isEarned ? theme.textTheme.bodyLarge?.color : theme.disabledColor)),
        Text(pts, style: theme.textTheme.labelSmall?.copyWith(color: theme.disabledColor, fontSize: 10)),
      ],
    );
  }

  Widget _buildRedeemItem(ThemeData theme, String title, String cost, String action, {bool isLocked = false}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.inventory_2_outlined, color: isLocked ? theme.disabledColor : theme.colorScheme.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: isLocked ? theme.disabledColor : theme.textTheme.bodyLarge?.color)),
                Text(cost, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: isLocked ? null : () {},
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: isLocked ? theme.disabledColor.withValues(alpha: 0.2) : theme.colorScheme.primary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              foregroundColor: isLocked ? theme.disabledColor : theme.colorScheme.primary,
            ),
            child: Text(action),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardItem(ThemeData theme, int rank, String name, String points, String level) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(width: 24, child: Text("$rank", style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: theme.disabledColor))),
          CircleAvatar(radius: 20, backgroundColor: theme.colorScheme.secondary.withValues(alpha: 0.5)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
                Text(level, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          Text(points, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
