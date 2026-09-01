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
      try {
        // Create a row in the public.users table for this user
        // We use upsert to avoid conflicts if the user already exists in public.users
        await _supabase.from('users').upsert({
          'id': response.user!.id,
          'full_name': metadata['full_name'] ?? 'Student',
          'student_id': studentId,
          'role': metadata['role'] ?? 'user',
          'total_points': 0,
          'created_at': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        print("Error creating public user record: $e");
        // We throw a more descriptive error if RLS or other issues occur
        throw Exception("Account created, but profile setup failed. Please contact admin to verify your Student ID.");
      }
    }
    
    return response;
  }

  // Sync check: Ensure a public.users row exists
  Future<void> syncProfile() async {
    final user = currentUser;
    if (user == null) return;

    try {
      final existing = await _supabase.from('users').select().eq('id', user.id).maybeSingle();
      if (existing == null) {
        await _supabase.from('users').insert({
          'id': user.id,
          'full_name': user.userMetadata?['full_name'] ?? 'Student',
          'student_id': user.userMetadata?['student_id'] ?? 'N/A',
          'role': user.userMetadata?['role'] ?? 'user',
          'total_points': 0,
          'created_at': user.createdAt,
        });
      }
    } catch (e) {
      print("Error syncing public user record: $e");
    }
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
      await syncProfile();
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
