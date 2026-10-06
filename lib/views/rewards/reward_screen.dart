import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/database_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/language_provider.dart';
import '../../models/voucher_model.dart';

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

  Future<void> _confirmRedeem(String rewardName, int pointsCost, int userPoints) async {
    if (userPoints < 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Minimum redemption is ₱20.00 (200 points). Points below ₱20 are pending to earn!")),
      );
      return;
    }

    final user = _supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please sign in to redeem rewards.")),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Claim Reward Ticket?"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Reward: $rewardName", style: const TextStyle(fontWeight: FontWeight.bold)),
            Text("Cost: $pointsCost Eco Points"),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.location_on, color: AppTheme.primaryGreen, size: 24),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "You will receive a SmartBin Digital Unique Identifier pass valid for 3 days to claim at the PSITS Office.",
                      style: TextStyle(fontSize: 12, color: AppTheme.primaryGreen, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Confirm & Claim"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final voucher = await _databaseService.generateDigitalVoucherPass(
        userId: user.id,
        pointsCost: pointsCost,
        rewardName: rewardName,
        validityDays: 3,
      );

      if (!mounted) return;
      _showVoucherTicketModal(voucher);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString().replaceAll("Exception: ", "")}")),
      );
    }
  }

  void _showVoucherTicketModal(VoucherModel voucher) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Icon(Icons.confirmation_number_rounded, size: 48, color: AppTheme.primaryGreen),
                const SizedBox(height: 8),
                const Text(
                  "SmartBin Digital Unique Identifier",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Text(
                  "PSITS Office Claim Pass",
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 16),

                // Identifier Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.primaryGreen, width: 1.5),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        "DIGITAL UNIQUE IDENTIFIER",
                        style: TextStyle(fontSize: 10, letterSpacing: 1.2, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        voucher.code,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: AppTheme.primaryGreen),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // QR Code Display
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: QrImageView(
                    data: voucher.code,
                    version: QrVersions.auto,
                    size: 160.0,
                    embeddedImage: const AssetImage('assets/images/logo.png'),
                    embeddedImageStyle: const QrEmbeddedImageStyle(size: Size(30, 30)),
                  ),
                ),

                const SizedBox(height: 16),

                // Details List
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      _buildTicketDetailRow("Reward", voucher.rewardName),
                      const Divider(height: 16),
                      _buildTicketDetailRow("Cost", "${voucher.pointsCost} Eco Points"),
                      const Divider(height: 16),
                      _buildTicketDetailRow("Claim Office", voucher.claimLocation),
                      const Divider(height: 16),
                      _buildTicketDetailRow("Validity Window", "3 Days from Claiming"),
                      const Divider(height: 16),
                      _buildTicketDetailRow(
                        "Status",
                        voucher.isClaimed
                            ? "Claimed at PSITS Office"
                            : (voucher.isExpired ? "Expired" : voucher.formattedRemainingTime),
                        isBadge: true,
                        statusColor: voucher.isClaimed
                            ? Colors.blue
                            : (voucher.isExpired ? Colors.red : Colors.green),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text("Done & View Claim Passes", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTicketDetailRow(String label, String value, {bool isBadge = false, Color? statusColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        if (isBadge)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: (statusColor ?? Colors.green).withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: (statusColor ?? Colors.green).withOpacity(0.4)),
            ),
            child: Text(
              value,
              style: TextStyle(color: statusColor ?? Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          )
        else
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }

  void _showMyVouchersModal() {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Row(
                children: [
                  Icon(Icons.confirmation_number_outlined, color: AppTheme.primaryGreen),
                  SizedBox(width: 8),
                  Text(
                    "My PSITS Claim Tickets",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const Text(
                "Present your digital unique identifier code or QR to the PSITS Office within 3 days.",
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: FutureBuilder<List<VoucherModel>>(
                  future: _databaseService.getUserVouchers(user.id),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(
                        child: Text("No claim tickets yet.\nRedeem a reward above to get one!", textAlign: TextAlign.center),
                      );
                    }

                    final tickets = snapshot.data!;
                    return ListView.builder(
                      itemCount: tickets.length,
                      itemBuilder: (context, index) {
                        final t = tickets[index];
                        final isClaimed = t.isClaimed;
                        final isExpired = t.isExpired;

                        Color badgeColor = Colors.green;
                        String badgeText = t.formattedRemainingTime;
                        if (isClaimed) {
                          badgeColor = Colors.blue;
                          badgeText = "Claimed";
                        } else if (isExpired) {
                          badgeColor = Colors.red;
                          badgeText = "Expired (3 Days Passed)";
                        }

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: badgeColor.withOpacity(0.3)),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(12),
                            leading: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: badgeColor.withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isClaimed
                                    ? Icons.check_circle
                                    : (isExpired ? Icons.cancel : Icons.qr_code_2),
                                color: badgeColor,
                              ),
                            ),
                            title: Text(
                              t.rewardName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Code: ${t.code}", style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.primaryGreen)),
                                Text(badgeText, style: TextStyle(color: badgeColor, fontSize: 11, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            trailing: OutlinedButton(
                              onPressed: () => _showVoucherTicketModal(t),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.primaryGreen,
                                side: const BorderSide(color: AppTheme.primaryGreen),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Text("View Pass", style: TextStyle(fontSize: 12)),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                      OutlinedButton.icon(
                        onPressed: _showMyVouchersModal,
                        icon: const Icon(Icons.confirmation_number_outlined, size: 18),
                        label: const Text("My Claim Tickets", style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryGreen,
                          side: const BorderSide(color: AppTheme.primaryGreen),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    "$userPoints ${languageProvider.translate("points")} available",
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.withOpacity(0.4)),
                    ),
                    child: Text(
                      "Estimated Value: ₱${(userPoints / 10).toStringAsFixed(2)} (10 Pts = ₱1.00)",
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFB78103)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // BADGES ROW (Adaptive)
                  Center(
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      alignment: WrapAlignment.center,
                      children: [
                        _buildBadgeItem(theme, "Beginner", "100 pts", userPoints >= 100),
                        _buildBadgeItem(theme, "Recycler", "250 pts", userPoints >= 250),
                        _buildBadgeItem(theme, "Warrior", "500 pts", userPoints >= 500),
                        _buildBadgeItem(theme, "Guardian", "750 pts", userPoints >= 750),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  Text(
                    "REDEEM",
                    style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold, color: theme.textTheme.bodySmall?.color, letterSpacing: 1),
                  ),
                  const SizedBox(height: 16),

                  if (userPoints < 200) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.orange.withOpacity(0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.hourglass_empty_rounded, color: Colors.orange, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Pending Points to Earn",
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 14),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "You have ₱${(userPoints / 10).toStringAsFixed(2)} ($userPoints pts). Reach at least ₱20.00 (200 pts) to unlock voucher redemption and claim at PSITS Office.",
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  
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
                          final hasReachedMinThreshold = userPoints >= 200;
                          final canRedeem = hasReachedMinThreshold && (userPoints >= cost);
                          final name = reward['reward_name'] ?? 'Reward';

                          String actionText = "Redeem";
                          if (!hasReachedMinThreshold) {
                            actionText = "Pending (< ₱20)";
                          } else if (!canRedeem) {
                            actionText = "Locked";
                          }

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildRedeemItem(
                              theme,
                              name, 
                              "$cost pts", 
                              actionText, 
                              isLocked: !canRedeem,
                              onTap: canRedeem ? () => _confirmRedeem(name, cost, userPoints) : null,
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

  Widget _buildRedeemItem(ThemeData theme, String title, String cost, String action, {bool isLocked = false, VoidCallback? onTap}) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 400;

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            height: isMobile ? 40 : 48,
            width: isMobile ? 40 : 48,
            decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.inventory_2_outlined, color: isLocked ? theme.disabledColor : theme.colorScheme.primary, size: isMobile ? 20 : 24),
          ),
          SizedBox(width: isMobile ? 12 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title, 
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold, 
                    color: isLocked ? theme.disabledColor : theme.textTheme.bodyLarge?.color,
                    fontSize: isMobile ? 13 : 16,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(cost, style: theme.textTheme.bodySmall?.copyWith(fontSize: isMobile ? 10 : 12)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: isLocked ? null : onTap,
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: 8),
              side: BorderSide(color: isLocked ? theme.disabledColor.withValues(alpha: 0.2) : theme.colorScheme.primary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              foregroundColor: isLocked ? theme.disabledColor : theme.colorScheme.primary,
            ),
            child: Text(action, style: TextStyle(fontSize: isMobile ? 11 : 14)),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardItem(ThemeData theme, int rank, String name, String points, String level) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 400;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: isMobile ? 20 : 24, 
            child: Text(
              "$rank", 
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold, 
                color: theme.disabledColor,
                fontSize: isMobile ? 14 : 16,
              )
            )
          ),
          CircleAvatar(
            radius: isMobile ? 18 : 20, 
            backgroundColor: theme.colorScheme.secondary.withOpacity(0.5)
          ),
          SizedBox(width: isMobile ? 12 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name, 
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: isMobile ? 14 : 16,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  level, 
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: isMobile ? 10 : 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            points, 
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: isMobile ? 14 : 16,
            )
          ),
        ],
      ),
    );
  }
}
