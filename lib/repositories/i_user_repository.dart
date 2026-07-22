/// Abstract repository interface for user data operations.
/// Implementations: [FirebaseUserRepository], [SupabaseUserRepository]

import '../models/user_model.dart';

abstract class IUserRepository {
  /// Get a single user by ID
  Future<UserModel?> getUserById(String userId);

  /// Get the current authenticated user's profile
  Future<UserModel?> getCurrentUserProfile();

  /// Create or update a user profile
  Future<void> saveUser(UserModel user);

  /// Update specific fields of a user
  Future<void> updateUser(String userId, Map<String, dynamic> updates);

  /// Delete a user
  Future<void> deleteUser(String userId);

  /// Get all users
  Future<List<UserModel>> getAllUsers();

  /// Get users filtered by role ('donor', 'recipient', etc.)
  Future<List<UserModel>> getUsersByRole(String role);

  /// Get users filtered by blood group
  Future<List<UserModel>> getUsersByBloodGroup(String bloodGroup);

  /// Get users filtered by multiple criteria
  Future<List<UserModel>> searchUsers({
    String? role,
    String? bloodGroup,
    String? location,
    bool? approved,
    String? nameQuery,
  });

  /// Get total count of users by role
  Future<int> getUserCountByRole(String role);

  /// Get blood group distribution (group -> count)
  Future<Map<String, int>> getBloodGroupDistribution();

  /// Approve a user (for admin)
  Future<void> approveUser(String userId);

  /// Update verification status
  Future<void> updateVerificationStatus(String userId, String status);

  /// Update cooldown until date
  Future<void> setCooldown(String userId, DateTime? until);
}
