import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';

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
      final user = _authService.currentUser;
      if (user == null) return;

      // --- CHECK IF IT'S A VOUCHER SCAN ---
      if (code.startsWith('voucher:')) {
        final parts = code.split(':');
        if (parts.length < 3) throw Exception("Invalid Voucher Format");

        final rewardName = parts[1];
        final pointsCost = int.tryParse(parts[2]) ?? 0;

        // 1. Enforce 1000-point limit
        if (pointsCost > 1000) {
          throw Exception("Voucher limit exceeded. Max 1000 pts per scan.");
        }

        // 2. Process Redemption
        await _databaseService.redeemVoucher(
          userId: user.id,
          pointsCost: pointsCost,
          rewardName: rewardName,
        );

        if (mounted) {
          _showVoucherDialog(rewardName, pointsCost);
        }
        return;
      }

      // --- CHECK IF IT'S A DYNAMIC DISPOSAL SCAN (FROM BIN LCD) ---
      if (code.startsWith('disposal:')) {
        final parts = code.split(':');
        if (parts.length < 4) throw Exception("Invalid Disposal Format");

        final wasteName = parts[1];
        final points = int.tryParse(parts[2]) ?? 0;
        final binId = parts[3];

        await _databaseService.recordDisposal(
          userId: user.id,
          binId: binId,
          wasteType: wasteName,
          weight: 0.1, // Hardware would provide this, we'll default for now
          points: points,
        );

        if (mounted) {
          _showSuccessDialog(wasteName, points);
        }
        return;
      }

      // --- OTHERWISE, IT'S A LEGACY/STATIC BIN ID SCAN ---
      final binId = code;
      final wasteTypes = await _databaseService.getWasteTypes();
      final selectedWaste = wasteTypes.firstWhere(
        (w) => w['waste_name'].toString().toLowerCase().contains('500ml'),
        orElse: () => wasteTypes.first,
      );

      await _databaseService.recordDisposal(
        userId: user.id,
        binId: binId,
        wasteType: selectedWaste['waste_name'],
        weight: 0.5,
        points: selectedWaste['points'],
      );

      if (mounted) {
        _showSuccessDialog(
          selectedWaste['waste_name'],
          selectedWaste['points'],
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll("Exception: ", "")),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showVoucherDialog(String rewardName, int points) {
    // 10 Points = 1 Peso
    final double pesos = points / 10.0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.confirmation_number_outlined, color: Color(0xFFE6AD62), size: 60),
        title: const Text("Voucher Redeemed!"),
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
            const Text("Voucher Value", style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          FilledButton(
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
            Text(wasteName),
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
      appBar: AppBar(title: const Text("Scan Bin QR")),
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
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(12),
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
