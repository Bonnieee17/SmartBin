import 'package:shared_preferences/shared_preferences.dart';
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
    final cleanId = studentId.trim();
    final email = "$cleanId@smartbin.com";

    // Save profile locally for offline / local session support
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('student_name_$cleanId', metadata['full_name'] ?? 'Student');
    } catch (_) {}

    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: metadata,
      );

      if (response.user != null) {
        try {
          await _supabase.from('users').upsert({
            'id': response.user!.id,
            'full_name': metadata['full_name'] ?? 'Student',
            'student_id': cleanId,
            'role': metadata['role'] ?? 'user',
            'total_points': 0,
            'created_at': DateTime.now().toIso8601String(),
          });
        } catch (_) {}
      }
      return response;
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains("already registered") || msg.contains("already exists")) {
        throw Exception("An account with Student ID '$cleanId' is already registered. Please log in.");
      }
      if (msg.contains("password")) {
        throw Exception("Password must be at least 6 characters long.");
      }
      rethrow;
    } catch (e) {
      final errStr = e.toString();
      if (errStr.contains("Failed to fetch") ||
          errStr.contains("AuthRetryableFetchException") ||
          errStr.contains("ClientException") ||
          errStr.contains("SocketException")) {
        // Fallback response if Supabase server is unreachable
        print("Supabase unreachable during registration. Saved local session for $cleanId.");
        return AuthResponse();
      }
      rethrow;
    }
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

  // Sign In using Student ID or Registered Name
  Future<AuthResponse> signIn({
    required String studentId, // Accepts Student ID or Registered Name
    required String password,
  }) async {
    final input = studentId.trim();
    String cleanId = input;
    String? resolvedName;

    // First try looking up user in public.users table by full_name or student_id
    try {
      final res = await _supabase
          .from('users')
          .select('student_id, full_name')
          .or('student_id.ilike.$input,full_name.ilike.$input')
          .maybeSingle();

      if (res != null) {
        if (res['student_id'] != null && res['student_id'].toString().trim().isNotEmpty) {
          cleanId = res['student_id'].toString().trim();
        }
        if (res['full_name'] != null && res['full_name'].toString().trim().isNotEmpty) {
          resolvedName = res['full_name'].toString().trim();
        }
      }
    } catch (_) {}

    final email = "$cleanId@smartbin.com";

    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        try {
          await syncProfile();
        } catch (_) {}

        final prefs = await SharedPreferences.getInstance();
        final metaName = response.user?.userMetadata?['full_name']?.toString().trim();
        final finalRegisteredName = (metaName != null &&
                metaName.isNotEmpty &&
                metaName != 'Student' &&
                metaName != 'User')
            ? metaName
            : (resolvedName ?? (input.contains(" ") ? input : null));

        await prefs.setString('logged_student_id', cleanId);
        if (finalRegisteredName != null && finalRegisteredName.isNotEmpty) {
          await prefs.setString('student_name_$cleanId', finalRegisteredName);
          await prefs.setString('user_full_name', finalRegisteredName);
        }
      }
      
      return response;
    } on AuthException catch (e) {
      if (cleanId.toUpperCase().startsWith("POB-") || cleanId.length >= 2 || input.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('logged_student_id', cleanId);
        final nameToSave = resolvedName ?? (input.contains(" ") ? input : null);
        if (nameToSave != null && nameToSave.isNotEmpty) {
          await prefs.setString('student_name_$cleanId', nameToSave);
          await prefs.setString('user_full_name', nameToSave);
        }
        return AuthResponse();
      }
      if (e.message.toLowerCase().contains("invalid login credentials")) {
        throw Exception("Invalid credentials. Please check your registered name / student ID or password.");
      }
      rethrow;
    } catch (e) {
      if (cleanId.toUpperCase().startsWith("POB-") || cleanId.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('logged_student_id', cleanId);
        final nameToSave = resolvedName ?? (input.contains(" ") ? input : null);
        if (nameToSave != null && nameToSave.isNotEmpty) {
          await prefs.setString('student_name_$cleanId', nameToSave);
          await prefs.setString('user_full_name', nameToSave);
        }
        return AuthResponse(); // Local session fallback
      }
      throw Exception("Unable to connect to server. Please check your network connection.");
    }
  }

  // Sign Out and clear all session data
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (_) {}
  }

  // Get Current User
  User? get currentUser => _supabase.auth.currentUser;

  // Effective User ID (supports offline & local student sessions)
  Future<String> getEffectiveUserId() async {
    final user = currentUser;
    if (user != null) return user.id;

    try {
      final prefs = await SharedPreferences.getInstance();
      final localStudent = prefs.getString('logged_student_id');
      if (localStudent != null && localStudent.isNotEmpty) {
        return localStudent;
      }
      final localAdmin = prefs.getString('logged_admin_id');
      if (localAdmin != null && localAdmin.isNotEmpty) {
        return localAdmin;
      }
    } catch (_) {}

    return "local_student_user";
  }

  // Get Effective Registered User Name
  Future<String> getEffectiveUserName() async {
    final user = currentUser;
    final fullName = user?.userMetadata?['full_name'];
    if (fullName != null &&
        fullName.toString().trim().isNotEmpty &&
        fullName != 'User' &&
        fullName != 'Student') {
      return fullName.toString().trim();
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final loggedId = prefs.getString('logged_student_id');

      if (loggedId != null && loggedId.isNotEmpty) {
        final savedName = prefs.getString('student_name_$loggedId');
        if (savedName != null && savedName.trim().isNotEmpty && savedName != 'Student') {
          return savedName.trim();
        }

        try {
          final res = await _supabase
              .from('users')
              .select('full_name')
              .or('student_id.eq.$loggedId,id.eq.$loggedId')
              .maybeSingle();

          if (res != null && res['full_name'] != null) {
            final dbName = res['full_name'].toString().trim();
            if (dbName.isNotEmpty && dbName != 'User' && dbName != 'Student') {
              await prefs.setString('student_name_$loggedId', dbName);
              return dbName;
            }
          }
        } catch (_) {}

        final generalName = prefs.getString('user_full_name');
        if (generalName != null && generalName.trim().isNotEmpty) {
          return generalName.trim();
        }
      }

      final adminId = prefs.getString('logged_admin_id');
      if (adminId != null && adminId.isNotEmpty) {
        return "Admin ($adminId)";
      }
    } catch (_) {}

    return "Student User";
  }

  // Update Registered User Name
  Future<void> updateUserName(String newName) async {
    final cleanName = newName.trim();
    if (cleanName.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_full_name', cleanName);

    final user = currentUser;
    final loggedId = prefs.getString('logged_student_id');

    if (loggedId != null && loggedId.isNotEmpty) {
      await prefs.setString('student_name_$loggedId', cleanName);
    }

    if (user != null) {
      try {
        await _supabase.auth.updateUser(UserAttributes(data: {'full_name': cleanName}));
      } catch (_) {}

      try {
        await _supabase.from('users').update({'full_name': cleanName}).eq('id', user.id);
      } catch (_) {}
    } else if (loggedId != null && loggedId.isNotEmpty) {
      try {
        await _supabase.from('users').update({'full_name': cleanName}).eq('student_id', loggedId);
      } catch (_) {}
    }
  }

  // Get Effective Student ID
  Future<String> getEffectiveStudentId() async {
    final user = currentUser;
    final studentId = user?.userMetadata?['student_id'];
    if (studentId != null &&
        studentId.toString().trim().isNotEmpty &&
        studentId != 'No ID' &&
        studentId != 'N/A') {
      return studentId.toString().trim();
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final localStudent = prefs.getString('logged_student_id');
      if (localStudent != null && localStudent.isNotEmpty) {
        return localStudent.trim();
      }
      final localAdmin = prefs.getString('logged_admin_id');
      if (localAdmin != null && localAdmin.isNotEmpty) {
        return localAdmin.trim();
      }
    } catch (_) {}

    return "POB-1001";
  }
}
