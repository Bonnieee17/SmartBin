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
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _databaseService.getLatestUnclaimedSession(widget.binId),
        builder: (context, snapshot) {
          final sessions = snapshot.data ?? [];
          final latestSession = sessions.isNotEmpty ? sessions.first : null;

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
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Badge(
              label: Text("REWARD ACTIVE", style: TextStyle(fontWeight: FontWeight.bold)),
              backgroundColor: Colors.orange,
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            ),
            const SizedBox(height: 24),
            Text(
              wasteType.toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.greenAccent,
                fontWeight: FontWeight.bold,
                fontSize: 28,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "+$points ECO POINTS",
              style: const TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.4),
                    blurRadius: 40,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 280,
                embeddedImage: const AssetImage('assets/images/logo.png'),
                embeddedImageStyle: const QrEmbeddedImageStyle(size: Size(60, 60)),
              ),
            ),
            const SizedBox(height: 40),
            TweenAnimationBuilder<Duration>(
              duration: expiresAt.difference(DateTime.now()),
              tween: Tween(begin: expiresAt.difference(DateTime.now()), end: Duration.zero),
              onEnd: () => setState(() {}),
              builder: (context, value, child) {
                final seconds = value.inSeconds;
                return Column(
                  children: [
                    Text(
                      "SCAN TO CLAIM IN ${seconds}S",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: 200,
                      child: LinearProgressIndicator(
                        value: seconds / 30,
                        backgroundColor: Colors.white10,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultUI() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/logo.png', height: 80, width: 80),
            const SizedBox(height: 32),
            const Text(
              "READY FOR DISPOSAL",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 24,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 48),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.2),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: QrImageView(
                data: AppConstants.downloadPage,
                version: QrVersions.auto,
                size: 300,
              ),
            ),
            const SizedBox(height: 60),
            const Text(
              "SMARTBIN OS v2.0 • STANDBY",
              style: TextStyle(color: Colors.white24, fontSize: 12, letterSpacing: 2),
            ),
            const SizedBox(height: 12),
            const Text(
              "INSTALL APP TO START EARNING",
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
