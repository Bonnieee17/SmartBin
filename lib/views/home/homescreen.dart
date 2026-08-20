import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/language_provider.dart';
import 'widgets/claim_points_dialog.dart';
import '../../services/deep_link_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _supabase = Supabase.instance.client;
  final _authService = AuthService();
  
  Stream<List<Map<String, dynamic>>>? _userStream;
  Stream<List<Map<String, dynamic>>>? _historyStream;
  late final Stream<List<Map<String, dynamic>>> _allUsersStream;
  late final Stream<List<Map<String, dynamic>>> _allHistoryStream;
  late final StreamSubscription<AuthState> _authSubscription;

  @override
  void initState() {
    super.initState();
    _setupStreams();
    _authSubscription = _supabase.auth.onAuthStateChange.listen((data) {
      if (mounted) setState(() {});
    });

    // Listen for incoming claim links while the app is already open
    DeepLinkService.onLinkDetected.listen((data) {
      if (mounted) {
        if (data.points != null && data.type != null && data.binId != null) {
          _showClaimDialog(data.points!, data.type!, data.binId!);
        } else if (data.voucher != null && data.cost != null) {
          _showVoucherRedemptionDialog(data.voucher!, data.cost!);
        }
      }
    });

    // Check if there was a pending claim from app startup (e.g. user was logged out)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pending = DeepLinkService.pendingClaim;
      if (pending != null && mounted) {
        if (pending.points != null && pending.type != null && pending.binId != null) {
          _showClaimDialog(pending.points!, pending.type!, pending.binId!);
        } else if (pending.voucher != null && pending.cost != null) {
          _showVoucherRedemptionDialog(pending.voucher!, pending.cost!);
        }
        DeepLinkService.clearPendingClaim();
      }
    });
  }

  void _showVoucherRedemptionDialog(String name, int cost) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text("Redeem Voucher?"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.confirmation_number_outlined, size: 64, color: AppTheme.primaryGreen),
            const SizedBox(height: 24),
            Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            Text("This will deduct $cost points from your account.", textAlign: TextAlign.center),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          FilledButton(
            onPressed: () async {
              try {
                final user = _authService.currentUser;
                if (user != null) {
                  await _supabase.rpc('redeem_points', params: {'user_id': user.id, 'amount': cost});
                  // If RPC not setup, we use the fallback method in DatabaseService
                  // For now, let's assume we use the client-side logic we built in DatabaseService
                  final databaseService = DatabaseService();
                  await databaseService.redeemVoucher(userId: user.id, pointsCost: cost, rewardName: name);
                  
                  if (mounted) {
                    Navigator.pop(context);
                    _showVoucherSuccess(name, cost);
                  }
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                  Navigator.pop(context);
                }
              }
            },
            child: const Text("REDEEM"),
          ),
        ],
      ),
    );
  }

  void _showVoucherSuccess(String name, int points) {
    final pesos = points / 10.0;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 60),
        title: const Text("Success!"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Voucher: $name"),
            const SizedBox(height: 8),
            Text("₱${pesos.toStringAsFixed(2)} Redeemed", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))],
      ),
    );
  }

  void _showClaimDialog(int points, String type, String binId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ClaimPointsDialog(
        points: points,
        wasteType: type,
        binId: binId,
      ),
    );
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
          .stream(primaryKey: ['id']);

      _allHistoryStream = _supabase
          .from('disposal_history')
          .stream(primaryKey: ['id']);
    }
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  String _getLevelName(int points, LanguageProvider lp) {
    if (points < 100) return lp.translate("eco_beginner");
    if (points < 250) return lp.translate("eco_recycler");
    if (points < 500) return lp.translate("eco_warrior");
    if (points < 750) return lp.translate("green_guardian");
    if (points < 1000) return lp.translate("recycling_champion");
    return lp.translate("sustainability_hero");
  }

  int _getNextLevelPoints(int points) {
    if (points < 100) return 100;
    if (points < 250) return 250;
    if (points < 500) return 500;
    if (points < 750) return 750;
    if (points < 1000) return 1000;
    return 2000;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final screenWidth = MediaQuery.of(context).size.width;

    Widget content = Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _userStream,
        builder: (context, userSnapshot) {
          if (userSnapshot.hasError) {
            return _buildErrorState(theme, languageProvider, "User Data Error");
          }
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final userData = userSnapshot.hasData && userSnapshot.data!.isNotEmpty 
              ? userSnapshot.data!.first 
              : null;
          
          final fullName = _supabase.auth.currentUser?.userMetadata?['full_name'] ?? userData?['full_name'] ?? "User";
          final points = userData?['total_points'] ?? 0;
          final levelName = _getLevelName(points, languageProvider);
          final nextPoints = _getNextLevelPoints(points);

          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: _historyStream,
            builder: (context, historySnapshot) {
              if (historySnapshot.hasError) {
                // Return main UI with empty history if stream fails
                return _buildMainHomeUI(context, theme, languageProvider, screenWidth, fullName, points, levelName, nextPoints, [], 0, 0, 0.0);
              }
              final List<Map<String, dynamic>> history = historySnapshot.data ?? [];
              final itemsRecycled = history.length;
              final List<Map<String, dynamic>> recentActivities = List<Map<String, dynamic>>.from(history.take(5));

              return StreamBuilder<List<Map<String, dynamic>>>(
                stream: _allUsersStream,
                builder: (context, allUsersSnapshot) {
                  return StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _allHistoryStream,
                    builder: (context, allHistorySnapshot) {
                      final totalStudents = (allUsersSnapshot.data ?? []).where((u) => (u['role'] ?? "") != 'admin').length;
                      double totalWeightKg = 0;
                      for (var item in (allHistorySnapshot.data ?? [])) {
                        totalWeightKg += (item['weight_kg'] ?? 0.0);
                      }

                      return _buildMainHomeUI(
                        context, theme, languageProvider, screenWidth, fullName, points, levelName, nextPoints, 
                        recentActivities, itemsRecycled, totalStudents, totalWeightKg
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),

      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: NavigationBar(
            elevation: 0,
            backgroundColor: theme.colorScheme.surface,
            selectedIndex: 0,
            indicatorColor: theme.colorScheme.secondary.withValues(alpha: 0.5),
            onDestinationSelected: (index) {
              switch (index) {
                case 1: Navigator.pushNamed(context, "/rewards"); break;
                case 2: Navigator.pushNamed(context, "/history"); break;
                case 3: Navigator.pushNamed(context, "/profile"); break;
              }
            },
            destinations: [
              NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home), label: languageProvider.translate("home")),
              NavigationDestination(icon: const Icon(Icons.card_giftcard_outlined), selectedIcon: const Icon(Icons.card_giftcard), label: languageProvider.translate("rewards")),
              NavigationDestination(icon: const Icon(Icons.leaderboard_outlined), selectedIcon: const Icon(Icons.leaderboard), label: languageProvider.translate("rank")),
              NavigationDestination(icon: const Icon(Icons.person_outline), selectedIcon: const Icon(Icons.person), label: languageProvider.translate("profile")),
            ],
          ),
        ),
      ),
    );

    return content;
  }

  Widget _buildErrorState(ThemeData theme, LanguageProvider lp, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(message, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text("Unable to connect to SmartBin servers. Some features may be limited.", textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: () => setState(() {}), child: const Text("Retry Connection")),
          ],
        ),
      ),
    );
  }

  Widget _buildMainHomeUI(
    BuildContext context, 
    ThemeData theme, 
    LanguageProvider languageProvider, 
    double screenWidth, 
    String fullName, 
    int points, 
    String levelName, 
    int nextPoints, 
    List<Map<String, dynamic>> recentActivities,
    int itemsRecycled,
    int totalStudents,
    double totalWeightKg,
  ) {
    final impactStudents = totalStudents > 0 ? totalStudents - 1 : 0;
    final tons = totalWeightKg / 1000;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: screenWidth > 900 ? 60 : 24, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    "${languageProvider.translate("hi")}, ${fullName.split(' ')[0]}",
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                      fontSize: screenWidth > 900 ? 44 : 32,
                    ),
                  ),
                ),
                if (screenWidth > 900)
                  Row(
                    children: [
                      Stack(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.notifications_none_outlined, size: 28), 
                            onPressed: () => Navigator.pushNamed(context, "/notifications"),
                          ),
                          if (itemsRecycled > 0)
                            Positioned(
                              right: 12,
                              top: 12,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                constraints: const BoxConstraints(minWidth: 8, minHeight: 8),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                        child: Text(fullName.isNotEmpty ? fullName[0] : "U", style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 18)),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 40),
            
            // LEVEL CARD & STATS ROW (Adaptive)
            if (screenWidth > 900)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: _buildLevelCard(theme, levelName, points, nextPoints, languageProvider),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 2,
                    child: Row(
                      children: [
                        Expanded(child: _buildStatCard(theme, languageProvider.translate("points"), "$points")),
                        const SizedBox(width: 16),
                        Expanded(child: _buildStatCard(theme, languageProvider.translate("items_recycled"), "$itemsRecycled")),
                      ],
                    ),
                  ),
                ],
              )
            else
              Column(
                children: [
                  _buildLevelCard(theme, levelName, points, nextPoints, languageProvider),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(child: _buildStatCard(theme, languageProvider.translate("points"), "$points")),
                      const SizedBox(width: 16),
                      Expanded(child: _buildStatCard(theme, languageProvider.translate("items_recycled"), "$itemsRecycled")),
                    ],
                  ),
                ],
              ),
            
            const SizedBox(height: 40),
            
            // ACTION BUTTON & RECENT ACTIVITY
            if (screenWidth > 1200)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildScanButton(context, languageProvider),
                        const SizedBox(height: 40),
                        _buildRecentActivityHeader(languageProvider, theme),
                        _buildActivityList(recentActivities, theme),
                      ],
                    ),
                  ),
                  const SizedBox(width: 48),
                  // Professional Impact Summary
                  Expanded(
                    flex: 1,
                    child: Container(
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.1)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.auto_graph_outlined, size: 64, color: AppTheme.primaryGreen),
                          const SizedBox(height: 24),
                          const Text("Community Impact", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
                          const SizedBox(height: 12),
                          Text(
                            "You and $impactStudents other students have collected ${tons.toStringAsFixed(2)} tons of waste this month. Keep going!",
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.black54),
                          ),
                          const SizedBox(height: 32),
                          FilledButton.icon(
                            onPressed: () {}, 
                            icon: const Icon(Icons.emoji_events_outlined),
                            label: const Text("View Leaderboard"),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            else
              Column(
                children: [
                  _buildScanButton(context, languageProvider),
                  const SizedBox(height: 40),
                  _buildRecentActivityHeader(languageProvider, theme),
                  _buildActivityList(recentActivities, theme),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      children: [
                        const Text("Community Impact", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        const SizedBox(height: 8),
                        Text(
                          "You and $impactStudents other students have collected ${tons.toStringAsFixed(2)} tons of waste. Keep going!",
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }


  Widget _buildLevelCard(ThemeData theme, String levelName, int points, int nextPoints, LanguageProvider lp) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Container(
      padding: EdgeInsets.all(isMobile ? 20 : 28),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [BoxShadow(color: theme.colorScheme.primary.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            decoration: BoxDecoration(
              color: theme.colorScheme.onPrimary.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.eco, color: theme.colorScheme.onPrimary, size: isMobile ? 28 : 36),
          ),
          SizedBox(width: isMobile ? 16 : 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  levelName,
                  style: TextStyle(
                    color: theme.colorScheme.onPrimary, 
                    fontSize: isMobile ? 18 : 22, 
                    fontWeight: FontWeight.bold
                  ),
                ),
                if (points < 1500)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: (points / nextPoints).clamp(0.0, 1.0),
                          backgroundColor: theme.colorScheme.onPrimary.withOpacity(0.1),
                          valueColor: AlwaysStoppedAnimation(theme.colorScheme.onPrimary),
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "${nextPoints - points} ${lp.translate("pts_to_next")}",
                        style: TextStyle(
                          color: theme.colorScheme.onPrimary.withOpacity(0.8), 
                          fontSize: isMobile ? 12 : 14, 
                          fontWeight: FontWeight.w500
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanButton(BuildContext context, LanguageProvider lp) {
    return ElevatedButton(
      onPressed: () => Navigator.pushNamed(context, "/scanner"),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFE6AD62),
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 72),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.qr_code_scanner, size: 28),
          const SizedBox(width: 16),
          Text(lp.translate("generate_qr"), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _buildRecentActivityHeader(LanguageProvider lp, ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          lp.translate("recent_activity").toUpperCase(),
          style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.grey[600], letterSpacing: 1.5),
        ),
        TextButton(
          onPressed: () => Navigator.pushNamed(context, "/history"),
          child: Text(lp.translate("view_all"), style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildActivityList(List<Map<String, dynamic>> activities, ThemeData theme) {
    if (activities.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: Text("No activities yet. Start recycling today!", style: TextStyle(color: Colors.grey))),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: activities.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final activity = activities[index];
        return _buildActivityItem(
          theme,
          activity['waste_type'] ?? "Unknown",
          activity['created_at'],
          activity['points_earned'] ?? 0,
        );
      },
    );
  }

  Widget _buildStatCard(ThemeData theme, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.textTheme.bodySmall?.color, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(ThemeData theme, String title, String? timestamp, int points) {
    String dateStr = "Just now";
    if (timestamp != null) {
      final date = DateTime.parse(timestamp);
      dateStr = DateFormat('MMM d, h:mm a').format(date);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.recycling, color: theme.colorScheme.primary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
                Text(
                  dateStr,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Text(
            "+$points",
            style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
          ),
        ],
      ),
    );
  }
}
