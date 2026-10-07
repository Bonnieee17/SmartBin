import 'dart:convert';
import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/voucher_model.dart';

class DatabaseService {
  final _supabase = Supabase.instance.client;

  // ============================================================
  // REWARDS
  // ============================================================

  Future<List<Map<String, dynamic>>> getRewards() async {
    try {
      final response = await _supabase
          .from('rewards')
          .select()
          .order('points_cost', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (_) {
      // Fallback rewards
      return [
        {
          'id': 'reward_1',
          'name': 'Printing Credit',
          'description': '₱10 Printing Credit',
          'points_cost': 100,
          'icon': 'print',
        },
        {
          'id': 'reward_2',
          'name': 'SmartBin Voucher',
          'description': 'SmartBin Digital Voucher',
          'points_cost': 100,
          'icon': 'qr_code',
        },
      ];
    }
  }

  // ============================================================
  // WASTE TYPES
  // ============================================================

  Future<List<Map<String, dynamic>>> getWasteTypes() async {
    try {
      final response = await _supabase
          .from('waste_types')
          .select()
          .order('name');

      return List<Map<String, dynamic>>.from(response);
    } catch (_) {
      return [
        {
          'id': 'plastic',
          'name': 'Plastic',
          'points': 10,
        },
        {
          'id': 'paper',
          'name': 'Paper',
          'points': 8,
        },
        {
          'id': 'metal',
          'name': 'Metal',
          'points': 15,
        },
        {
          'id': 'glass',
          'name': 'Glass',
          'points': 12,
        },
      ];
    }
  }

  // ============================================================
  // BADGES
  // ============================================================

  Future<List<Map<String, dynamic>>> getBadges() async {
    try {
      final response = await _supabase
          .from('badges')
          .select()
          .order('points_required');

      return List<Map<String, dynamic>>.from(response);
    } catch (_) {
      return [];
    }
  }

  // ============================================================
  // BINS
  // ============================================================

  Stream<List<Map<String, dynamic>>> getBinsStream() {
    return _supabase
        .from('bins')
        .stream(primaryKey: ['id'])
        .order('name');
  }

  Future<List<Map<String, dynamic>>> getBins() async {
    try {
      final response = await _supabase
          .from('bins')
          .select()
          .order('name');

      return List<Map<String, dynamic>>.from(response);
    } catch (_) {
      return [];
    }
  }

  // ============================================================
  // USERS / STUDENTS
  // ============================================================

  Stream<List<Map<String, dynamic>>> getUsersStream() {
    return _supabase
        .from('users')
        .stream(primaryKey: ['id'])
        .order('full_name');
  }

  Future<List<Map<String, dynamic>>> getStudents() async {
    try {
      final response = await _supabase
          .from('users')
          .select()
          .order('full_name');

      return List<Map<String, dynamic>>.from(response);
    } catch (_) {
      return [];
    }
  }

  // ============================================================
  // RECENT ACTIVITY
  // ============================================================

  Stream<List<Map<String, dynamic>>> getRecentActivityStream() {
    return _supabase
        .from('disposal_history')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);
  }

  Stream<List<Map<String, dynamic>>> getDisposalHistoryStream() {
    return _supabase
        .from('disposal_history')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);
  }

  // ============================================================
  // REWARD SESSION
  // ============================================================

  Future<String> createRewardSession({
    required String userId,
    required int points,
  }) async {
    final token = _generateRandomToken();

    try {
      await _supabase.from('reward_sessions').insert({
        'user_id': userId,
        'token': token,
        'points': points,
        'claimed': false,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to create reward session: $e');
    }

    return token;
  }

  // ============================================================
  // CLAIM REWARD SESSION
  // ============================================================

  Future<void> claimRewardByToken(String token) async {
    final cleanToken = token.trim();

    if (cleanToken.isEmpty) {
      throw Exception('Invalid reward token.');
    }

    try {
      final session = await _supabase
          .from('reward_sessions')
          .select()
          .eq('token', cleanToken)
          .maybeSingle();

      if (session == null) {
        throw Exception('Reward session not found.');
      }

      final claimed = session['claimed'] == true;

      if (claimed) {
        throw Exception('This reward has already been claimed.');
      }

      final userId = session['user_id']?.toString();
      final points = (session['points'] as num?)?.toInt() ?? 0;

      if (userId == null) {
        throw Exception('Invalid reward session.');
      }

      await _supabase
          .from('reward_sessions')
          .update({
        'claimed': true,
        'claimed_at': DateTime.now().toIso8601String(),
      })
          .eq('token', cleanToken);

      await recordDisposal(
        userId: userId,
        points: points,
        wasteType: 'Reward',
      );
    } catch (e) {
      throw Exception(
        e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  // ============================================================
  // USER POINTS
  // ============================================================

  Future<int> getUserPoints(String userId) async {
    try {
      final response = await _supabase
          .from('users')
          .select('total_points')
          .eq('id', userId)
          .maybeSingle();

      if (response == null) {
        return 0;
      }

      return (response['total_points'] as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  // ============================================================
  // ADD POINTS
  // ============================================================

  Future<void> addPointsLocallyAndRemote(
      String userId,
      int points,
      ) async {
    if (points <= 0) return;

    try {
      final currentPoints = await getUserPoints(userId);
      final newPoints = currentPoints + points;

      await _supabase
          .from('users')
          .update({
        'total_points': newPoints,
      })
          .eq('id', userId);
    } catch (e) {
      throw Exception('Failed to add points: $e');
    }
  }

  // ============================================================
  // DEDUCT POINTS
  // ============================================================
  //
  // NOTE:
  // This method remains available for other parts of the app.
  //
  // IMPORTANT:
  // DO NOT call this method before create_smartbin_voucher().
  // The SmartBin SQL RPC already deducts the points atomically.
  // ============================================================

  Future<void> deductPointsLocallyAndRemote(
      String userId,
      int points,
      ) async {
    if (points <= 0) {
      throw Exception('Points must be greater than zero.');
    }

    try {
      final currentPoints = await getUserPoints(userId);

      if (currentPoints < points) {
        throw Exception('Not enough points.');
      }

      final newPoints = currentPoints - points;

      await _supabase
          .from('users')
          .update({
        'total_points': newPoints,
      })
          .eq('id', userId);
    } catch (e) {
      throw Exception(
        e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  // ============================================================
  // RECORD DISPOSAL
  // ============================================================

  Future<void> recordDisposal({
    required String userId,
    required int points,
    required String wasteType,
    String? binId,
  }) async {
    if (points <= 0) {
      throw Exception('Points must be greater than zero.');
    }

    await addPointsLocallyAndRemote(userId, points);

    try {
      await _supabase.from('disposal_history').insert({
        'user_id': userId,
        'points_earned': points,
        'waste_type': wasteType,
        'bin_id': binId,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // Keep the points update even if history insertion fails.
    }
  }

  // ============================================================
  // LOCAL HISTORY
  // ============================================================

  Future<List<Map<String, dynamic>>> getLocalDisposalHistory() async {
    final prefs = await SharedPreferences.getInstance();

    final jsonList =
        prefs.getStringList('local_disposal_history') ?? [];

    final result = <Map<String, dynamic>>[];

    for (final item in jsonList) {
      try {
        result.add(
          Map<String, dynamic>.from(
            jsonDecode(item),
          ),
        );
      } catch (_) {}
    }

    return result;
  }

  Future<void> saveLocalDisposalHistory(
      Map<String, dynamic> data,
      ) async {
    final prefs = await SharedPreferences.getInstance();

    final existing =
        prefs.getStringList('local_disposal_history') ?? [];

    existing.add(jsonEncode(data));

    await prefs.setStringList(
      'local_disposal_history',
      existing,
    );
  }

  // ============================================================
  // LATEST UNCLAIMED SESSION
  // ============================================================

  Future<Map<String, dynamic>?> getLatestUnclaimedSession(
      String userId,
      ) async {
    try {
      final response = await _supabase
          .from('reward_sessions')
          .select()
          .eq('user_id', userId)
          .eq('claimed', false)
          .order('created_at', ascending: false)
          .limit(1);

      if (response.isEmpty) {
        return null;
      }

      return Map<String, dynamic>.from(response.first);
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // RANDOM TOKEN
  // ============================================================

  String _generateRandomToken() {
    final random = math.Random.secure();

    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
        'abcdefghijklmnopqrstuvwxyz'
        '0123456789';

    return List.generate(
      32,
          (_) => chars[random.nextInt(chars.length)],
    ).join();
  }

  // ============================================================
  // ============================================================
  // SMARTBIN SECURE DIGITAL VOUCHERS
  // ============================================================
  // ============================================================

  // ------------------------------------------------------------
  // Generate voucher
  // ------------------------------------------------------------
  //
  // IMPORTANT:
  //
  // The QR CODE must contain the returned "token".
  //
  // Do NOT put voucher_code into the QR.
  //
  // The SQL function:
  //
  // create_smartbin_voucher()
  //
  // handles:
  // - authentication
  // - point validation
  // - point deduction
  // - secure token generation
  // - token hashing
  // - voucher creation
  // - expiration
  //
  // ------------------------------------------------------------

  Future<VoucherModel> generateDigitalVoucherPass({
    required String userId,
    required int pointsCost,
    required String rewardName,
    String? userName,
    int validityDays = 3,
    double? pesoValue,
  }) async {
    if (userId.trim().isEmpty) {
      throw Exception('User ID is required.');
    }

    if (pointsCost <= 0) {
      throw Exception('Points cost must be greater than zero.');
    }

    if (validityDays < 1 || validityDays > 3) {
      throw Exception('Voucher validity must be between 1 and 3 days.');
    }

    final currentUser = _supabase.auth.currentUser;

    if (currentUser == null) {
      throw Exception('You must be logged in to create a voucher.');
    }

    if (currentUser.id != userId) {
      throw Exception(
        'You can only create a voucher for your own account.',
      );
    }

    // ----------------------------------------------------------
    // Determine peso value
    // ----------------------------------------------------------
    //
    // Default assumption:
    // 100 points = ₱10
    //
    // If your project has a different conversion, pass:
    //
    // pesoValue: 10.0
    //
    // explicitly.
    // ----------------------------------------------------------

    final calculatedPesoValue =
        pesoValue ?? _calculatePesoValue(pointsCost);

    if (calculatedPesoValue <= 0) {
      throw Exception('Peso value must be greater than zero.');
    }

    try {
      // --------------------------------------------------------
      // CALL SUPABASE RPC
      // --------------------------------------------------------
      //
      // This RPC already deducts the user's points.
      //
      // DO NOT call:
      //
      // deductPointsLocallyAndRemote()
      //
      // here.
      // --------------------------------------------------------

      final result = await _supabase.rpc(
        'create_smartbin_voucher',
        params: {
          'p_user_id': userId,
          'p_points_used': pointsCost,
          'p_peso_value': calculatedPesoValue,
          'p_valid_days': validityDays,
        },
      );

      final data = _normalizeRpcResult(result);

      if (data['success'] != true) {
        throw Exception(
          data['message']?.toString() ??
              'Failed to create SmartBin voucher.',
        );
      }

      final voucherId =
          data['voucher_id']?.toString() ?? '';

      final voucherCode =
          data['voucher_code']?.toString() ?? '';

      final rawToken =
          data['token']?.toString() ?? '';

      if (voucherId.isEmpty) {
        throw Exception('Voucher ID was not returned.');
      }

      if (voucherCode.isEmpty) {
        throw Exception('Voucher code was not returned.');
      }

      if (rawToken.isEmpty) {
        throw Exception('QR token was not returned.');
      }

      // --------------------------------------------------------
      // Dates
      // --------------------------------------------------------

      final createdAt = _parseDateTime(
        data['created_at'],
        DateTime.now(),
      );

      final expiresAt = _parseDateTime(
        data['expires_at'],
        createdAt.add(
          Duration(days: validityDays),
        ),
      );

      // --------------------------------------------------------
      // Create local VoucherModel
      // --------------------------------------------------------

      final voucher = VoucherModel(
        id: voucherId,
        code: voucherCode,
        userId: userId,
        userName: userName ?? 'Student',
        rewardName: rewardName,
        pointsCost: pointsCost,
        claimLocation: 'PSITS Office',
        createdAt: createdAt,
        expiresAt: expiresAt,
        rawStatus: data['status']?.toString() ?? 'AVAILABLE',
      );

      // --------------------------------------------------------
      // Store raw QR token locally
      //
      // The token is intentionally NOT placed inside
      // VoucherModel unless your model has a token field.
      // --------------------------------------------------------

      await _saveVoucherToken(
        voucherId: voucherId,
        token: rawToken,
      );

      await _saveVoucherToLocal(voucher);

      return voucher;
    } catch (e) {
      throw Exception(
        e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  // ============================================================
  // BACKWARD-COMPATIBILITY: generateVoucher
  // ============================================================

  Future<String> generateVoucher({
    required String userId,
    required int pointsCost,
    required String rewardName,
  }) async {
    final voucher = await generateDigitalVoucherPass(
      userId: userId,
      pointsCost: pointsCost,
      rewardName: rewardName,
    );

    return voucher.code;
  }

  // ============================================================
  // BACKWARD-COMPATIBILITY: redeemVoucher
  // ============================================================
  //
  // NOTE:
  // This old method actually CREATED a voucher.
  //
  // It is preserved so old screens do not immediately break.
  //
  // For actual redemption, use:
  //
  // redeemSmartBinVoucher()
  //
  // ============================================================

  Future<void> redeemVoucher({
    required String userId,
    required int pointsCost,
    required String rewardName,
  }) async {
    await generateDigitalVoucherPass(
      userId: userId,
      pointsCost: pointsCost,
      rewardName: rewardName,
    );
  }

  // ============================================================
  // CALCULATE PESO VALUE
  // ============================================================

  double _calculatePesoValue(int points) {
    // 100 points = ₱10
    return points / 10.0;
  }

  // ============================================================
  // NORMALIZE SUPABASE RPC RESULT
  // ============================================================

  Map<String, dynamic> _normalizeRpcResult(dynamic result) {
    if (result is Map<String, dynamic>) {
      return result;
    }

    if (result is Map) {
      return Map<String, dynamic>.from(result);
    }

    try {
      return Map<String, dynamic>.from(
        jsonDecode(jsonEncode(result)),
      );
    } catch (_) {
      throw Exception(
        'Unexpected response from Supabase RPC.',
      );
    }
  }

  // ============================================================
  // VERIFY SMARTBIN VOUCHER
  // ============================================================
  //
  // Use this after the cellphone scans the QR code.
  //
  // scanned QR value = raw token
  //
  // Example:
  //
  // final result = await verifySmartBinVoucher(
  //   token: scannedQrValue,
  // );
  //
  // ============================================================

  Future<Map<String, dynamic>> verifySmartBinVoucher({
    required String token,
  }) async {
    final cleanToken = token.trim();

    if (cleanToken.isEmpty) {
      throw Exception('Invalid QR token.');
    }

    if (cleanToken.length < 10) {
      throw Exception('Invalid QR token.');
    }

    try {
      final result = await _supabase.rpc(
        'verify_smartbin_voucher',
        params: {
          'p_token': cleanToken,
        },
      );

      return _normalizeRpcResult(result);
    } catch (e) {
      throw Exception(
        e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  // ============================================================
  // REDEEM SMARTBIN VOUCHER
  // ============================================================
  //
  // This is the ACTUAL redemption.
  //
  // The SQL function locks the voucher row and prevents
  // double redemption.
  //
  // ============================================================

  Future<Map<String, dynamic>> redeemSmartBinVoucher({
    required String token,
    required String redeemedBy,
    String? redemptionLocation,
  }) async {
    final cleanToken = token.trim();

    if (cleanToken.isEmpty) {
      throw Exception('Invalid QR token.');
    }

    if (cleanToken.length < 10) {
      throw Exception('Invalid QR token.');
    }

    if (redeemedBy.trim().isEmpty) {
      throw Exception('Redeemer user ID is required.');
    }

    final currentUser = _supabase.auth.currentUser;

    if (currentUser == null) {
      throw Exception(
        'You must be logged in to redeem a voucher.',
      );
    }

    if (currentUser.id != redeemedBy) {
      throw Exception(
        'The logged-in user does not match the redeemer.',
      );
    }

    try {
      final result = await _supabase.rpc(
        'redeem_smartbin_voucher',
        params: {
          'p_token': cleanToken,
          'p_redeemed_by': redeemedBy,
          'p_redemption_location': redemptionLocation,
        },
      );

      return _normalizeRpcResult(result);
    } catch (e) {
      throw Exception(
        e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  // ============================================================
  // VERIFY + REDEEM
  // ============================================================
  //
  // Convenience method.
  //
  // First verifies the QR.
  // If AVAILABLE, immediately redeems it.
  //
  // ============================================================

  Future<Map<String, dynamic>> verifyAndRedeemSmartBinVoucher({
    required String token,
    required String redeemedBy,
    String? redemptionLocation,
  }) async {
    // First verify
    final verification = await verifySmartBinVoucher(
      token: token,
    );

    final success = verification['success'] == true;
    final status =
    verification['status']?.toString().toUpperCase();

    if (!success || status != 'AVAILABLE') {
      return verification;
    }

    // Then redeem
    return await redeemSmartBinVoucher(
      token: token,
      redeemedBy: redeemedBy,
      redemptionLocation: redemptionLocation,
    );
  }

  // ============================================================
  // SAVE QR TOKEN LOCALLY
  // ============================================================

  Future<void> _saveVoucherToken({
    required String voucherId,
    required String token,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final existing =
        prefs.getStringList('smartbin_voucher_tokens') ?? [];

    final List<Map<String, dynamic>> tokens = [];

    for (final item in existing) {
      try {
        final decoded = jsonDecode(item);

        if (decoded is Map) {
          tokens.add(
            Map<String, dynamic>.from(decoded),
          );
        }
      } catch (_) {}
    }

    tokens.removeWhere(
          (item) => item['voucher_id']?.toString() == voucherId,
    );

    tokens.add({
      'voucher_id': voucherId,
      'token': token,
      'saved_at': DateTime.now().toIso8601String(),
    });

    await prefs.setStringList(
      'smartbin_voucher_tokens',
      tokens.map(jsonEncode).toList(),
    );
  }

  // ============================================================
  // GET QR TOKEN FOR VOUCHER
  // ============================================================

  Future<String?> getVoucherToken(String voucherId) async {
    final prefs = await SharedPreferences.getInstance();

    final existing =
        prefs.getStringList('smartbin_voucher_tokens') ?? [];

    for (final item in existing) {
      try {
        final decoded = jsonDecode(item);

        if (decoded is Map) {
          final map = Map<String, dynamic>.from(decoded);

          if (map['voucher_id']?.toString() == voucherId) {
            return map['token']?.toString();
          }
        }
      } catch (_) {}
    }

    return null;
  }

  // ============================================================
  // GET USER VOUCHERS
  // ============================================================

  Future<List<VoucherModel>> getUserVouchers(
      String userId,
      ) async {
    final List<VoucherModel> list = [];

    // ----------------------------------------------------------
    // Supabase
    // ----------------------------------------------------------

    try {
      final response = await _supabase
          .from('vouchers')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      for (final item in response) {
        try {
          list.add(
            VoucherModel.fromJson(
              Map<String, dynamic>.from(item),
            ),
          );
        } catch (_) {}
      }
    } catch (_) {}

    // ----------------------------------------------------------
    // Local backup
    // ----------------------------------------------------------

    final localList = await _getVouchersFromLocal();

    final userLocal =
    localList.where((v) => v.userId == userId).toList();

    for (final localVoucher in userLocal) {
      if (!list.any(
            (v) =>
        v.code == localVoucher.code ||
            v.id == localVoucher.id,
      )) {
        list.add(localVoucher);
      }
    }

    list.sort(
          (a, b) => b.createdAt.compareTo(a.createdAt),
    );

    return list;
  }

  // ============================================================
  // CLAIM VOUCHER IN OFFICE
  // ============================================================
  //
  // OLD VERSION used voucher code/id and directly changed
  // the database.
  //
  // NEW VERSION:
  // The scanner must scan the RAW QR TOKEN.
  //
  // ============================================================

  Future<Map<String, dynamic>> claimVoucherInOffice(
      String qrToken, {
        required String redeemedBy,
        String redemptionLocation = 'PSITS Office',
      }) async {
    final cleanToken = qrToken.trim();

    if (cleanToken.isEmpty) {
      throw Exception('Please scan a valid SmartBin QR code.');
    }

    return await verifyAndRedeemSmartBinVoucher(
      token: cleanToken,
      redeemedBy: redeemedBy,
      redemptionLocation: redemptionLocation,
    );
  }

  // ============================================================
  // GET ALL VOUCHERS
  // ============================================================

  Future<List<VoucherModel>> getAllVouchers() async {
    final List<VoucherModel> list = [];

    try {
      final response = await _supabase
          .from('vouchers')
          .select()
          .order('created_at', ascending: false);

      for (final item in response) {
        try {
          list.add(
            VoucherModel.fromJson(
              Map<String, dynamic>.from(item),
            ),
          );
        } catch (_) {}
      }
    } catch (_) {}

    final localList = await _getVouchersFromLocal();

    for (final localVoucher in localList) {
      if (!list.any(
            (v) =>
        v.code == localVoucher.code ||
            v.id == localVoucher.id,
      )) {
        list.add(localVoucher);
      }
    }

    list.sort(
          (a, b) => b.createdAt.compareTo(a.createdAt),
    );

    return list;
  }

  // ============================================================
  // SAVE VOUCHER LOCALLY
  // ============================================================

  Future<void> _saveVoucherToLocal(
      VoucherModel voucher,
      ) async {
    final prefs = await SharedPreferences.getInstance();

    final existingJson =
        prefs.getStringList('local_user_vouchers') ?? [];

    final List<Map<String, dynamic>> mapList = [];

    for (final str in existingJson) {
      try {
        final decoded = jsonDecode(str);

        if (decoded is Map) {
          mapList.add(
            Map<String, dynamic>.from(decoded),
          );
        }
      } catch (_) {}
    }

    mapList.removeWhere(
          (m) =>
      m['code']?.toString() == voucher.code ||
          m['id']?.toString() == voucher.id,
    );

    mapList.add(voucher.toJson());

    final updatedJson =
    mapList.map((m) => jsonEncode(m)).toList();

    await prefs.setStringList(
      'local_user_vouchers',
      updatedJson,
    );
  }

  // ============================================================
  // GET LOCAL VOUCHERS
  // ============================================================

  Future<List<VoucherModel>> _getVouchersFromLocal() async {
    final prefs = await SharedPreferences.getInstance();

    final existingJson =
        prefs.getStringList('local_user_vouchers') ?? [];

    final List<VoucherModel> list = [];

    for (final str in existingJson) {
      try {
        list.add(
          VoucherModel.fromJson(
            jsonDecode(str),
          ),
        );
      } catch (_) {}
    }

    return list;
  }

  // ============================================================
  // DATE HELPER
  // ============================================================

  DateTime _parseDateTime(
      dynamic value,
      DateTime fallback,
      ) {
    if (value == null) {
      return fallback;
    }

    try {
      return DateTime.parse(
        value.toString(),
      );
    } catch (_) {
      return fallback;
    }
  }

  // ============================================================
  // RESET DISPOSAL HISTORY
  // ============================================================

  Future<void> resetDisposalHistory() async {
    try {
      await _supabase
          .from('disposal_history')
          .delete()
          .neq('id', '00000000-0000-0000-0000-000000000000');
    } catch (e) {
      throw Exception(
        'Failed to reset disposal history: $e',
      );
    }
  }

  // ============================================================
  // UPDATE BIN STATUS
  // ============================================================

  Future<void> updateBinStatus({
    required String binId,
    required String status,
  }) async {
    try {
      await _supabase
          .from('bins')
          .update({
        'status': status,
      })
          .eq('id', binId);
    } catch (e) {
      throw Exception(
        'Failed to update bin status: $e',
      );
    }
  }

  // ============================================================
  // DELETE ALL BINS
  // ============================================================

  Future<void> deleteAllBins() async {
    try {
      await _supabase
          .from('bins')
          .delete()
          .neq('id', '00000000-0000-0000-0000-000000000000');
    } catch (e) {
      throw Exception(
        'Failed to delete bins: $e',
      );
    }
  }
}