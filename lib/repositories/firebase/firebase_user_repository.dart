/// Firebase implementation of [IUserRepository].
/// Wraps Cloud Firestore user collection operations.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../i_user_repository.dart';
import '../../models/user_model.dart';

class FirebaseUserRepository implements IUserRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  FirebaseUserRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _usersCol => _firestore.collection('users');

  @override
  Future<UserModel?> getUserById(String userId) async {
    final doc = await _usersCol.doc(userId).get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(userId, doc.data() ?? {});
  }

  @override
  Future<UserModel?> getCurrentUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return getUserById(user.uid);
  }

  @override
  Future<void> saveUser(UserModel user) async {
    await _usersCol.doc(user.id).set(user.toFirestore());
  }

  @override
  Future<void> updateUser(String userId, Map<String, dynamic> updates) async {
    await _usersCol.doc(userId).update(updates);
  }

  @override
  Future<void> deleteUser(String userId) async {
    await _usersCol.doc(userId).delete();
  }

  @override
  Future<List<UserModel>> getAllUsers() async {
    final snap = await _usersCol.get();
    return snap.docs
        .map((doc) => UserModel.fromFirestore(doc.id, doc.data()))
        .toList();
  }

  @override
  Future<List<UserModel>> getUsersByRole(String role) async {
    final snap = await _usersCol.where('role', isEqualTo: role).get();
    return snap.docs
        .map((doc) => UserModel.fromFirestore(doc.id, doc.data()))
        .toList();
  }

  @override
  Future<List<UserModel>> getUsersByBloodGroup(String bloodGroup) async {
    final snap = await _usersCol.where('bloodGroup', isEqualTo: bloodGroup).get();
    return snap.docs
        .map((doc) => UserModel.fromFirestore(doc.id, doc.data()))
        .toList();
  }

  @override
  Future<List<UserModel>> searchUsers({
    String? role,
    String? bloodGroup,
    String? location,
    bool? approved,
    String? nameQuery,
  }) async {
    Query<Map<String, dynamic>> query = _usersCol;

    if (role != null) {
      query = query.where('role', isEqualTo: role);
    }
    if (bloodGroup != null) {
      query = query.where('bloodGroup', isEqualTo: bloodGroup);
    }
    if (approved != null) {
      query = query.where('approved', isEqualTo: approved);
    }

    final snap = await query.get();
    var results = snap.docs
        .map((doc) => UserModel.fromFirestore(doc.id, doc.data()))
        .toList();

    // Client-side filtering for location and name (Firestore doesn't support text search natively)
    if (location != null && location.isNotEmpty) {
      results = results
          .where((u) => u.location.toLowerCase().contains(location.toLowerCase()))
          .toList();
    }
    if (nameQuery != null && nameQuery.isNotEmpty) {
      results = results
          .where((u) => u.name.toLowerCase().contains(nameQuery.toLowerCase()))
          .toList();
    }

    return results;
  }

  @override
  Future<int> getUserCountByRole(String role) async {
    final snap = await _usersCol.where('role', isEqualTo: role).count().get();
    return snap.count ?? 0;
  }

  @override
  Future<Map<String, int>> getBloodGroupDistribution() async {
    final snap = await _usersCol.get();
    final distribution = <String, int>{};
    for (final doc in snap.docs) {
      final bg = (doc.data()['bloodGroup'] ?? '').toString();
      if (bg.isNotEmpty) {
        distribution[bg] = (distribution[bg] ?? 0) + 1;
      }
    }
    return distribution;
  }

  @override
  Future<void> approveUser(String userId) async {
    await _usersCol.doc(userId).update({'approved': true});
  }

  @override
  Future<void> updateVerificationStatus(String userId, String status) async {
    await _usersCol.doc(userId).update({'verificationStatus': status});
  }

  @override
  Future<void> setCooldown(String userId, DateTime? until) async {
    if (until == null) {
      await _usersCol.doc(userId).update({'cooldownUntil': FieldValue.delete()});
    } else {
      await _usersCol.doc(userId).update({'cooldownUntil': until.toIso8601String()});
    }
  }
}
