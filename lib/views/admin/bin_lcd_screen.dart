import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/constants/app_constants.dart';
import '../../services/database_service.dart';

class BinLcdScreen extends StatefulWidget {
  final String binId;
  const BinLcdScreen({super.key, this.binId = "BIN-001"});

  @override
  State<BinLcdScreen> createState() => _BinLcdScreenState();
}

class _BinLcdScreenState extends State<BinLcdScreen> {
  final _databaseService = DatabaseService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _databaseService.getLatestUnclaimedSession(widget.binId),
        builder: (context, snapshot) {
          final latestSession = snapshot.data;

          bool isSessionActive = false;
          if (latestSession != null) {
            final expiresAt = DateTime.parse(latestSession['expires_at']);
            if (expiresAt.isAfter(DateTime.now())) {
              isSessionActive = true;
            }
          }

          if (isSessionActive) {
            final String token = latestSession!['token'];
            final String qrData = "${AppConstants.claimPage}?token=$token";
            final String wasteType = latestSession['waste_type'];
            final int points = latestSession['points'];
            final DateTime expiresAt = DateTime.parse(latestSession['expires_at']);

            return _buildRewardUI(qrData, wasteType, points, expiresAt);
          }

          return _buildDefaultUI();
        },
      ),
    );
  }

  Widget _buildRewardUI(String qrData, String wasteType, int points, DateTime expiresAt) {
    return Center(
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: const Color(0xFF242424),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.green.withValues(alpha: 0.4), width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "REWARD UNLOCKED!",
              style: TextStyle(color: Colors.green, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.5),
            ),
            const SizedBox(height: 8),
            Text(
              "+$points POINTS",
              style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900),
            ),
            Text(
              "Item: $wasteType",
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 160.0,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Scan to Claim Reward",
              style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultUI() {
    return Center(
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: const Color(0xFF242424),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white24, width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.qr_code_2, size: 80, color: Colors.green),
            const SizedBox(height: 16),
            const Text(
              "SMARTBIN",
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 2),
            ),
            const SizedBox(height: 8),
            const Text(
              "Scan to Open SmartBin App",
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                "READY FOR DISPOSAL",
                style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
