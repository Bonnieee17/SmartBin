import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/providers/language_provider.dart';

class BadgesScreen extends StatefulWidget {
  const BadgesScreen({super.key});

  @override
  State<BadgesScreen> createState() => _BadgesScreenState();
}

class _BadgesScreenState extends State<BadgesScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _badges = [];
  int _userPoints = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final profile = await _supabase
            .from('users')
            .select('total_points')
            .eq('id', user.id)
            .single();
        _userPoints = profile['total_points'] ?? 0;
      }

      final badges = await _supabase.from('badges').select().order('points_required');
      
      setState(() {
        _badges = badges;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  IconData _getBadgeIcon(String? iconName) {
    final name = iconName?.replaceAll('.png', '') ?? '';
    switch (name) {
      case 'eco_beginner': return Icons.emoji_events_outlined;
      case 'eco_recycler': return Icons.recycling;
      case 'eco_warrior': return Icons.shield_outlined;
      case 'green_guardian': return Icons.nature_people_outlined;
      case 'recycling_champion': return Icons.workspace_premium;
      case 'sustainability_hero': return Icons.auto_awesome;
      default: return Icons.military_tech;
    }
  }

  String _getCurrentRank(LanguageProvider lp) {
    String rank = "New Recycler";
    for (var badge in _badges) {
      if (_userPoints >= badge['points_required']) {
        rank = badge['badge_name'];
      }
    }
    if (rank == "Eco Beginner") return lp.translate("eco_beginner");
    if (rank == "Eco Recycler") return lp.translate("eco_recycler");
    if (rank == "Eco Warrior") return lp.translate("eco_warrior");
    if (rank == "Green Guardian") return lp.translate("green_guardian");
    if (rank == "Recycling Champion") return lp.translate("recycling_champion");
    if (rank == "Sustainability Hero") return lp.translate("sustainability_hero");
    
    return rank;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          languageProvider.translate("rank"),
                          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  // Rank Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      border: Border(bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1))),
                    ),
                    child: Column(
                      children: [
                        Text(
                          "Your Current Level:",
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.textTheme.bodySmall?.color),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _getCurrentRank(languageProvider),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "${languageProvider.translate("points")}: $_userPoints",
                          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: _badges.length,
                      itemBuilder: (context, index) {
                        final badge = _badges[index];
                        final pointsRequired = badge['points_required'] as int;
                        final isEarned = _userPoints >= pointsRequired;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          color: isEarned ? theme.colorScheme.surface : theme.colorScheme.surface.withValues(alpha: 0.5),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            leading: CircleAvatar(
                              radius: 30,
                              backgroundColor: isEarned 
                                  ? theme.colorScheme.primary.withValues(alpha: 0.1) 
                                  : theme.disabledColor.withValues(alpha: 0.1),
                              child: Icon(
                                _getBadgeIcon(badge['badge_icon']),
                                size: 30,
                                color: isEarned 
                                    ? theme.colorScheme.primary 
                                    : theme.disabledColor,
                              ),
                            ),
                            title: Text(
                              "${badge['badge_name']}: $pointsRequired ${languageProvider.translate("points")}",
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isEarned ? null : theme.disabledColor,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  badge['description'] ?? "",
                                  style: TextStyle(
                                    color: isEarned ? null : theme.disabledColor,
                                  ),
                                ),
                              ],
                            ),
                            trailing: isEarned
                                ? const Icon(Icons.check_circle, color: Colors.green)
                                : Text(
                                    "${_userPoints}/${pointsRequired}",
                                    style: TextStyle(color: theme.disabledColor, fontSize: 12),
                                  ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
