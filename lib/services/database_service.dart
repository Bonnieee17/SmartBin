import 'package:supabase_flutter/supabase_flutter.dart';

class DatabaseService {
  final _supabase = Supabase.instance.client;

  // --- REWARDS ---
  Future<List<Map<String, dynamic>>> getRewards() async {
    return await _supabase.from('rewards').select().order('points_required');
  }

  // --- WASTE TYPES ---
  Future<List<Map<String, dynamic>>> getWasteTypes() async {
    return await _supabase.from('waste_types').select();
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

  // --- DISPOSAL / POINTS ---
  Future<void> recordDisposal({
    required String userId,
    required String binId,
    required String wasteType,
    required double weight,
    required int points,
  }) async {
    // 1. Record the transaction
    await _supabase.from('disposal_history').insert({
      'user_id': userId,
      'bin_id': binId,
      'waste_type': wasteType,
      'weight_kg': weight,
      'points_earned': points,
    });

    // 2. Update user profile points
    final profile = await _supabase
        .from('users')
        .select('total_points')
        .eq('id', userId)
        .single();
    
    int currentPoints = profile['total_points'] ?? 0;
    
    await _supabase.from('users').update({
      'total_points': currentPoints + points,
    }).eq('id', userId);
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

  // --- REDEEM VOUCHER ---
  Future<void> redeemVoucher({
    required String userId,
    required int pointsCost,
    required String rewardName,
  }) async {
    // 1. Get current points
    final profile = await _supabase
        .from('users')
        .select('total_points')
        .eq('id', userId)
        .single();
    
    int currentPoints = profile['total_points'] ?? 0;

    if (currentPoints < pointsCost) {
      throw Exception("Insufficient Eco Points. You need $pointsCost pts.");
    }

    // 2. Deduct points
    await _supabase.from('users').update({
      'total_points': currentPoints - pointsCost,
    }).eq('id', userId);

    // 3. Log the redemption (using disposal_history for now or a new table if preferred)
    // We'll use a negative value in disposal_history to represent redemption if the schema allows, 
    // but better to just update points for now to avoid breaking stats.
  }
}
