import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import 'widgets/history_card.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _supabase = Supabase.instance.client;
  final _authService = AuthService();
  final _databaseService = DatabaseService();

  String selectedFilter = "All";
  Stream<List<Map<String, dynamic>>>? _historyStream;

  final List<String> filters = [
    "All",
    "Recyclable",
    "Non-Biodegradable",
  ];

  @override
  void initState() {
    super.initState();
    _setupStream();
  }

  void _setupStream() {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    var query = _supabase
        .from('disposal_history')
        .stream(primaryKey: ['id'])
        .eq('user_id', user.id)
        .order('created_at', ascending: false);
    
    _historyStream = query;
  }

  Widget _buildHistoryList(ThemeData theme, List<Map<String, dynamic>> rawItems) {
    var items = List<Map<String, dynamic>>.from(rawItems);

    if (selectedFilter != "All") {
      items = items.where((item) {
        final type = item['waste_type']?.toString().toLowerCase() ?? "";
        final isRecyclable = type.contains('bottle') ||
            type.contains('paper') ||
            type.contains('metal') ||
            type.contains('can') ||
            type.contains('glass');

        if (selectedFilter == "Recyclable") return isRecyclable;
        if (selectedFilter == "Non-Biodegradable") return !isRecyclable;
        return true;
      }).toList();
    }

    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              "No disposal history recorded yet.",
              style: theme.textTheme.headlineSmall?.copyWith(
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final dateObj = DateTime.tryParse(item['created_at'].toString()) ?? DateTime.now();

        return HistoryCard(
          wasteType: item['waste_type'] ?? "Disposal Record",
          points: "+${item['points_earned'] ?? 10} Points",
          date: "${dateObj.month}/${dateObj.day}/${dateObj.year}",
          time: "${dateObj.hour}:${dateObj.minute.toString().padLeft(2, '0')}",
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
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
                    "Disposal History",
                    style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // FILTERS
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: filters.map((filter) {
                  final isSelected = selectedFilter == filter;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedFilter = filter;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        filter,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),

              // LIST
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _historyStream,
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                      return _buildHistoryList(theme, snapshot.data!);
                    }

                    // Fallback to local history for offline support
                    return FutureBuilder<String>(
                      future: _authService.getEffectiveUserId(),
                      builder: (context, userSnapshot) {
                        final userId = userSnapshot.data ?? 'student_local';
                        return FutureBuilder<List<Map<String, dynamic>>>(
                          future: _databaseService.getLocalDisposalHistory(userId),
                          builder: (context, localSnapshot) {
                            if (localSnapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            final list = localSnapshot.data ?? [];
                            return _buildHistoryList(theme, list);
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
