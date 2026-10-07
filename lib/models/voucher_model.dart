import 'package:intl/intl.dart';

class VoucherModel {
  final String id;
  final String code; // SmartBin Unique Digital Identifier (e.g. SB-VCH-2026-XXXX)
  final String userId;
  final String? userName;
  final String rewardName;
  final int pointsCost;
  final String claimLocation; // "PSITS Office"
  final DateTime createdAt;
  final DateTime expiresAt; // createdAt + 3 days validity
  final DateTime? claimedAt;
  final String rawStatus; // "AVAILABLE", "REDEEMED", "EXPIRED", "pending", "claimed"

  VoucherModel({
    required this.id,
    required this.code,
    required this.userId,
    this.userName,
    required this.rewardName,
    required this.pointsCost,
    this.claimLocation = "PSITS Office",
    required this.createdAt,
    required this.expiresAt,
    this.claimedAt,
    this.rawStatus = "AVAILABLE",
  });

  bool get isClaimed => rawStatus.toUpperCase() == 'REDEEMED' || rawStatus.toLowerCase() == 'claimed';

  bool get isExpired {
    if (isClaimed) return false;
    return DateTime.now().isAfter(expiresAt) || rawStatus.toUpperCase() == 'EXPIRED' || rawStatus.toLowerCase() == 'expired';
  }

  String get status {
    if (isClaimed) return 'REDEEMED';
    if (isExpired) return 'EXPIRED';
    return 'AVAILABLE';
  }

  String get statusLabel {
    switch (status) {
      case 'REDEEMED':
      case 'claimed':
        return 'Claimed at PSITS Office';
      case 'EXPIRED':
      case 'expired':
        return 'Expired (3-Day Limit Passed)';
      default:
        return 'Available (Claim at PSITS Office)';
    }
  }

  Duration get remainingTime {
    if (isClaimed || isExpired) return Duration.zero;
    final diff = expiresAt.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  String get formattedRemainingTime {
    if (isClaimed) {
      return claimedAt != null
          ? "Claimed on ${DateFormat('MMM d, h:mm a').format(claimedAt!)}"
          : "Claimed";
    }
    if (isExpired) {
      return "Expired on ${DateFormat('MMM d, h:mm a').format(expiresAt)}";
    }
    final rem = remainingTime;
    if (rem.inDays >= 1) {
      final hours = rem.inHours % 24;
      return "Expires in ${rem.inDays}d ${hours}h";
    } else if (rem.inHours >= 1) {
      final mins = rem.inMinutes % 60;
      return "Expires in ${rem.inHours}h ${mins}m";
    } else {
      return "Expires in ${rem.inMinutes}m";
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'user_id': userId,
      'user_name': userName,
      'reward_name': rewardName,
      'points_cost': pointsCost,
      'claim_location': claimLocation,
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
      'claimed_at': claimedAt?.toIso8601String(),
      'status': status,
    };
  }

  factory VoucherModel.fromJson(Map<String, dynamic> json) {
    final created = json['created_at'] != null
        ? DateTime.parse(json['created_at'].toString())
        : DateTime.now();

    final expires = json['expires_at'] != null
        ? DateTime.parse(json['expires_at'].toString())
        : created.add(const Duration(days: 3));

    final claimed = json['claimed_at'] != null
        ? DateTime.parse(json['claimed_at'].toString())
        : null;

    final statusVal = json['status']?.toString() ?? (claimed != null ? 'REDEEMED' : 'AVAILABLE');

    return VoucherModel(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? json['voucher_code']?.toString() ?? json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      userName: json['user_name']?.toString() ?? (json['users'] is Map ? json['users']['full_name']?.toString() : null),
      rewardName: json['reward_name']?.toString() ?? 'Reward Voucher',
      pointsCost: json['points_cost'] != null
          ? int.tryParse(json['points_cost'].toString()) ?? 0
          : 0,
      claimLocation: json['claim_location']?.toString() ?? 'PSITS Office',
      createdAt: created,
      expiresAt: expires,
      claimedAt: claimed,
      rawStatus: statusVal,
    );
  }
}
