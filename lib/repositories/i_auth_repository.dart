/// Abstract repository interface for authentication operations.
/// Implementations: [FirebaseAuthRepository], [SupabaseAuthRepository]

import '../models/user_model.dart';

abstract class IAuthRepository {
  /// Sign in with email and password
  Future<UserModel?> signIn(String email, String password);

  /// Register a new user with email and password
  Future<UserModel?> signUp(String email, String password);

  /// Sign out the current user
  Future<void> signOut();

  /// Get the currently signed-in user
  Future<UserModel?> getCurrentUser();

  /// Check if a user is currently signed in
  Future<bool> isSignedIn();

  /// Get the current user's auth ID (UID)
  String? get currentUserId;

  /// Get the current user's email
  String? get currentUserEmail;

  /// Stream of auth state changes
  Stream<UserModel?> authStateChanges();

  /// Delete the current user account
  Future<void> deleteAccount();
}
