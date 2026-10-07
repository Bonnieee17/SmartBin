import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';
import '../../core/theme/app_theme.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final _databaseService = DatabaseService();
  final _authService = AuthService();
  bool _isProcessing = false;

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
      final String code = barcodes.first.rawValue!;
      await _processScan(code);
    }
  }

  Future<void> _processScan(String code) async {
    setState(() => _isProcessing = true);

    try {
      final userId = await _authService.getEffectiveUserId();

      // 1. --- SECURE VOUCHER TOKEN SCAN ---
      try {
        final result = await _databaseService.claimVoucherInOffice(
          code,
          redeemedBy: userId,
          redemptionLocation: 'PSITS Office',
        );
        final success = result['success'] == true;
        final status = result['status']?.toString().toUpperCase() ?? 'INVALID';
        final message = result['message']?.toString() ?? (success ? "Voucher successfully redeemed!" : "Voucher verification failed.");

        if (mounted) {
          if (success && (status == 'REDEEMED' || status == 'AVAILABLE')) {
            _showVoucherClaimedDialog(result);
          } else {
            _showErrorDialog(message);
          }
        }
        return;
      } catch (_) {
        // If not a secure voucher token, proceed to disposal or other formats
      }

      // 2. --- CHECK IF IT'S A VOUCHER REDEMPTION SCAN (e.g. voucher:Printing Credit:100) ---
      if (code.startsWith('voucher:')) {
        final parts = code.split(':');
        if (parts.length < 3) throw Exception("Invalid Voucher Format");

        final rewardName = parts[1];
        final pointsCost = int.tryParse(parts[2]) ?? 0;

        if (pointsCost > 1000) {
          throw Exception("Voucher limit exceeded. Max 1000 pts per scan.");
        }

        await _databaseService.redeemVoucher(
          userId: userId,
          pointsCost: pointsCost,
          rewardName: rewardName,
        );

        if (mounted) {
          _showVoucherDialog(rewardName, pointsCost);
        }
        return;
      }

      // 3. --- CHECK IF IT'S A DYNAMIC DISPOSAL SCAN (FROM BIN LCD) ---
      if (code.startsWith('disposal:')) {
        final parts = code.split(':');
        if (parts.length < 4) throw Exception("Invalid Disposal Format");

        final wasteName = parts[1];
        final points = int.tryParse(parts[2]) ?? 0;
        final binId = parts[3];

        await _databaseService.recordDisposal(
          userId: userId,
          binId: binId,
          wasteType: wasteName,
          points: points,
        );

        if (mounted) {
          _showSuccessDialog(wasteName, points);
        }
        return;
      }

      // 4. --- DEFAULT / STATIC BIN ID SCAN (Any QR code scanned) ---
      final binId = code.isEmpty ? "BIN-01" : code;
      final wasteTypes = await _databaseService.getWasteTypes();
      final selectedWaste = wasteTypes.firstWhere(
        (w) => w['waste_name'].toString().toLowerCase().contains('bottle') ||
               w['waste_name'].toString().toLowerCase().contains('500ml'),
        orElse: () => wasteTypes.first,
      );

      final wasteName = selectedWaste['waste_name'] ?? 'PET Plastic Bottle';
      final pts = selectedWaste['points'] ?? 10;

      await _databaseService.recordDisposal(
        userId: userId,
        binId: binId,
        wasteType: wasteName,
        points: pts,
      );

      if (mounted) {
        _showSuccessDialog(wasteName, pts);
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog(e.toString().replaceAll("Exception: ", ""));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showVoucherClaimedDialog(Map<String, dynamic> result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.verified, color: Colors.blue, size: 60),
        title: const Text("Voucher Verified & Redeemed"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Code: ${result['voucher_code'] ?? 'N/A'}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
            const SizedBox(height: 8),
            Text(result['reward_name'] ?? 'Reward Voucher', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
              child: const Text("Status: REDEEMED AT PSITS OFFICE", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text("Done"),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.error_outline, color: Colors.redAccent, size: 50),
        title: const Text("Scan Alert"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  void _showVoucherDialog(String rewardName, int points) {
    final double pesos = points / 10.0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.confirmation_number_outlined, color: Color(0xFFE6AD62), size: 60),
        title: const Text("Voucher Claimed!"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(rewardName, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Text(
              "-$points Eco Points",
              style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
            ),
            const Divider(height: 24),
            Text(
              "₱${pesos.toStringAsFixed(2)}",
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const Text("Voucher Value (PSITS Office)", style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text("Awesome"),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String wasteName, int points) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 60),
        title: const Text("Disposal Recorded"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(wasteName, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              "+$points Eco Points",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green,
                fontSize: 18,
              ),
            ),
          ],
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back home
            },
            child: const Text("Done"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Scan SmartBin QR"),
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: _onDetect,
          ),
          // Overlay
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                "Align SmartBin or Voucher QR code within frame to scan.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ),
          if (_isProcessing)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
