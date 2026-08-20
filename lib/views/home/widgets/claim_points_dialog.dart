import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/database_service.dart';
import '../../../services/auth_service.dart';

class ClaimPointsDialog extends StatefulWidget {
  final int points;
  final String wasteType;
  final String binId;

  const ClaimPointsDialog({
    super.key,
    required this.points,
    required this.wasteType,
    required this.binId,
  });

  @override
  State<ClaimPointsDialog> createState() => _ClaimPointsDialogState();
}

class _ClaimPointsDialogState extends State<ClaimPointsDialog> {
  int _secondsLeft = 30;
  Timer? _timer;
  bool _isClaiming = false;
  final _databaseService = DatabaseService();
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft > 0) {
        setState(() => _secondsLeft--);
      } else {
        _timer?.cancel();
        if (mounted) Navigator.pop(context); // Close if time runs out
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _handleClaim() async {
    setState(() => _isClaiming = true);
    try {
      final user = _authService.currentUser;
      if (user != null) {
        await _databaseService.recordDisposal(
          userId: user.id,
          binId: widget.binId,
          wasteType: widget.wasteType,
          weight: 0.1,
          points: widget.points,
        );
        if (mounted) {
          Navigator.pop(context, true); // Success
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Successfully claimed ${widget.points} points!")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.toString()}")),
        );
      }
    } finally {
      if (mounted) setState(() => _isClaiming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: Colors.white,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 16),
          // Timer Circle
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                height: 80,
                width: 80,
                child: CircularProgressIndicator(
                  value: _secondsLeft / 30,
                  strokeWidth: 8,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation(
                    _secondsLeft > 10 ? AppTheme.primaryGreen : Colors.red,
                  ),
                ),
              ),
              Text(
                "$_secondsLeft",
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 32),
          const Text(
            "Points Detected!",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            "You earned points for recycling:",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              widget.wasteType,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryGreen,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "+${widget.points}",
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w900,
              color: AppTheme.primaryGreen,
            ),
          ),
          const Text("Eco Points", style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: _isClaiming ? null : _handleClaim,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isClaiming
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("CLAIM NOW", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Discard Points", style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }
}
