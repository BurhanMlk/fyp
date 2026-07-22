/// Supabase implementation of [IUserRepository].

import 'package:supabase_flutter/supabase_flutter.dart';
import '../i_user_repository.dart';
import '../../models/user_model.dart';

class SupabaseUserRepository implements IUserRepository {
  final SupabaseClient _client;

  SupabaseUserRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  @override
  Future<UserModel?> getUserById(String userId) async {
    try {
      final data = await _client.from('users').select().eq('id', userId).single();
      return UserModel.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<UserModel?> getCurrentUserProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    try {
      final data = await _client.from('users').select().eq('auth_id', user.id).single();
      return UserModel.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveUser(UserModel user) async {
    await _client.from('users').upsert(user.toJson());
  }

  @override
  Future<void> updateUser(String userId, Map<String, dynamic> updates) async {
    await _client.from('users').update(updates).eq('id', userId);
  }

  @override
  Future<void> deleteUser(String userId) async {
    await _client.from('users').delete().eq('id', userId);
  }

  @override
  Future<List<UserModel>> getAllUsers() async {
    final data = await _client.from('users').select();
    return (data as List).map((json) => UserModel.fromJson(json)).toList();
  }

  @override
  Future<List<UserModel>> getUsersByRole(String role) async {
    final data = await _client.from('users').select().eq('role', role);
    return (data as List).map((json) => UserModel.fromJson(json)).toList();
  }

  @override
  Future<List<UserModel>> getUsersByBloodGroup(String bloodGroup) async {
    final data = await _client.from('users').select().eq('blood_group', bloodGroup);
    return (data as List).map((json) => UserModel.fromJson(json)).toList();
  }

  @override
  Future<List<UserModel>> searchUsers({
    String? role,
    String? bloodGroup,
    String? location,
    bool? approved,
    String? nameQuery,
  }) async {
    var query = _client.from('users').select();

    if (role != null) query = query.eq('role', role);
    if (bloodGroup != null) query = query.eq('blood_group', bloodGroup);
    if (approved != null) query = query.eq('approved', approved);
    if (location != null) query = query.ilike('location', '%$location%');
    if (nameQuery != null) query = query.ilike('name', '%$nameQuery%');

    final data = await query;
    return (data as List).map((json) => UserModel.fromJson(json)).toList();
  }

  @override
  Future<int> getUserCountByRole(String role) async {
    final data = await _client
        .from('users')
        .select('id')
        .eq('role', role);
    return (data as List).length;
  }

  @override
  Future<Map<String, int>> getBloodGroupDistribution() async {
    // Use the blood_group_stock view created in the schema
    final data = await _client.from('blood_group_stock').select();
    final distribution = <String, int>{};
    for (final row in (data as List)) {
      distribution[row['blood_group']?.toString() ?? ''] =
          (row['approved_donors'] as int?) ?? 0;
    }
    return distribution;
  }

  @override
  Future<void> approveUser(String userId) async {
    await _client.from('users').update({'approved': true}).eq('id', userId);
  }

  @override
  Future<void> updateVerificationStatus(String userId, String status) async {
    await _client.from('users').update({'verification_status': status}).eq('id', userId);
  }

  @override
  Future<void> setCooldown(String userId, DateTime? until) async {
    await _client.from('users').update({
      'cooldown_until': until?.toIso8601String(),
    }).eq('id', userId);
  }
}
