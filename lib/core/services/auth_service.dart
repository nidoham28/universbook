import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static final AuthService instance = AuthService._internal();
  AuthService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  User? get currentUser => _supabase.auth.currentUser;
  Session? get currentSession => _supabase.auth.currentSession;
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  Future<AuthResponse> signInWithEmail(String email, String password) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<AuthResponse> signUpWithEmail(String email, String password) async {
    return await _supabase.auth.signUp(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  /// Fetches the public.profiles row for the current user.
  /// Returns null if there's no signed-in user or no matching row.
  Future<Map<String, dynamic>?> fetchCurrentProfile() async {
    final user = currentUser;
    if (user == null) return null;

    return _supabase
        .from('profiles')
        .select('username, display_name, avatar_url')
        .eq('id', user.id)
        .maybeSingle();
  }
}