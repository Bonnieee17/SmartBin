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

  Future<void> _processScan(String binId) async {
    setState(() => _isProcessing = true);

    try {
      final user = _authService.currentUser;
      if (user == null) return;

      // Fetch available waste types to simulate detection
      final wasteTypes = await _databaseService.getWasteTypes();
      
      // For demo purposes, we'll pick the first one (or match by ID if binId was a waste ID)
      // In this case, let's pick "Plastic bottle 500ml" if it exists, otherwise the first one
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
          SnackBar(content: Text("Error: ${e.toString()}")),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
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
