import 'dart:convert';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/voucher_model.dart';

class DatabaseService {
  final _supabase = Supabase.instance.client;

  // --- REWARDS ---
  Future<List<Map<String, dynamic>>> getRewards() async {
    try {
      final res = await _supabase.from('rewards').select().order('points_required');
      if (res.isNotEmpty) return res;
    } catch (_) {}

    return [
      {'id': '1', 'reward_name': 'Printing Credit (₱10)', 'points_required': 100},
      {'id': '2', 'reward_name': 'Notebook & Pen Set', 'points_required': 250},
      {'id': '3', 'reward_name': 'School Canteen Meal Coupon', 'points_required': 500},
      {'id': '4', 'reward_name': 'Eco Bottle', 'points_required': 750},
    ];
  }

  // --- WASTE TYPES ---
  Future<List<Map<String, dynamic>>> getWasteTypes() async {
    try {
      final res = await _supabase.from('waste_types').select();
      if (res.isNotEmpty) return res;
    } catch (_) {}

    return [
      {'id': '1', 'waste_name': 'PET Plastic Bottle (500ml)', 'points': 10},
      {'id': '2', 'waste_name': 'Aluminum Can', 'points': 15},
      {'id': '3', 'waste_name': 'Paper & Cardboard', 'points': 5},
      {'id': '4', 'waste_name': 'Glass Bottle', 'points': 20},
    ];
  }

  // --- BADGES ---
  Future<List<Map<String, dynamic>>> getBadges() async {
    return await _supabase.from('badges').select().order('points_required');
  }

  // --- BINS ---
  Stream<List<Map<String, dynamic>>> getBinsStream() {
    return _supabase.from('bins').stream(primaryKey: ['id']);
  }

  Future<List<Map<String, dynamic>>> getBins() async {
    return await _supabase.from('bins').select();
  }

  // --- ADMIN / USERS ---
  Stream<List<Map<String, dynamic>>> getUsersStream() {
    return _supabase.from('users').stream(primaryKey: ['id']).order('total_points', ascending: false);
  }

  Future<List<Map<String, dynamic>>> getStudents() async {
    final response = await _supabase
        .from('users')
        .select()
        .neq('role', 'admin')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Stream<List<Map<String, dynamic>>> getRecentActivityStream() {
    // This streams the latest disposals across the entire app for the admin
    return _supabase
        .from('disposal_history')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .limit(10);
  }

  Stream<List<Map<String, dynamic>>> getDisposalHistoryStream() {
    return _supabase.from('disposal_history').stream(primaryKey: ['id']);
  }

  // --- REWARD SESSIONS ---
  Future<String> createRewardSession({
    required String binId,
    required int points,
    required String wasteType,
  }) async {
    final token = _generateRandomToken();
    final expiresAt = DateTime.now().add(const Duration(seconds: 30)).toIso8601String();

    await _supabase.from('reward_sessions').insert({
      'bin_id': binId,
      'points': points,
      'waste_type': wasteType,
      'token': token,
      'expires_at': expiresAt,
    });
    
    return token;
  }

  Future<Map<String, dynamic>> claimRewardByToken(String token, String userId) async {
    // 1. Find the token
    final sessionResponse = await _supabase
        .from('reward_sessions')
        .select()
        .eq('token', token)
        .maybeSingle();

    if (sessionResponse == null) {
      throw Exception("Invalid token.");
    }

    if (sessionResponse['is_claimed'] == true) {
      throw Exception("This reward has already been claimed.");
    }

    final expiresAt = DateTime.parse(sessionResponse['expires_at']);
    if (DateTime.now().isAfter(expiresAt)) {
      throw Exception("Token expired.");
    }

    // 2. Mark as claimed
    await _supabase.from('reward_sessions').update({
      'is_claimed': true,
      'claimed_by': userId,
    }).eq('token', token);

    // 3. Add points to user
    final points = sessionResponse['points'];
    final wasteType = sessionResponse['waste_type'];
    final binId = sessionResponse['bin_id'];

    await recordDisposal(
      userId: userId,
      binId: binId,
      wasteType: wasteType,
      weight: 0.0,
      points: points,
    );

    return sessionResponse;
  }

  // --- OFFLINE / ONLINE POINTS MANAGEMENT ---
  Future<int> getUserPoints(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    int localPts = prefs.getInt('local_points_$userId') ?? 100;

    try {
      final res = await _supabase
          .from('users')
          .select('total_points')
          .eq('id', userId)
          .maybeSingle();

      if (res != null && res['total_points'] != null) {
        int remotePts = int.tryParse(res['total_points'].toString()) ?? localPts;
        await prefs.setInt('local_points_$userId', remotePts);
        return remotePts;
      }
    } catch (_) {}

    return localPts;
  }

  Future<int> addPointsLocallyAndRemote(String userId, int pointsToAdd) async {
    final current = await getUserPoints(userId);
    final newTotal = current + pointsToAdd;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('local_points_$userId', newTotal);

    try {
      await _supabase.from('users').update({
        'total_points': newTotal,
      }).eq('id', userId);
    } catch (_) {}

    return newTotal;
  }

  Future<int> deductPointsLocallyAndRemote(String userId, int pointsToDeduct) async {
    final current = await getUserPoints(userId);
    if (current < pointsToDeduct) {
      throw Exception("Insufficient Eco Points. You need $pointsToDeduct pts (You have $current pts).");
    }
    final newTotal = current - pointsToDeduct;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('local_points_$userId', newTotal);

    try {
      await _supabase.from('users').update({
        'total_points': newTotal,
      }).eq('id', userId);
    } catch (_) {}

    return newTotal;
  }

  // --- DISPOSAL / POINTS ---
  Future<void> recordDisposal({
    required String userId,
    required String binId,
    required String wasteType,
    required double weight,
    required int points,
  }) async {
    // 1. Add points locally and remotely
    await addPointsLocallyAndRemote(userId, points);

    // 2. Save record to local disposal history
    final record = {
      'id': "disp_${DateTime.now().millisecondsSinceEpoch}",
      'user_id': userId,
      'bin_id': binId,
      'waste_type': wasteType,
      'weight_kg': weight,
      'points_earned': points,
      'created_at': DateTime.now().toIso8601String(),
    };
    await _saveDisposalToLocal(userId, record);

    // 3. Try remote Supabase sync
    try {
      await _supabase.from('disposal_history').insert({
        'user_id': userId,
        'bin_id': binId,
        'waste_type': wasteType,
        'weight_kg': weight,
        'points_earned': points,
      });
    } catch (_) {}
  }

  Future<void> _saveDisposalToLocal(String userId, Map<String, dynamic> record) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('local_history_$userId') ?? [];
    list.insert(0, jsonEncode(record));
    await prefs.setStringList('local_history_$userId', list);
  }

  Future<List<Map<String, dynamic>>> getLocalDisposalHistory(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('local_history_$userId') ?? [];
    List<Map<String, dynamic>> result = [];
    for (var item in list) {
      try {
        result.add(jsonDecode(item));
      } catch (_) {}
    }

    try {
      final res = await _supabase
          .from('disposal_history')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      for (var item in res) {
        final map = Map<String, dynamic>.from(item);
        if (!result.any((r) => r['id'] == map['id'])) {
          result.add(map);
        }
      }
    } catch (_) {}

    result.sort((a, b) {
      final tA = DateTime.tryParse(a['created_at'].toString()) ?? DateTime.now();
      final tB = DateTime.tryParse(b['created_at'].toString()) ?? DateTime.now();
      return tB.compareTo(tA);
    });

    return result;
  }

  Stream<List<Map<String, dynamic>>> getLatestUnclaimedSession(String binId) {
    return _supabase
        .from('reward_sessions')
        .stream(primaryKey: ['id'])
        .eq('bin_id', binId)
        .order('created_at', ascending: false)
        .limit(1);
  }

  String _generateRandomToken() {
    final random = math.Random();
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(16, (index) => chars[random.nextInt(chars.length)]).join();
  }

  // --- VOUCHERS ---
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

  // --- SMARTBIN DIGITAL VOUCHER PASS (PSITS OFFICE) ---
  Future<VoucherModel> generateDigitalVoucherPass({
    required String userId,
    required int pointsCost,
    required String rewardName,
    String? userName,
    int validityDays = 3,
  }) async {
    // 1. Deduct points locally & remotely
    await deductPointsLocallyAndRemote(userId, pointsCost);

    // 2. Create unique SmartBin Digital Identifier (e.g. SB-PSITS-89F0A1)
    final codeHash = _generateRandomToken().substring(0, 6).toUpperCase();
    final voucherCode = "SB-PSITS-$codeHash";
    final now = DateTime.now();
    final expires = now.add(Duration(days: validityDays));

    final voucher = VoucherModel(
      id: "vch_${now.millisecondsSinceEpoch}_$codeHash",
      code: voucherCode,
      userId: userId,
      userName: userName ?? 'Student',
      rewardName: rewardName,
      pointsCost: pointsCost,
      claimLocation: "PSITS Office",
      createdAt: now,
      expiresAt: expires,
      rawStatus: "pending",
    );

    // 4. Try storing in Supabase
    try {
      await _supabase.from('vouchers').insert({
        'user_id': userId,
        'reward_name': rewardName,
        'points_cost': pointsCost,
        'code': voucherCode,
        'claim_location': "PSITS Office",
        'status': "pending",
        'created_at': now.toIso8601String(),
        'expires_at': expires.toIso8601String(),
      });
    } catch (_) {
      try {
        await _supabase.from('vouchers').insert({
          'user_id': userId,
          'reward_name': rewardName,
          'points_cost': pointsCost,
          'code': voucherCode,
        });
      } catch (_) {}
    }

    // 5. Save to local storage backup
    await _saveVoucherToLocal(voucher);

    return voucher;
  }

  Future<List<VoucherModel>> getUserVouchers(String userId) async {
    List<VoucherModel> list = [];

    // 1. Try Supabase
    try {
      final res = await _supabase
          .from('vouchers')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      for (final item in res) {
        list.add(VoucherModel.fromJson(Map<String, dynamic>.from(item)));
      }
    } catch (_) {}

    // 2. Load from local storage backup and merge
    final localList = await _getVouchersFromLocal();
    final userLocal = localList.where((v) => v.userId == userId).toList();

    for (final loc in userLocal) {
      if (!list.any((v) => v.code == loc.code || v.id == loc.id)) {
        list.add(loc);
      }
    }

    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<VoucherModel> claimVoucherInOffice(String voucherCodeOrId) async {
    final cleanCode = voucherCodeOrId.trim().toUpperCase();

    VoucherModel? targetVoucher;

    // Check Supabase
    try {
      final res = await _supabase
          .from('vouchers')
          .select()
          .or('code.eq.$cleanCode,id.eq.$cleanCode')
          .maybeSingle();

      if (res != null) {
        targetVoucher = VoucherModel.fromJson(Map<String, dynamic>.from(res));
      }
    } catch (_) {}

    if (targetVoucher == null) {
      final localList = await _getVouchersFromLocal();
      try {
        targetVoucher = localList.firstWhere(
            (v) => v.code.toUpperCase() == cleanCode || v.id.toUpperCase() == cleanCode);
      } catch (_) {}
    }

    if (targetVoucher == null) {
      throw Exception("Voucher ticket '$cleanCode' not found. Please check the identifier.");
    }

    if (targetVoucher.isClaimed) {
      throw Exception("This voucher was ALREADY claimed at the PSITS Office.");
    }

    if (targetVoucher.isExpired) {
      throw Exception("This voucher has EXPIRED. The 3-day validity period has passed.");
    }

    final now = DateTime.now();
    final updatedVoucher = VoucherModel(
      id: targetVoucher.id,
      code: targetVoucher.code,
      userId: targetVoucher.userId,
      userName: targetVoucher.userName,
      rewardName: targetVoucher.rewardName,
      pointsCost: targetVoucher.pointsCost,
      claimLocation: targetVoucher.claimLocation,
      createdAt: targetVoucher.createdAt,
      expiresAt: targetVoucher.expiresAt,
      claimedAt: now,
      rawStatus: "claimed",
    );

    try {
      await _supabase.from('vouchers').update({
        'status': 'claimed',
        'claimed_at': now.toIso8601String(),
      }).or('code.eq.$cleanCode,id.eq.$cleanCode');
    } catch (_) {}

    await _saveVoucherToLocal(updatedVoucher);

    return updatedVoucher;
  }

  Future<List<VoucherModel>> getAllVouchers() async {
    List<VoucherModel> list = [];
    try {
      final res = await _supabase
          .from('vouchers')
          .select('*, users(full_name)')
          .order('created_at', ascending: false);

      for (final item in res) {
        list.add(VoucherModel.fromJson(Map<String, dynamic>.from(item)));
      }
    } catch (_) {}

    final localList = await _getVouchersFromLocal();
    for (final loc in localList) {
      if (!list.any((v) => v.code == loc.code || v.id == loc.id)) {
        list.add(loc);
      }
    }

    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<void> _saveVoucherToLocal(VoucherModel voucher) async {
    final prefs = await SharedPreferences.getInstance();
    final existingJson = prefs.getStringList('local_user_vouchers') ?? [];
    List<Map<String, dynamic>> mapList = [];
    for (var str in existingJson) {
      try {
        mapList.add(jsonDecode(str));
      } catch (_) {}
    }

    mapList.removeWhere((m) => m['code'] == voucher.code || m['id'] == voucher.id);
    mapList.add(voucher.toJson());

    final updatedJson = mapList.map((m) => jsonEncode(m)).toList();
    await prefs.setStringList('local_user_vouchers', updatedJson);
  }

  Future<List<VoucherModel>> _getVouchersFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final existingJson = prefs.getStringList('local_user_vouchers') ?? [];
    List<VoucherModel> list = [];
    for (var str in existingJson) {
      try {
        list.add(VoucherModel.fromJson(jsonDecode(str)));
      } catch (_) {}
    }
    return list;
  }

  // --- SYSTEM RESET ---
  Future<void> resetDisposalHistory() async {
    // 1. Delete all history
    await _supabase.from('disposal_history').delete().neq('user_id', '0000'); // Delete all

    // 2. Insert Basis Examples
    final user = _supabase.auth.currentUser;
    if (user != null) {
      await _supabase.from('disposal_history').insert([
        {
          'user_id': user.id,
          'waste_type': 'Plastic Bottle (Recyclable Basis)',
          'weight_kg': 0.5,
          'points_earned': 10,
          'created_at': DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String(),
        },
        {
          'user_id': user.id,
          'waste_type': 'Food Wrapper (Non-Biodegradable Basis)',
          'weight_kg': 0.1,
          'points_earned': 2,
          'created_at': DateTime.now().toIso8601String(),
        }
      ]);
    }
  }

  // --- DELETE ALL BINS ---
  Future<void> updateBinStatus({
    required String binId,
    required String status,
    required String qrData,
    required String color,
  }) async {
    await _supabase.from('bins').upsert({
      'id': binId,
      'status': status,
      'qr_data': qrData,
      'color': color,
      'last_update': DateTime.now().toIso8601String(),
    });
  }

  // --- DELETE ALL BINS ---
  Future<void> deleteAllBins() async {
    await _supabase.from('bins').delete().neq('id', '0000'); // Delete all rows
  }
}
