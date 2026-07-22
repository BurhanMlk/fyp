/// Supabase implementation of [IAuthRepository].
/// Use this when migrating from Firebase to Supabase.
///
/// Prerequisites:
/// 1. Add supabase_flutter to pubspec.yaml
/// 2. Initialize Supabase in main.dart:
///    await Supabase.initialize(url: 'YOUR_SUPABASE_URL', anonKey: 'YOUR_ANON_KEY');
/// 3. Set ServiceLocator provider to BackendProvider.supabase

import 'package:supabase_flutter/supabase_flutter.dart';
import '../i_auth_repository.dart';
import '../../models/user_model.dart';

class SupabaseAuthRepository implements IAuthRepository {
  final SupabaseClient _client;

  SupabaseAuthRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  @override
  String? get currentUserId => _client.auth.currentUser?.id;

  @override
  String? get currentUserEmail => _client.auth.currentUser?.email;

  @override
  Future<UserModel?> signIn(String email, String password) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    final user = response.user;
    if (user == null) return null;

    // Fetch user profile from the users table
    final data = await _client
        .from('users')
        .select()
        .eq('auth_id', user.id)
        .single();

    return UserModel.fromJson(data);
  }

  @override
  Future<UserModel?> signUp(String email, String password) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
    );
    final user = response.user;
    if (user == null) return null;
    return UserModel(
      id: user.id,
      name: '',
      email: user.email ?? email,
      contact: '',
      bloodGroup: '',
      role: 'user',
      location: '',
    );
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    try {
      final data = await _client
          .from('users')
          .select()
          .eq('auth_id', user.id)
          .single();
      return UserModel.fromJson(data);
    } catch (_) {
      return UserModel(
        id: user.id,
        name: '',
        email: user.email ?? '',
        contact: '',
        bloodGroup: '',
        role: 'user',
        location: '',
      );
    }
  }

  @override
  Future<bool> isSignedIn() async {
    return _client.auth.currentUser != null;
  }

  @override
  Stream<UserModel?> authStateChanges() {
    return _client.auth.onAuthStateChange.asyncMap((event) async {
      final session = event.session;
      if (session == null) return null;
      try {
        final data = await _client
            .from('users')
            .select()
            .eq('auth_id', session.user.id)
            .single();
        return UserModel.fromJson(data);
      } catch (_) {
        return UserModel(
          id: session.user.id,
          name: '',
          email: session.user.email ?? '',
          contact: '',
          bloodGroup: '',
          role: 'user',
          location: '',
        );
      }
    });
  }

  @override
  Future<void> deleteAccount() async {
    final user = _client.auth.currentUser;
    if (user != null) {
      await _client.from('users').delete().eq('auth_id', user.id);
      // Supabase doesn't allow client-side user deletion by default;
      // you'd typically call a server-side function for this.
    }
  }
}
