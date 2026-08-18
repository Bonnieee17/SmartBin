import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';
import '../../core/theme/app_theme.dart';
import 'widgets/summary_card.dart';
import 'widgets/waste_chart_placeholder.dart';
import 'widgets/user_table.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final _databaseService = DatabaseService();
  final _authService = AuthService();
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final useDrawer = screenWidth < 1000;

    return Scaffold(
      backgroundColor: AppTheme.backgroundBeige,
      appBar: useDrawer
          ? AppBar(
              title: const Text("SmartBin Admin"),
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: Colors.white,
            )
          : null,
      drawer: useDrawer ? Drawer(child: _buildSidebarContent()) : null,
      body: Row(
        children: [
          // SIDEBAR (Desktop)
          if (!useDrawer)
            SizedBox(
              width: 280,
              child: _buildSidebarContent(),
            ),

          // MAIN CONTENT
          Expanded(
            child: _buildMainContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarContent() {
    return Container(
      color: AppTheme.primaryGreen,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  const Icon(Icons.recycling, color: Colors.white),
                  const SizedBox(width: 12),
                  const Text(
                    "SmartBin",
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildSidebarItem(0, Icons.dashboard_outlined, "Dashboard"),
                    _buildSidebarItem(1, Icons.people_outline, "Users"),
                    _buildSidebarItem(2, Icons.history, "Disposals"),
                    _buildSidebarItem(3, Icons.card_giftcard, "Rewards"),
                    _buildSidebarItem(4, Icons.emoji_events_outlined, "Badges"),
                    _buildSidebarItem(5, Icons.bar_chart, "Reports"),
                    _buildSidebarItem(6, Icons.delete_outline, "Bin Status"),
                  ],
                ),
              ),
            ),
            const Divider(color: Colors.white24, height: 1),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.white70),
              title: const Text("Logout", style: TextStyle(color: Colors.white70)),
              onTap: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('remember_me');
                await prefs.remove('is_admin_bypass');
                await _authService.signOut();
                if (mounted) Navigator.pushReplacementNamed(context, "/");
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboardOverview();
      case 1:
        return _buildUsersList();
      case 2:
        return _buildDisposalsList();
      case 6:
        return _buildBinsMonitoring();
      default:
        return Center(
          child: Text(
            "Section ${_selectedIndex + 1} coming soon",
            style: const TextStyle(fontSize: 20, color: Colors.grey),
          ),
        );
    }
  }

  Widget _buildBinsMonitoring() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Bin Status Monitoring", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text("Clear All Bins?"),
                          content: const Text("This will permanently remove all smart bin monitoring records from the database."),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
                            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete All", style: TextStyle(color: Colors.red))),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await _databaseService.deleteAllBins();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("All bins removed.")));
                        }
                      }
                    },
                    icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                    label: const Text("Clear All"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.withOpacity(0.1),
                      foregroundColor: Colors.red,
                      elevation: 0,
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => setState(() {}),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text("Refresh Status"),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _databaseService.getBinsStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return _buildAdminErrorState();
              }
              final bins = snapshot.data ?? [];
              if (bins.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(80.0),
                    child: Text("No bins detected in the system.", style: TextStyle(color: Colors.grey)),
                  ),
                );
              }

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 450,
                  mainAxisSpacing: 24,
                  crossAxisSpacing: 24,
                  childAspectRatio: 1.4,
                ),
                itemCount: bins.length,
                itemBuilder: (context, index) {
                  final bin = bins[index];
                  final fillLevel = (bin['fill_level'] ?? 0.0).toDouble();
                  final normalizedLevel = fillLevel / 100.0;
                  
                  Color statusColor = Colors.green;
                  String statusLabel = "HEALTHY";
                  if (fillLevel >= 80) {
                    statusColor = Colors.red;
                    statusLabel = "FULL";
                  } else if (fillLevel >= 50) {
                    statusColor = Colors.orange;
                    statusLabel = "WARNING";
                  }

                  return Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: statusColor.withOpacity(0.2), width: 2),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(bin['bin_name'] ?? "SmartBin ${index+1}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                Text(bin['location'] ?? "Main Campus", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: statusColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                statusLabel,
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Fill Level", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            Text("${fillLevel.toInt()}%", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: statusColor)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: normalizedLevel,
                            minHeight: 12,
                            backgroundColor: Colors.grey[100],
                            valueColor: AlwaysStoppedAnimation(statusColor),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Icon(Icons.access_time, size: 14, color: Colors.grey[400]),
                            const SizedBox(width: 6),
                            Text("Last ping: Just now", style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                            const Spacer(),
                            if (fillLevel >= 80)
                              const Text("Needs Collection", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 11)),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }


  Widget _buildDashboardOverview() {
    final now = DateTime.now();
    final dateStr = DateFormat('EEEE, MMMM d').format(now);

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _databaseService.getUsersStream(),
      builder: (context, userSnapshot) {
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: _databaseService.getDisposalHistoryStream(),
          builder: (context, historySnapshot) {
            if (userSnapshot.hasError || historySnapshot.hasError) {
              return _buildAdminErrorState();
            }

            final userCount = userSnapshot.hasData 
                ? userSnapshot.data!.where((u) => (u['role'] ?? "").toString().toLowerCase() != 'admin').length 
                : 0;
            double totalWeight = 0;
            int disposalsToday = 0;
            Set<String> activeUsersLast7Days = {};
            
            final today = DateTime.now();
            final sevenDaysAgo = today.subtract(const Duration(days: 7));

            // Filter history to exclude potential admin activity
            final historyData = (historySnapshot.data ?? []).where((item) {
              final userId = item['user_id']?.toString() ?? "";
              // We'd ideally need a map of IDs to roles here, or filter by a known admin ID pattern
              // For now, let's assume we want to hide anything that might be admin testing
              return !userId.toLowerCase().contains('admin'); 
            }).toList();

            if (historySnapshot.hasData) {
              for (var item in historyData) {
                totalWeight += (item['weight_kg'] ?? 0.0);
                
                final createdAt = item['created_at'] != null 
                    ? DateTime.parse(item['created_at']) 
                    : null;
                
                if (createdAt != null) {
                  if (createdAt.year == today.year && 
                      createdAt.month == today.month && 
                      createdAt.day == today.day) {
                    disposalsToday++;
                  }
                  if (createdAt.isAfter(sevenDaysAgo)) {
                    activeUsersLast7Days.add(item['user_id']?.toString() ?? "");
                  }
                }
              }
            }

            final screenWidth = MediaQuery.of(context).size.width;
            final isVeryWide = screenWidth > 1400;
            final isDesktop = screenWidth > 1100;

            return SingleChildScrollView(
              padding: EdgeInsets.all(screenWidth < 600 ? 20 : 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // RESPONSIVE HEADER
                  Wrap(
                    spacing: 20,
                    runSpacing: 20,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text("System Overview", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87)),
                              const SizedBox(width: 12),
                              _buildLiveIndicator(),
                            ],
                          ),
                          Text(
                            dateStr,
                            style: TextStyle(color: Colors.grey[600], fontSize: 16),
                          ),
                        ],
                      ),
                      Wrap(
                        spacing: 20,
                        runSpacing: 20,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text("Clear History?"),
                                  content: const Text("This will delete all disposal records and insert 2 basis examples."),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
                                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Reset Now", style: TextStyle(color: Colors.red))),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await _databaseService.resetDisposalHistory();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Database reset to Basis examples.")));
                                }
                              }
                            },
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text("Reset to Basis"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.withValues(alpha: 0.1),
                              foregroundColor: Colors.red,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.file_download_outlined),
                            label: const Text("Export Analytics"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppTheme.primaryGreen,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              side: BorderSide(color: AppTheme.primaryGreen.withValues(alpha: 0.2)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),

                  // REAL-TIME STATS GRID
                  GridView.count(
                    crossAxisCount: isVeryWide ? 4 : (isDesktop ? 2 : 1),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: isDesktop ? 2.2 : 3.0,
                    mainAxisSpacing: 24,
                    crossAxisSpacing: 24,
                    children: [
                      SummaryCard(title: "Total users", value: userCount.toString(), subtitle: "Registered students"),
                      SummaryCard(title: "Waste collected", value: "${(totalWeight / 1000).toStringAsFixed(2)} t", subtitle: "${totalWeight.toStringAsFixed(1)} kg total"),
                      SummaryCard(title: "Active users (7d)", value: activeUsersLast7Days.length.toString(), subtitle: "Unique recyclers"),
                      SummaryCard(title: "Disposals today", value: disposalsToday.toString(), subtitle: "recorded scans"),
                    ],
                  ),
                  
                  const SizedBox(height: 40),

                  // ADAPTIVE CHART & FEED
                  if (screenWidth > 1200)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // TREND CHART
                        Expanded(
                          flex: 2,
                          child: _buildSection(
                            "Disposal trend — last 7 days", 
                            WasteChartPlaceholder(disposalHistory: historyData),
                          ),
                        ),
                        const SizedBox(width: 24),
                        // LIVE FEED
                        Expanded(
                          flex: 1,
                          child: _buildLiveFeed(),
                        ),
                      ],
                    )
                  else
                    Column(
                      children: [
                        _buildSection(
                          "Disposal trend — last 7 days", 
                          WasteChartPlaceholder(disposalHistory: historyData),
                        ),
                        const SizedBox(height: 24),
                        _buildLiveFeed(),
                      ],
                    ),

                  const SizedBox(height: 40),

                  // BIN STATUS MONITORING
                  _buildSection(
                    "Real-time Bin Monitoring",
                    StreamBuilder<List<Map<String, dynamic>>>(
                      stream: _databaseService.getBinsStream(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) return const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("Bin Monitoring Offline")));
                        final bins = snapshot.data ?? [];
                        if (bins.isEmpty) return const Center(child: Text("No bins connected"));
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 400,
                            mainAxisSpacing: 20,
                            crossAxisSpacing: 20,
                            childAspectRatio: 1.5,
                          ),
                          itemCount: bins.length,
                          itemBuilder: (context, index) {
                            final bin = bins[index];
                            final fillLevel = (bin['fill_level'] ?? 0.0) / 100.0;
                            final isFull = fillLevel >= 0.8;
                            return Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: isFull ? Colors.red.withValues(alpha: 0.05) : Colors.green.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: isFull ? Colors.red.withValues(alpha: 0.3) : Colors.green.withValues(alpha: 0.3), width: 1.5),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(bin['bin_name'] ?? "Bin ${index+1}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isFull ? Colors.red : Colors.green,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          isFull ? "FULL" : "ONLINE",
                                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Spacer(),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(10),
                                          child: LinearProgressIndicator(
                                            value: fillLevel,
                                            minHeight: 10,
                                            backgroundColor: Colors.white,
                                            valueColor: AlwaysStoppedAnimation(isFull ? Colors.red : Colors.green),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text("${(fillLevel * 100).toInt()}%", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isFull ? Colors.red : Colors.green)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text("Capacity Level", style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 40),

                  // RECENT DISPOSALS
                  _buildSection(
                    "Recent Activity Log",
                    historyData.isEmpty 
                      ? const Padding(padding: EdgeInsets.all(20), child: Text("No records found"))
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minWidth: screenWidth < 1200 ? 800 : 0),
                            child: UserTable(records: historyData.take(15).toList()),
                          ),
                        ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildUsersList() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Registered Users", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _databaseService.getUsersStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Padding(padding: EdgeInsets.all(40), child: Text("No users registered yet.")));
              }
              
              // Filter out Admins from the list
              final userList = snapshot.data!.where((user) {
                final role = user['role']?.toString().toLowerCase() ?? "";
                final studentId = user['student_id']?.toString().toLowerCase() ?? "";
                return role != 'admin' && !studentId.contains('admin');
              }).toList();

              if (userList.isEmpty) {
                return const Center(child: Padding(padding: EdgeInsets.all(40), child: Text("No student users found.")));
              }

              return Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.grey.withOpacity(0.1)),
                ),
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text("NAME")),
                    DataColumn(label: Text("STUDENT ID")),
                    DataColumn(label: Text("POINTS")),
                  ],
                  rows: userList.map((user) => DataRow(cells: [
                    DataCell(Text(user['full_name'] ?? "Unknown")),
                    DataCell(Text(user['student_id'] ?? "N/A")),
                    DataCell(Text("${user['total_points'] ?? 0}")),
                  ])).toList(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDisposalsList() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Disposal Records", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          _buildSection(
            "Complete History",
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: _databaseService.getDisposalHistoryStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Padding(padding: EdgeInsets.all(40), child: Text("No disposal history found.")));
                }
                
                final records = List<Map<String, dynamic>>.from(snapshot.data!).where((r) {
                  final userId = r['user_id']?.toString() ?? "";
                  return !userId.toLowerCase().contains('admin');
                }).toList();
                
                records.sort((a, b) => (b['created_at'] ?? "").compareTo(a['created_at'] ?? ""));
                
                if (records.isEmpty) return const Center(child: Text("No student records."));
                return UserTable(records: records);
              },
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildLiveFeed() {
    return _buildSection(
      "🔴 Live Activity Feed",
      SizedBox(
        height: 300,
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: _databaseService.getRecentActivityStream(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return const Center(child: Text("Offline Feed"));
            final feed = (snapshot.data ?? []).where((item) {
              final userId = item['user_id']?.toString() ?? "";
              return !userId.toLowerCase().contains('admin');
            }).toList();
            
            if (feed.isEmpty) return const Center(child: Text("Waiting for activity..."));
            return ListView.separated(
              itemCount: feed.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                final item = feed[index];
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.flash_on, size: 16)),
                  title: Text(item['waste_type'] ?? "Disposal"),
                  subtitle: Text(DateFormat('h:mm:ss a').format(DateTime.parse(item['created_at']))),
                  trailing: Text("+${item['points_earned']} pts", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildAdminErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 24),
          const Text("Connection error", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const Text("Please check your internet connection."),
          const SizedBox(height: 32),
          ElevatedButton(onPressed: () => setState(() {}), child: const Text("Reconnect")),
        ],
      ),
    );
  }


  Widget _buildLiveIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          const Text("LIVE", style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(int index, IconData icon, String title) {
    final isSelected = _selectedIndex == index;
    return ListTile(
      leading: Icon(icon, color: isSelected ? Colors.white : Colors.white70),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.white70,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onTap: () => setState(() => _selectedIndex = index),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
    );
  }

  Widget _buildSection(String title, Widget content) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 24),
          content,
        ],
      ),
    );
  }
}
