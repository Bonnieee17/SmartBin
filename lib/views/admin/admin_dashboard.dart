import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import 'widgets/summary_card.dart';
import 'widgets/waste_chart_placeholder.dart';
import 'widgets/user_table.dart';
import 'widgets/student_table.dart';
import 'package:qr_flutter/qr_flutter.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final _databaseService = DatabaseService();
  final _authService = AuthService();

  int _selectedIndex = 0;

  final _productionUrlController = TextEditingController(text: AppConstants.baseUrl);

  // Voucher
  final _voucherNameController =
  TextEditingController(text: "Printing Credit");
  final _voucherPointsController =
  TextEditingController(text: "100");

  String _qrData = "voucher:Printing Credit:100";

  // Hardware simulator
  String _simQrData = "";
  String _simStatus = "Waiting for item...";
  Color _simColor = Colors.grey;

  @override
  void initState() {
    super.initState();
    _checkAdminAccess();
    _loadSettings();
  }

  Future<void> _checkAdminAccess() async {
    final user = _authService.currentUser;
    if (user == null || user.userMetadata?['role'] != 'admin') {
      // Check if bypass is active
      final prefs = await SharedPreferences.getInstance();
      final isAdminBypass = prefs.getBool('is_admin_bypass') ?? false;
      
      if (!isAdminBypass) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, "/");
        }
      }
    }
  }

  @override
  void dispose() {
    _productionUrlController.dispose();
    _voucherNameController.dispose();
    _voucherPointsController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    if (!mounted) return;

    setState(() {
      _productionUrlController.text = AppConstants.baseUrl;
    });

    _updateQr();
  }

  Future<void> _saveSettings() async {
    // URL is now permanent/hardcoded, no need to save to local storage
  }

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

      drawer: useDrawer
          ? Drawer(
        child: _buildSidebarContent(),
      )
          : null,

      body: Row(
        children: [
          if (!useDrawer)
            SizedBox(
              width: 150,
              child: _buildSidebarContent(),
            ),

          Expanded(
            child: _buildMainContent(),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SIDEBAR
  // ============================================================

  Widget _buildSidebarContent() {
    return Container(
      color: AppTheme.primaryGreen,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),

            Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 16),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(
                      Icons.recycling,
                      color: Colors.white,
                    ),
                    SizedBox(width: 12),
                    Text(
                      "SmartBin",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 40),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildSidebarItem(
                      0,
                      Icons.dashboard_outlined,
                      "Dashboard",
                    ),
                    _buildSidebarItem(
                      1,
                      Icons.people_outline,
                      "Users",
                    ),
                    _buildSidebarItem(
                      2,
                      Icons.history,
                      "Disposals",
                    ),
                    _buildSidebarItem(
                      3,
                      Icons.card_giftcard,
                      "Rewards",
                    ),
                    _buildSidebarItem(
                      4,
                      Icons.emoji_events_outlined,
                      "Badges",
                    ),
                    _buildSidebarItem(
                      5,
                      Icons.bar_chart,
                      "Reports",
                    ),
                    _buildSidebarItem(
                      6,
                      Icons.delete_outline,
                      "Bin Status",
                    ),
                    _buildSidebarItem(
                      7,
                      Icons.qr_code_2_outlined,
                      "Vouchers",
                    ),
                    _buildSidebarItem(
                      8,
                      Icons.terminal_outlined,
                      "Hardware Sim",
                    ),
                  ],
                ),
              ),
            ),

            const Divider(
              color: Colors.white24,
              height: 1,
            ),

            ListTile(
              leading: const Icon(
                Icons.logout,
                color: Colors.white70,
              ),
              title: const Text(
                "Logout",
                style: TextStyle(
                  color: Colors.white70,
                ),
              ),
              onTap: () async {
                final prefs =
                await SharedPreferences.getInstance();

                await prefs.remove('remember_me');
                await prefs.remove('is_admin_bypass');

                await _authService.signOut();

                if (!mounted) return;

                Navigator.pushReplacementNamed(
                  context,
                  "/",
                );
              },
            ),

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // MAIN CONTENT
  // ============================================================

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

      case 7:
        return _buildVoucherGenerator();

      case 8:
        return _buildHardwareSimulator();

      default:
        return Center(
          child: Text(
            "Section ${_selectedIndex + 1} coming soon",
            style: const TextStyle(
              fontSize: 20,
              color: Colors.grey,
            ),
          ),
        );
    }
  }

  // ============================================================
  // VOUCHER GENERATOR
  // ============================================================

  Widget _buildVoucherGenerator() {
    final screenWidth =
        MediaQuery.of(context).size.width;

    final isMobile = screenWidth < 600;

    return SingleChildScrollView(
      padding:
      EdgeInsets.all(isMobile ? 20 : 40),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          const Text(
            "Voucher Generator",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            "Create and display QR codes for printing vouchers.",
            style: TextStyle(
              color: Colors.grey,
            ),
          ),

          const SizedBox(height: 40),

          if (screenWidth > 900)
            Row(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildVoucherInputs(),
                ),

                const SizedBox(width: 48),

                Expanded(
                  child: _buildVoucherDisplay(),
                ),
              ],
            )
          else
            Column(
              children: [
                _buildVoucherInputs(),
                const SizedBox(height: 40),
                _buildVoucherDisplay(),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildVoucherInputs() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(28),
        border: Border.all(
          color: Colors.grey.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          const Text(
            "Voucher Details",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),

          const SizedBox(height: 24),

          TextField(
            controller: _voucherNameController,
            decoration:
            const InputDecoration(
              labelText: "Voucher Name",
              hintText: "e.g. Printing Credit",
            ),
            onChanged: (_) => _updateQr(),
          ),

          const SizedBox(height: 20),

          TextField(
            controller: _voucherPointsController,
            keyboardType:
            TextInputType.number,
            decoration:
            const InputDecoration(
              labelText: "Points Value",
              hintText: "Max 1000",
            ),
            onChanged: (_) => _updateQr(),
          ),

          const SizedBox(height: 12),

          const Text(
            "Note: 10 Points = ₱1.00 Peso. Maximum 1000 points per voucher.",
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  void _updateQr() {
    int pts =
        int.tryParse(
          _voucherPointsController.text,
        ) ??
            0;

    if (pts > 1000) {
      pts = 1000;
    }

    final baseUrl = _productionUrlController.text.trim();

    if (!mounted) return;

    setState(() {
      _qrData =
      "${AppConstants.claimPage}?voucher=${Uri.encodeComponent(_voucherNameController.text.trim())}&cost=$pts";
    });
  }

  Widget _buildVoucherDisplay() {
    int pts =
        int.tryParse(
          _voucherPointsController.text,
        ) ??
            0;

    if (pts > 1000) {
      pts = 1000;
    }

    final pesos = pts / 10.0;

    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen,
        borderRadius:
        BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryGreen
                .withOpacity(0.3),
            blurRadius: 20,
            offset:
            const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding:
            const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
              BorderRadius.circular(20),
            ),
            child: QrImageView(
              data: _qrData,
              version: QrVersions.auto,
              size: 240,
              gapless: false,
            ),
          ),

          const SizedBox(height: 32),

          Text(
            _voucherNameController.text.isEmpty
                ? "Untitled Voucher"
                : _voucherNameController.text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            "VALUE: ₱${pesos.toStringAsFixed(2)}",
            style: const TextStyle(
              color: AppTheme.secondarySage,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(height: 8),

          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _qrData,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 10,
              ),
            ),
          ),

          const SizedBox(height: 4),

          Text(
            "Cost: $pts Eco Points",
            style: TextStyle(
              color:
              Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HARDWARE SIMULATOR
  // ============================================================

  Widget _buildHardwareSimulator() {
    final screenWidth =
        MediaQuery.of(context).size.width;

    final isMobile = screenWidth < 600;

    return SingleChildScrollView(
      padding:
      EdgeInsets.all(isMobile ? 20 : 40),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          const Text(
            "SmartBin Hardware Simulator",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),

          const Text(
            "Use this to mimic the Trashcan's LCD screen.",
            style: TextStyle(
              color: Colors.grey,
            ),
          ),

          const SizedBox(height: 40),

          if (screenWidth > 1100)
            Row(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      _buildAppConfig(),
                      const SizedBox(height: 24),
                      _buildSimControls(),
                    ],
                  ),
                ),

                const SizedBox(width: 48),

                Expanded(
                  child: _buildSimLcd(),
                ),
              ],
            )
          else
            Column(
              children: [
                _buildAppConfig(),
                const SizedBox(height: 24),
                _buildSimControls(),
                const SizedBox(height: 40),
                _buildSimLcd(),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildAppConfig() {
    const downloadUrl = AppConstants.downloadPage;

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "App Configuration",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 24),
          const Text(
            "SmartBin App Link (Public)",
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue),
          ),
          const SizedBox(height: 8),
          const Text(
            "Scan this QR code to download the SmartBin app on any student device.",
            style: TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 24),
          Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey[100]!),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, spreadRadius: 2),
                ],
              ),
              child: QrImageView(
                data: downloadUrl,
                version: QrVersions.auto,
                size: 180,
                embeddedImage: const AssetImage('assets/images/logo.png'),
                embeddedImageStyle: const QrEmbeddedImageStyle(size: Size(40, 40)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: SelectableText(
              downloadUrl,
              style: const TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimControls() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(28),
        border: Border.all(
          color: Colors.grey.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          const Text(
            "Trashcan Action",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),

          const SizedBox(height: 24),

          const Text(
            "Drop an item to generate a dynamic QR code for the student to scan:",
            style: TextStyle(
              fontSize: 13,
              color: Colors.black54,
            ),
          ),

          const SizedBox(height: 24),

          _buildSimBtn(
            "Drop Plastic Bottle",
            "Plastic Bottle",
            10,
            Icons.local_drink_outlined,
            Colors.blue,
          ),

          const SizedBox(height: 12),

          _buildSimBtn(
            "Drop Metal Can",
            "Metal Can",
            15,
            Icons.inventory_2_outlined,
            Colors.orange,
          ),

          const SizedBox(height: 12),

          _buildSimBtn(
            "Drop Paper/Cardboard",
            "Paper",
            5,
            Icons.description_outlined,
            Colors.green,
          ),

          const SizedBox(height: 32),

          OutlinedButton(
            onPressed: () {
              setState(() {
                _simQrData = "";
                _simStatus =
                "Waiting for item...";
                _simColor = Colors.grey;
              });
              
              _databaseService.updateBinStatus(
                binId: "BIN-001",
                status: _simStatus,
                qrData: "",
                color: Colors.grey.value.toRadixString(16),
              );
            },
            child: const Text(
              "Reset LCD",
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimBtn(
      String label,
      String type,
      int pts,
      IconData icon,
      Color color,
      ) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          final baseUrl = _productionUrlController.text.trim();

          setState(() {
            _simStatus =
            "Item Detected: $type";

            _simColor = color;

            _simQrData =
            "${AppConstants.claimPage}?type=${Uri.encodeComponent(type)}&pts=$pts&bin=BIN-001";
          });
          
          // Sync to Database for remote simulator
          _databaseService.updateBinStatus(
            binId: "BIN-001",
            status: _simStatus,
            qrData: _simQrData,
            color: color.value.toRadixString(16),
          );
        },
        icon: Icon(
          icon,
          size: 18,
        ),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor:
          color.withOpacity(0.1),
          foregroundColor: color,
          elevation: 0,
          padding:
          const EdgeInsets.symmetric(
            vertical: 16,
          ),
          shape:
          RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildSimLcd() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius:
        BorderRadius.circular(32),
        border: Border.all(
          color: Colors.grey[800]!,
          width: 4,
        ),
        boxShadow: [
          BoxShadow(
            color:
            Colors.black.withOpacity(0.5),
            blurRadius: 20,
            offset:
            const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            _simStatus.toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _simColor,
              fontWeight: FontWeight.bold,
              fontSize: 16,
              letterSpacing: 2,
            ),
          ),

          const SizedBox(height: 32),

          if (_simQrData.isNotEmpty)
            Container(
              padding:
              const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                BorderRadius.circular(20),
              ),
              child: QrImageView(
                data: _simQrData,
                version: QrVersions.auto,
                size: 240,
                embeddedImage: const AssetImage('assets/images/logo.png'),
                embeddedImageStyle: const QrEmbeddedImageStyle(
                  size: Size(50, 50),
                ),
              ),
            )
          else
            Container(
              height: 272,
              width: 272,
              decoration:
              BoxDecoration(
                color:
                Colors.white.withOpacity(0.05),
                borderRadius:
                BorderRadius.circular(20),
              ),
              child: const Center(
                child: Icon(
                  Icons.qr_code_scanner,
                  color: Colors.white24,
                  size: 80,
                ),
              ),
            ),

          const SizedBox(height: 32),

          const Text(
            "SMARTBIN OS v2.0",
            style: TextStyle(
              color: Colors.white24,
              fontSize: 10,
              letterSpacing: 1,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            "SCAN TO REDEEM POINTS",
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BIN MONITORING
  // ============================================================

  Widget _buildBinsMonitoring() {
    final screenWidth =
        MediaQuery.of(context).size.width;

    final isMobile = screenWidth < 600;

    return SingleChildScrollView(
      padding:
      EdgeInsets.all(isMobile ? 20 : 40),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 20,
            runSpacing: 20,
            alignment:
            WrapAlignment.spaceBetween,
            crossAxisAlignment:
            WrapCrossAlignment.center,
            children: [
              const Text(
                "Bin Status Monitoring",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),

              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ElevatedButton.icon(
                    onPressed: () async {
                      final confirm =
                      await showDialog<bool>(
                        context: context,
                        builder:
                            (context) =>
                            AlertDialog(
                              title: const Text(
                                "Clear All Bins?",
                              ),
                              content:
                              const Text(
                                "This will permanently remove all smart bin monitoring records from the database.",
                              ),
                              actions: [
                                TextButton(
                                  onPressed:
                                      () =>
                                      Navigator.pop(
                                        context,
                                        false,
                                      ),
                                  child:
                                  const Text(
                                    "Cancel",
                                  ),
                                ),
                                TextButton(
                                  onPressed:
                                      () =>
                                      Navigator.pop(
                                        context,
                                        true,
                                      ),
                                  child:
                                  const Text(
                                    "Delete All",
                                    style:
                                    TextStyle(
                                      color:
                                      Colors.red,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                      );

                      if (confirm == true) {
                        await _databaseService
                            .deleteAllBins();

                        if (!mounted) return;

                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(
                          const SnackBar(
                            content: Text(
                              "All bins removed.",
                            ),
                          ),
                        );
                      }
                    },
                    icon: const Icon(
                      Icons.delete_sweep_outlined,
                      size: 18,
                    ),
                    label: const Text(
                      "Clear All",
                    ),
                    style:
                    ElevatedButton.styleFrom(
                      backgroundColor:
                      Colors.red
                          .withOpacity(
                        0.1,
                      ),
                      foregroundColor:
                      Colors.red,
                      elevation: 0,
                    ),
                  ),

                  ElevatedButton.icon(
                    onPressed: () =>
                        setState(() {}),
                    icon: const Icon(
                      Icons.refresh,
                      size: 18,
                    ),
                    label: const Text(
                      "Refresh Status",
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 32),

          StreamBuilder<
              List<Map<String, dynamic>>>(
            stream:
            _databaseService
                .getBinsStream(),
            builder:
                (context, snapshot) {
              if (snapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(
                  child:
                  CircularProgressIndicator(),
                );
              }

              if (snapshot.hasError) {
                return _buildAdminErrorState();
              }

              final bins =
                  snapshot.data ?? [];

              if (bins.isEmpty) {
                return const Center(
                  child: Padding(
                    padding:
                    EdgeInsets.all(80),
                    child: Text(
                      "No bins detected in the system.",
                      style: TextStyle(
                        color: Colors.grey,
                      ),
                    ),
                  ),
                );
              }

              return GridView.builder(
                shrinkWrap: true,
                physics:
                const NeverScrollableScrollPhysics(),
                gridDelegate:
                SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent:
                  screenWidth > 600
                      ? 450
                      : screenWidth,
                  mainAxisSpacing: 24,
                  crossAxisSpacing: 24,
                  childAspectRatio:
                  screenWidth > 1200
                      ? 1.4
                      : (screenWidth > 600
                      ? 1.6
                      : 1.2),
                ),
                itemCount: bins.length,
                itemBuilder:
                    (context, index) {
                  final bin =
                  bins[index];

                  final fillLevel =
                  (bin['fill_level'] ??
                      0.0)
                      .toDouble();

                  final normalizedLevel =
                  (fillLevel / 100.0)
                      .clamp(0.0, 1.0);

                  Color statusColor =
                      Colors.green;

                  String statusLabel =
                      "HEALTHY";

                  if (fillLevel >= 80) {
                    statusColor =
                        Colors.red;
                    statusLabel = "FULL";
                  } else if (fillLevel >=
                      50) {
                    statusColor =
                        Colors.orange;
                    statusLabel =
                    "WARNING";
                  }

                  return Container(
                    padding: EdgeInsets.all(
                      screenWidth > 600
                          ? 28
                          : 20,
                    ),
                    decoration:
                    BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                      BorderRadius
                          .circular(
                        28,
                      ),
                      border: Border.all(
                        color: statusColor
                            .withOpacity(
                          0.2,
                        ),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                      children: [
                        Row(
                          mainAxisAlignment:
                          MainAxisAlignment
                              .spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                                children: [
                                  Text(
                                    bin['bin_name'] ??
                                        "SmartBin ${index + 1}",
                                    style:
                                    TextStyle(
                                      fontWeight:
                                      FontWeight
                                          .bold,
                                      fontSize:
                                      screenWidth >
                                          600
                                          ? 18
                                          : 16,
                                    ),
                                    overflow:
                                    TextOverflow
                                        .ellipsis,
                                  ),
                                  Text(
                                    bin['location'] ??
                                        "Main Campus",
                                    style:
                                    TextStyle(
                                      color:
                                      Colors.grey[
                                      600],
                                      fontSize:
                                      12,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            Container(
                              padding:
                              const EdgeInsets
                                  .symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration:
                              BoxDecoration(
                                color:
                                statusColor,
                                borderRadius:
                                BorderRadius
                                    .circular(
                                  8,
                                ),
                              ),
                              child: Text(
                                statusLabel,
                                style:
                                const TextStyle(
                                  color:
                                  Colors.white,
                                  fontSize: 10,
                                  fontWeight:
                                  FontWeight
                                      .bold,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const Spacer(),

                        Row(
                          mainAxisAlignment:
                          MainAxisAlignment
                              .spaceBetween,
                          children: [
                            const Text(
                              "Fill Level",
                              style:
                              TextStyle(
                                fontWeight:
                                FontWeight
                                    .w600,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              "${fillLevel.toInt()}%",
                              style:
                              TextStyle(
                                fontSize: 16,
                                fontWeight:
                                FontWeight
                                    .bold,
                                color:
                                statusColor,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(
                            height: 12),

                        ClipRRect(
                          borderRadius:
                          BorderRadius
                              .circular(
                            10,
                          ),
                          child:
                          LinearProgressIndicator(
                            value:
                            normalizedLevel,
                            minHeight: 12,
                            backgroundColor:
                            Colors.grey[
                            100],
                            valueColor:
                            AlwaysStoppedAnimation<
                                Color>(
                              statusColor,
                            ),
                          ),
                        ),

                        const SizedBox(
                            height: 16),

                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 14,
                              color:
                              Colors.grey[
                              400],
                            ),
                            const SizedBox(
                                width: 6),
                            const Expanded(
                              child: Text(
                                "Last ping: Just now",
                                style:
                                TextStyle(
                                  fontSize:
                                  11,
                                  color:
                                  Colors.grey,
                                ),
                              ),
                            ),
                            if (fillLevel >=
                                80)
                              const Text(
                                "Needs Collection",
                                style:
                                TextStyle(
                                  color:
                                  Colors.red,
                                  fontWeight:
                                  FontWeight
                                      .bold,
                                  fontSize:
                                  11,
                                ),
                              ),
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

  // ============================================================
  // DASHBOARD OVERVIEW
  // ============================================================

  Widget _buildDashboardOverview() {
    final now = DateTime.now();

    final dateStr =
    DateFormat('EEEE, MMMM d')
        .format(now);

    return StreamBuilder<
        List<Map<String, dynamic>>>(
      stream:
      _databaseService.getUsersStream(),
      builder:
          (context, userSnapshot) {
        return StreamBuilder<
            List<Map<String, dynamic>>>(
          stream: _databaseService
              .getDisposalHistoryStream(),
          builder:
              (context, historySnapshot) {
            if (userSnapshot.hasError ||
                historySnapshot.hasError) {
              return _buildAdminErrorState();
            }

            final userCount =
            userSnapshot.hasData
                ? userSnapshot.data!
                .where(
                  (u) =>
              (u['role'] ??
                  "")
                  .toString()
                  .toLowerCase() !=
                  'admin',
            )
                .length
                : 0;

            double totalWeight = 0;

            int disposalsToday = 0;

            Set<String>
            activeUsersLast7Days =
            {};

            final today =
            DateTime.now();

            final sevenDaysAgo =
            today.subtract(
              const Duration(
                days: 7,
              ),
            );

            final historyData =
            (historySnapshot.data ??
                [])
                .where((item) {
              final userId =
                  item['user_id']
                      ?.toString() ??
                      "";

              return !userId
                  .toLowerCase()
                  .contains(
                'admin',
              );
            }).toList();

            for (final item
            in historyData) {
              totalWeight +=
                  (item['weight_kg'] ??
                      0.0)
                      .toDouble();

              DateTime? createdAt;

              if (item['created_at'] !=
                  null) {
                createdAt =
                    DateTime.tryParse(
                      item['created_at']
                          .toString(),
                    );
              }

              if (createdAt != null) {
                if (createdAt.year ==
                    today.year &&
                    createdAt.month ==
                        today.month &&
                    createdAt.day ==
                        today.day) {
                  disposalsToday++;
                }

                if (createdAt.isAfter(
                    sevenDaysAgo)) {
                  activeUsersLast7Days.add(
                    item['user_id']
                        ?.toString() ??
                        "",
                  );
                }
              }
            }

            final screenWidth =
                MediaQuery.of(context)
                    .size
                    .width;

            final isMobile =
                screenWidth < 600;

            return SingleChildScrollView(
              padding:
              EdgeInsets.all(
                isMobile ? 20 : 40,
              ),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment
                    .start,
                children: [
                  Wrap(
                    spacing: 20,
                    runSpacing: 20,
                    alignment:
                    WrapAlignment
                        .spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                "System Overview",
                                style:
                                TextStyle(
                                  fontSize:
                                  28,
                                  fontWeight:
                                  FontWeight
                                      .bold,
                                  color: Colors
                                      .black87,
                                ),
                              ),
                              const SizedBox(
                                  width: 12),
                              _buildLiveIndicator(),
                            ],
                          ),

                          Text(
                            dateStr,
                            style:
                            TextStyle(
                              color:
                              Colors.grey[
                              600],
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),

                      Wrap(
                        spacing: 20,
                        runSpacing: 20,
                        children: [
                          ElevatedButton
                              .icon(
                            onPressed:
                                () async {
                              final confirm =
                              await showDialog<
                                  bool>(
                                context:
                                context,
                                builder:
                                    (context) =>
                                    AlertDialog(
                                      title:
                                      const Text(
                                        "Clear History?",
                                      ),
                                      content:
                                      const Text(
                                        "This will delete all disposal records and insert 2 basis examples.",
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed:
                                              () =>
                                              Navigator.pop(
                                                context,
                                                false,
                                              ),
                                          child:
                                          const Text(
                                            "Cancel",
                                          ),
                                        ),
                                        TextButton(
                                          onPressed:
                                              () =>
                                              Navigator.pop(
                                                context,
                                                true,
                                              ),
                                          child:
                                          const Text(
                                            "Reset Now",
                                            style:
                                            TextStyle(
                                              color:
                                              Colors.red,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                              );

                              if (confirm ==
                                  true) {
                                await _databaseService
                                    .resetDisposalHistory();

                                if (!mounted)
                                  return;

                                ScaffoldMessenger
                                    .of(
                                  context,
                                ).showSnackBar(
                                  const SnackBar(
                                    content:
                                    Text(
                                      "Database reset to Basis examples.",
                                    ),
                                  ),
                                );
                              }
                            },
                            icon:
                            const Icon(
                              Icons.refresh,
                              size: 18,
                            ),
                            label:
                            const Text(
                              "Reset to Basis",
                            ),
                            style:
                            ElevatedButton
                                .styleFrom(
                              backgroundColor:
                              Colors.red
                                  .withOpacity(
                                0.1,
                              ),
                              foregroundColor:
                              Colors.red,
                              elevation: 0,
                            ),
                          ),

                          ElevatedButton
                              .icon(
                            onPressed: () {},
                            icon:
                            const Icon(
                              Icons
                                  .file_download_outlined,
                            ),
                            label:
                            const Text(
                              "Export Analytics",
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(
                      height: 40),

                  GridView.count(
                    crossAxisCount:
                    screenWidth > 1400
                        ? 4
                        : (screenWidth >
                        900
                        ? 2
                        : 1),
                    shrinkWrap: true,
                    physics:
                    const NeverScrollableScrollPhysics(),
                    childAspectRatio:
                    screenWidth > 600
                        ? 2.2
                        : 3.2,
                    mainAxisSpacing: 24,
                    crossAxisSpacing: 24,
                    children: [
                      SummaryCard(
                        title:
                        "Total users",
                        value:
                        userCount
                            .toString(),
                        subtitle:
                        "Registered students",
                      ),

                      SummaryCard(
                        title:
                        "Waste collected",
                        value:
                        "${(totalWeight / 1000).toStringAsFixed(2)} t",
                        subtitle:
                        "${totalWeight.toStringAsFixed(1)} kg total",
                      ),

                      SummaryCard(
                        title:
                        "Active users (7d)",
                        value:
                        activeUsersLast7Days
                            .length
                            .toString(),
                        subtitle:
                        "Unique recyclers",
                      ),

                      SummaryCard(
                        title:
                        "Disposals today",
                        value:
                        disposalsToday
                            .toString(),
                        subtitle:
                        "recorded scans",
                      ),
                    ],
                  ),

                  const SizedBox(
                      height: 40),

                  if (screenWidth > 1200)
                    Row(
                      crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                      children: [
                        Expanded(
                          flex: 2,
                          child:
                          _buildSection(
                            "Disposal trend — last 7 days",
                            WasteChartPlaceholder(
                              disposalHistory:
                              historyData,
                            ),
                          ),
                        ),

                        const SizedBox(
                            width: 24),

                        Expanded(
                          child:
                          _buildLiveFeed(),
                        ),
                      ],
                    )
                  else
                    Column(
                      children: [
                        _buildSection(
                          "Disposal trend — last 7 days",
                          WasteChartPlaceholder(
                            disposalHistory:
                            historyData,
                          ),
                        ),

                        const SizedBox(
                            height: 24),

                        _buildLiveFeed(),
                      ],
                    ),

                  const SizedBox(
                      height: 40),

                  _buildSection(
                    "Real-time Bin Monitoring",
                    StreamBuilder<
                        List<
                            Map<String,
                                dynamic>>>(
                      stream:
                      _databaseService
                          .getBinsStream(),
                      builder:
                          (context,
                          snapshot) {
                        if (snapshot
                            .hasError) {
                          return const Center(
                            child: Padding(
                              padding:
                              EdgeInsets.all(
                                20,
                              ),
                              child: Text(
                                "Bin Monitoring Offline",
                              ),
                            ),
                          );
                        }

                        final bins =
                            snapshot.data ??
                                [];

                        if (bins.isEmpty) {
                          return const Center(
                            child: Text(
                              "No bins connected",
                            ),
                          );
                        }

                        return GridView
                            .builder(
                          shrinkWrap:
                          true,
                          physics:
                          const NeverScrollableScrollPhysics(),
                          gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent:
                            400,
                            mainAxisSpacing:
                            20,
                            crossAxisSpacing:
                            20,
                            childAspectRatio:
                            1.5,
                          ),
                          itemCount:
                          bins.length,
                          itemBuilder:
                              (context,
                              index) {
                            final bin =
                            bins[index];

                            final fillLevel =
                                ((bin['fill_level'] ??
                                    0.0)
                                    .toDouble()) /
                                    100.0;

                            final isFull =
                                fillLevel >=
                                    0.8;

                            return Container(
                              padding:
                              const EdgeInsets
                                  .all(
                                20,
                              ),
                              decoration:
                              BoxDecoration(
                                color: isFull
                                    ? Colors.red
                                    .withOpacity(
                                  0.05,
                                )
                                    : Colors.green
                                    .withOpacity(
                                  0.05,
                                ),
                                borderRadius:
                                BorderRadius
                                    .circular(
                                  20,
                                ),
                                border:
                                Border.all(
                                  color: isFull
                                      ? Colors.red
                                      .withOpacity(
                                    0.3,
                                  )
                                      : Colors.green
                                      .withOpacity(
                                    0.3,
                                  ),
                                  width: 1.5,
                                ),
                              ),
                              child:
                              Column(
                                crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                    MainAxisAlignment
                                        .spaceBetween,
                                    children: [
                                      Expanded(
                                        child:
                                        Text(
                                          bin['bin_name'] ??
                                              "Bin ${index + 1}",
                                          style:
                                          const TextStyle(
                                            fontWeight:
                                            FontWeight.bold,
                                            fontSize:
                                            16,
                                          ),
                                          overflow:
                                          TextOverflow.ellipsis,
                                        ),
                                      ),

                                      Container(
                                        padding:
                                        const EdgeInsets
                                            .symmetric(
                                          horizontal:
                                          8,
                                          vertical:
                                          4,
                                        ),
                                        decoration:
                                        BoxDecoration(
                                          color:
                                          isFull
                                              ? Colors.red
                                              : Colors.green,
                                          borderRadius:
                                          BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child:
                                        Text(
                                          isFull
                                              ? "FULL"
                                              : "ONLINE",
                                          style:
                                          const TextStyle(
                                            color:
                                            Colors.white,
                                            fontSize:
                                            10,
                                            fontWeight:
                                            FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  const Spacer(),

                                  Row(
                                    children: [
                                      Expanded(
                                        child:
                                        ClipRRect(
                                          borderRadius:
                                          BorderRadius.circular(
                                            10,
                                          ),
                                          child:
                                          LinearProgressIndicator(
                                            value:
                                            fillLevel.clamp(
                                              0.0,
                                              1.0,
                                            ),
                                            minHeight:
                                            10,
                                            backgroundColor:
                                            Colors.white,
                                            valueColor:
                                            AlwaysStoppedAnimation<
                                                Color>(
                                              isFull
                                                  ? Colors.red
                                                  : Colors.green,
                                            ),
                                          ),
                                        ),
                                      ),

                                      const SizedBox(
                                          width:
                                          12),

                                      Text(
                                        "${(fillLevel * 100).toInt()}%",
                                        style:
                                        TextStyle(
                                          fontSize:
                                          14,
                                          fontWeight:
                                          FontWeight.bold,
                                          color:
                                          isFull
                                              ? Colors.red
                                              : Colors.green,
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(
                                      height: 4),

                                  Text(
                                    "Capacity Level",
                                    style:
                                    TextStyle(
                                      fontSize:
                                      11,
                                      color:
                                      Colors.grey[
                                      600],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),

                  const SizedBox(
                      height: 40),

                  _buildSection(
                    "Recent Activity Log",
                    historyData.isEmpty
                        ? const Padding(
                      padding:
                      EdgeInsets.all(
                        20,
                      ),
                      child: Text(
                        "No records found",
                      ),
                    )
                        : UserTable(
                      records:
                      historyData
                          .take(15)
                          .toList(),
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

  // ============================================================
  // USERS
  // ============================================================

  Widget _buildUsersList() {
    final screenWidth =
        MediaQuery.of(context).size.width;

    final isMobile =
        screenWidth < 600;

    return SingleChildScrollView(
      padding:
      EdgeInsets.all(isMobile ? 20 : 40),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Registered Users",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => setState(() {}),
                tooltip: "Refresh List",
              ),
            ],
          ),

          const SizedBox(height: 24),

          StreamBuilder<
              List<Map<String, dynamic>>>(
            stream:
            _databaseService
                .getUsersStream(),
            builder:
                (context, snapshot) {
              if (snapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(
                  child:
                  CircularProgressIndicator(),
                );
              }

              if (snapshot.hasError) {
                return _buildAdminErrorState();
              }

              if (!snapshot.hasData ||
                  snapshot.data!.isEmpty) {
                return const Center(
                  child: Padding(
                    padding:
                    EdgeInsets.all(40),
                    child: Text(
                      "No users registered yet.",
                    ),
                  ),
                );
              }

              final userList =
              snapshot.data!
                  .where((user) {
                final role =
                    user['role']
                        ?.toString()
                        .toLowerCase() ??
                        "user";

                return role == 'user';
              }).toList();

              if (userList.isEmpty) {
                return const Center(
                  child: Padding(
                    padding:
                    EdgeInsets.all(40),
                    child: Text(
                      "No student users found.",
                    ),
                  ),
                );
              }

              return StudentTable(students: userList);
            },
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DISPOSALS
  // ============================================================

  Widget _buildDisposalsList() {
    final screenWidth =
        MediaQuery.of(context).size.width;

    final isMobile =
        screenWidth < 600;

    return SingleChildScrollView(
      padding:
      EdgeInsets.all(isMobile ? 20 : 40),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          const Text(
            "Disposal Records",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 24),

          _buildSection(
            "Complete History",
            StreamBuilder<
                List<Map<String, dynamic>>>(
              stream: _databaseService
                  .getDisposalHistoryStream(),
              builder:
                  (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child:
                    CircularProgressIndicator(),
                  );
                }

                if (snapshot.hasError) {
                  return _buildAdminErrorState();
                }

                if (!snapshot.hasData ||
                    snapshot.data!.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding:
                      EdgeInsets.all(40),
                      child: Text(
                        "No disposal history found.",
                      ),
                    ),
                  );
                }

                final records =
                List<
                    Map<String,
                        dynamic>>.from(
                  snapshot.data!,
                ).where((r) {
                  final userId =
                      r['user_id']
                          ?.toString() ??
                          "";

                  return !userId
                      .toLowerCase()
                      .contains('admin');
                }).toList();

                records.sort(
                      (a, b) =>
                      (b['created_at'] ??
                          "")
                          .toString()
                          .compareTo(
                        (a['created_at'] ??
                            "")
                            .toString(),
                      ),
                );

                if (records.isEmpty) {
                  return const Center(
                    child: Text(
                      "No student records.",
                    ),
                  );
                }

                return UserTable(
                  records: records,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // LIVE FEED
  // ============================================================

  Widget _buildLiveFeed() {
    return _buildSection(
      "🔴 Live Activity Feed",
      SizedBox(
        height: 300,
        child: StreamBuilder<
            List<Map<String, dynamic>>>(
          stream:
          _databaseService
              .getRecentActivityStream(),
          builder:
              (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: Text(
                  "Offline Feed",
                ),
              );
            }

            final feed =
            (snapshot.data ?? [])
                .where((item) {
              final userId =
                  item['user_id']
                      ?.toString() ??
                      "";

              return !userId
                  .toLowerCase()
                  .contains('admin');
            }).toList();

            if (feed.isEmpty) {
              return const Center(
                child: Text(
                  "Waiting for activity...",
                ),
              );
            }

            return ListView.separated(
              itemCount: feed.length,
              separatorBuilder:
                  (_, __) =>
              const Divider(),
              itemBuilder:
                  (context, index) {
                final item =
                feed[index];

                DateTime? createdAt =
                DateTime.tryParse(
                  item['created_at']
                      ?.toString() ??
                      "",
                );

                return ListTile(
                  leading:
                  const CircleAvatar(
                    child: Icon(
                      Icons.flash_on,
                      size: 16,
                    ),
                  ),
                  title: Text(
                    item['waste_type'] ??
                        "Disposal",
                  ),
                  subtitle: Text(
                    createdAt == null
                        ? "Unknown time"
                        : DateFormat(
                      'h:mm:ss a',
                    ).format(
                      createdAt,
                    ),
                  ),
                  trailing: Text(
                    "+${item['points_earned'] ?? 0} pts",
                    style:
                    const TextStyle(
                      fontWeight:
                      FontWeight.bold,
                      color:
                      Colors.green,
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  Widget _buildAdminErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment:
        MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 64,
            color: Colors.grey,
          ),

          const SizedBox(height: 24),

          const Text(
            "Connection error",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          const Text(
            "Please check your internet connection.",
          ),

          const SizedBox(height: 32),

          ElevatedButton(
            onPressed: () =>
                setState(() {}),
            child: const Text(
              "Reconnect",
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveIndicator() {
    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color:
        Colors.red.withOpacity(0.1),
        borderRadius:
        BorderRadius.circular(8),
        border: Border.all(
          color:
          Colors.red.withOpacity(0.5),
        ),
      ),
      child: Row(
        mainAxisSize:
        MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration:
            const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
          ),

          const SizedBox(width: 6),

          const Text(
            "LIVE",
            style: TextStyle(
              color: Colors.red,
              fontSize: 10,
              fontWeight:
              FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(
      int index,
      IconData icon,
      String title,
      ) {
    final isSelected =
        _selectedIndex == index;

    return ListTile(
      leading: Icon(
        icon,
        color: isSelected
            ? Colors.white
            : Colors.white70,
        size: 20,
      ),

      title: FittedBox(
        fit: BoxFit.scaleDown,
        alignment:
        Alignment.centerLeft,
        child: Text(
          title,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : Colors.white70,
            fontWeight: isSelected
                ? FontWeight.bold
                : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),

      selected: isSelected,

      onTap: () {
        setState(() {
          _selectedIndex = index;
        });

        // Close drawer on mobile.
        if (MediaQuery.of(context)
            .size
            .width <
            1000) {
          Navigator.of(context).pop();
        }
      },

      contentPadding:
      const EdgeInsets.symmetric(
        horizontal: 16,
      ),

      dense: true,

      visualDensity:
      VisualDensity.compact,
    );
  }

  Widget _buildSection(
      String title,
      Widget content,
      ) {
    return Container(
      padding:
      const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(24),
        border: Border.all(
          color:
          Colors.grey.withOpacity(
            0.1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style:
            const TextStyle(
              fontWeight:
              FontWeight.bold,
              fontSize: 16,
            ),
          ),

          const SizedBox(height: 24),

          content,
        ],
      ),
    );
  }
}