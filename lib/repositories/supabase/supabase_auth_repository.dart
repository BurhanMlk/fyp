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
        .maybeSingle();

    if (data != null) {
      return UserModel.fromJson(Map<String, dynamic>.from(data));
    }
    return UserModel(
      id: user.id,
      name: user.userMetadata?['name'] ?? '',
      email: user.email ?? email,
      contact: '',
      bloodGroup: '',
      role: 'donor',
      location: '',
    );
  }

  @override
  Future<UserModel?> signInWithGoogle() async {
    final success = await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'com.burhan_blood://oauth-callback',
    );
    if (!success) return null;

    final user = _client.auth.currentUser;
    if (user == null) return null;

    // Check if user profile exists
    final data = await _client
        .from('users')
        .select()
        .eq('auth_id', user.id)
        .maybeSingle();

    if (data != null) {
      return UserModel.fromJson(Map<String, dynamic>.from(data));
    }

    // Create new user profile for Google sign-in
    final newUser = UserModel(
      id: user.id,
      name: user.userMetadata?['full_name'] ?? user.email?.split('@').first ?? '',
      email: user.email ?? '',
      contact: '',
      bloodGroup: '',
      role: 'donor',
      location: '',
    );
    await _client.from('users').insert({
      'auth_id': user.id,
      'name': newUser.name,
      'email': newUser.email,
      'contact': newUser.contact,
      'blood_group': newUser.bloodGroup,
      'role': newUser.role,
      'location': newUser.location,
      'approved': false,
      'is_donor': true,
      'verification_status': 'not_uploaded',
      'created_at': DateTime.now().toIso8601String(),
    });
    return newUser;
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
