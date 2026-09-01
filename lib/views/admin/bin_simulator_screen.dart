import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../services/database_service.dart';

class BinSimulatorScreen extends StatefulWidget {
  final String binId;
  const BinSimulatorScreen({super.key, this.binId = "BIN-001"});

  @override
  State<BinSimulatorScreen> createState() => _BinSimulatorScreenState();
}

class _BinSimulatorScreenState extends State<BinSimulatorScreen> {
  final _databaseService = DatabaseService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _databaseService.getBinsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text("Error loading simulator", style: TextStyle(color: Colors.white)));
          }
          
          final bins = snapshot.data ?? [];
          final binData = bins.firstWhere(
            (b) => b['id'] == widget.binId,
            orElse: () => {'status': 'Waiting for item...', 'color': 'FF9E9E9E', 'qr_data': ''},
          );

          final String status = binData['status'] ?? "Waiting for item...";
          final String qrData = binData['qr_data'] ?? "";
          final Color color = Color(int.parse(binData['color'] ?? "FF9E9E9E", radix: 16));

          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    status.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 48),
                  if (qrData.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.3),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: QrImageView(
                        data: qrData,
                        version: QrVersions.auto,
                        size: 300,
                        embeddedImage: const AssetImage('assets/images/logo.png'),
                        embeddedImageStyle: const QrEmbeddedImageStyle(
                          size: Size(60, 60),
                        ),
                      ),
                    )
                  else
                    Container(
                      height: 348,
                      width: 348,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.qr_code_scanner,
                          color: Colors.white24,
                          size: 100,
                        ),
                      ),
                    ),
                  const SizedBox(height: 60),
                  const Text(
                    "SMARTBIN OS v2.0 • LIVE FEED",
                    style: TextStyle(
                      color: Colors.white24,
                      fontSize: 12,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "SCAN TO REDEEM ECO POINTS",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 40),
                  Text(
                    "Bin ID: ${widget.binId}",
                    style: const TextStyle(color: Colors.white38, fontSize: 10),
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
