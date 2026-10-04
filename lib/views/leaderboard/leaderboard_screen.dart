import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../services/database_service.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dbService = DatabaseService();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Campus Leaderboard"),
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: dbService.getUsersStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final users = snapshot.data ?? [];
          if (users.isEmpty) {
            return const Center(child: Text("No recyclers on the leaderboard yet."));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              final rank = index + 1;
              final name = user['full_name'] ?? user['student_id'] ?? 'Recycler $rank';
              final points = user['total_points'] ?? 0;
              final dept = user['department'] ?? 'CICI';

              Color rankColor = Colors.grey;
              if (rank == 1) rankColor = const Color(0xFFFFD700); // Gold
              if (rank == 2) rankColor = const Color(0xFFC0C0C0); // Silver
              if (rank == 3) rankColor = const Color(0xFFCD7F32); // Bronze

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1)),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: rank <= 3 ? rankColor.withValues(alpha: 0.2) : theme.colorScheme.primary.withValues(alpha: 0.1),
                    child: Text(
                      "#$rank",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: rank <= 3 ? rankColor : theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("Department: $dept", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "$points pts",
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
