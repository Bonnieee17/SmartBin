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
        stream: _databaseService.getBinsStream(),
        builder: (context, snapshot) {
          final bins = snapshot.data ?? [];
          final binData = bins.firstWhere(
            (b) => b['id'] == widget.binId,
            orElse: () => {'status': 'Waiting for item...', 'color': 'FF9E9E9E', 'qr_data': ''},
          );

          final String status = binData['status'] ?? "Waiting for item...";
          final String qrData = binData['qr_data'] ?? "";
          final Color statusColor = Color(int.parse(binData['color'] ?? "FF9E9E9E", radix: 16));

          // If no dynamic QR data (no drop detected), show the APP DOWNLOAD QR
          final String displayQrData = qrData.isNotEmpty ? qrData : AppConstants.downloadPage;
          final String instructionText = qrData.isNotEmpty ? "SCAN TO CLAIM POINTS" : "INSTALL THIS APP FOR A BETTER EXPERIENCE";

          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App Icon at the top
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white10, width: 2),
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/logo.png',
                        height: 80,
                        width: 80,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  Text(
                    status.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: qrData.isNotEmpty ? statusColor : Colors.white,
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
                          color: (qrData.isNotEmpty ? statusColor : Colors.green).withOpacity(0.3),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: QrImageView(
                      data: displayQrData,
                      version: QrVersions.auto,
                      size: 300,
                      embeddedImage: const AssetImage('assets/images/logo.png'),
                      embeddedImageStyle: const QrEmbeddedImageStyle(
                        size: Size(60, 60),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 60),
                  const Text(
                    "SMARTBIN OS v2.0 • OFFICIAL INTERFACE",
                    style: TextStyle(
                      color: Colors.white24,
                      fontSize: 12,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    instructionText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
