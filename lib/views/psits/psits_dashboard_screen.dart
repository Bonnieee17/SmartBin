import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../models/voucher_model.dart';
import '../scanner/scanner_screen.dart';

class PsitsDashboardScreen extends StatefulWidget {
  const PsitsDashboardScreen({super.key});

  @override
  State<PsitsDashboardScreen> createState() => _PsitsDashboardScreenState();
}

class PsitsQrScannerScreen extends ScannerScreen {
  const PsitsQrScannerScreen({super.key});
}

class _PsitsDashboardScreenState extends State<PsitsDashboardScreen> {
  final _databaseService = DatabaseService();
  final _authService = AuthService();
  bool _isLoading = true;
  List<VoucherModel> _vouchers = [];
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _checkAccessAndLoadVouchers();
  }

  Future<void> _checkAccessAndLoadVouchers() async {
    final user = _authService.currentUser;
    final prefs = await SharedPreferences.getInstance();
    final isAdminBypass = prefs.getBool('is_admin_bypass') ?? false;
    final isAdminLoggedIn = prefs.getBool('is_admin_logged_in') ?? false;

    final role = user?.userMetadata?['role']?.toString().toLowerCase() ?? '';
    final email = user?.email?.toLowerCase() ?? '';
    final isPsitsOrAdmin = isAdminBypass || isAdminLoggedIn || role == 'admin' || role == 'psits' || email.contains('admin') || email.contains('psits');

    if (!isPsitsOrAdmin) {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text("Access Denied"),
            content: const Text("You are not authorized to access the PSITS Dashboard."),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: const Text("OK"),
              ),
            ],
          ),
        );
      }
      return;
    }

    try {
      final vouchers = await _databaseService.getAllVouchers();
      if (mounted) {
        setState(() {
          _vouchers = vouchers;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final filteredVouchers = _vouchers.where((v) {
      return v.code.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          v.rewardName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (v.userName ?? "").toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("PSITS Dashboard"),
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header & Quick Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "PSITS Office Management",
                        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "Scan SmartBin vouchers and view redemption history.",
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const PsitsQrScannerScreen()),
                      ).then((_) => _checkAccessAndLoadVouchers());
                    },
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text("Scan SmartBin Voucher"),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Search Bar for Voucher History
              TextField(
                decoration: InputDecoration(
                  labelText: "Search vouchers by code, reward, or student name",
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: theme.cardColor,
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
              const SizedBox(height: 24),

              // Voucher History Section Title
              Row(
                children: [
                  const Icon(Icons.history, color: AppTheme.primaryGreen),
                  const SizedBox(width: 8),
                  Text(
                    "Voucher History (${filteredVouchers.length})",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Voucher History List
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : filteredVouchers.isEmpty
                        ? const Center(
                            child: Text(
                              "No vouchers found.",
                              style: TextStyle(color: Colors.grey, fontSize: 16),
                            ),
                          )
                        : ListView.builder(
                            itemCount: filteredVouchers.length,
                            itemBuilder: (context, index) {
                              final v = filteredVouchers[index];
                              final isClaimed = v.isClaimed;
                              final isExpired = v.isExpired;

                              Color badgeColor = Colors.green;
                              String badgeText = "Available";
                              if (isClaimed) {
                                badgeColor = Colors.blue;
                                badgeText = "Redeemed";
                              } else if (isExpired) {
                                badgeColor = Colors.red;
                                badgeText = "Expired";
                              }

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                color: theme.cardColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(color: badgeColor.withValues(alpha: 0.3)),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.all(16),
                                  leading: CircleAvatar(
                                    backgroundColor: badgeColor.withValues(alpha: 0.15),
                                    child: Icon(
                                      isClaimed ? Icons.check_circle : (isExpired ? Icons.cancel : Icons.confirmation_number),
                                      color: badgeColor,
                                    ),
                                  ),
                                  title: Text(
                                    v.rewardName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Text("Code: ${v.code}", style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
                                      Text("Cost: ${v.pointsCost} pts | Created: ${v.createdAt.toLocal().toString().split('.').first}", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                    ],
                                  ),
                                  trailing: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: badgeColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      badgeText,
                                      style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ),
                                ),
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
