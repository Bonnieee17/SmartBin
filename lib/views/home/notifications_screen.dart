import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _supabase = Supabase.instance.client;
  
  Stream<List<Map<String, dynamic>>>? _historyStream;
  Stream<Map<String, dynamic>>? _userStream;

  @override
  void initState() {
    super.initState();
    _setupStreams();
  }

  void _setupStreams() {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      _historyStream = _supabase
          .from('disposal_history')
          .stream(primaryKey: ['id'])
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(10);
      
      _userStream = _supabase
          .from('users')
          .stream(primaryKey: ['id'])
          .eq('id', user.id)
          .map((data) => data.isNotEmpty ? data.first : {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Notifications"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _historyStream,
        builder: (context, historySnapshot) {
          return StreamBuilder<Map<String, dynamic>>(
            stream: _userStream,
            builder: (context, userSnapshot) {
              if (historySnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final notifications = _generateNotifications(
                historySnapshot.data ?? [],
                userSnapshot.data ?? {},
              );

              if (notifications.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_none_outlined, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text("No new notifications", style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: notifications.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final notif = notifications[index];
                  return _buildNotificationCard(theme, notif);
                },
              );
            },
          );
        },
      ),
    );
  }

  List<Map<String, dynamic>> _generateNotifications(List<Map<String, dynamic>> history, Map<String, dynamic> user) {
    final List<Map<String, dynamic>> list = [];

    // 1. Welcome Notification (Always first for new users or as a base)
    list.add({
      'type': 'system',
      'title': 'Welcome to SmartBin 2025!',
      'message': 'Start recycling to earn points and climb the ranks.',
      'time': 'Just now',
      'icon': Icons.stars,
      'color': Colors.amber,
    });

    // 2. Rank Milestones
    final points = user['total_points'] ?? 0;
    if (points >= 100) {
      list.add({
        'type': 'achievement',
        'title': 'New Rank Achieved!',
        'message': 'Congratulations! You are now an Eco Beginner.',
        'time': 'Recent',
        'icon': Icons.emoji_events,
        'color': Colors.blue,
      });
    }

    // 3. Recycling Activity (Derived from history)
    for (var entry in history) {
      final type = entry['waste_type'] ?? 'Item';
      final pts = entry['points_earned'] ?? 0;
      final createdAt = DateTime.parse(entry['created_at']);
      
      list.add({
        'type': 'activity',
        'title': 'Points Earned!',
        'message': 'You earned $pts points for recycling a $type.',
        'time': DateFormat('MMM d, h:mm a').format(createdAt),
        'icon': Icons.recycling,
        'color': AppTheme.primaryGreen,
      });
    }

    return list;
  }

  Widget _buildNotificationCard(ThemeData theme, Map<String, dynamic> notif) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (notif['color'] as Color).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(notif['icon'] as IconData, color: notif['color'] as Color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(notif['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(notif['time'], style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  notif['message'],
                  style: TextStyle(color: Colors.black87, fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
