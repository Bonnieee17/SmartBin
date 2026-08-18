import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  SupabaseClient get supabase => _supabase;

  // Sign Up using Student ID (maps to fake email internally)
  Future<AuthResponse> signUp({
    required String studentId,
    required String password,
    required Map<String, dynamic> metadata,
  }) async {
    // Internally use Student ID as the email to satisfy Supabase
    final email = "$studentId@smartbin.com";
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
      data: metadata,
    );

    if (response.user != null) {
      // Create a row in the public.users table for this user
      await _supabase.from('users').insert({
        'id': response.user!.id,
        'full_name': metadata['full_name'],
        'student_id': studentId,
        'role': metadata['role'] ?? 'user',
        'total_points': 0,
        'created_at': DateTime.now().toIso8601String(),
      });
    }
    
    return response;
  }

  // Sign In using Student ID
  Future<AuthResponse> signIn({
    required String studentId,
    required String password,
  }) async {
    final email = "$studentId@smartbin.com";
    final response = await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );

    if (response.user != null) {
      // Ensure a public.users row exists (in case table was reset)
      final existing = await _supabase.from('users').select().eq('id', response.user!.id).maybeSingle();
      if (existing == null) {
        await _supabase.from('users').insert({
          'id': response.user!.id,
          'full_name': response.user!.userMetadata?['full_name'] ?? 'User',
          'student_id': studentId,
          'role': response.user!.userMetadata?['role'] ?? 'user',
          'total_points': 0,
        });
      }
    }
    
    return response;
  }

  // Sign Out and clear all session data
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  // Get Current User
  User? get currentUser => _supabase.auth.currentUser;
}
