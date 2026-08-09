import 'package:cloud_firestore/cloud_firestore.dart';
import '../i_organization_repository.dart';
import '../../models/organization_model.dart';

class FirebaseOrganizationRepository implements IOrganizationRepository {
  static const String _collection = 'organizations';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Future<String> createOrganization(OrganizationModel org) async {
    final docRef = await _firestore.collection(_collection).add(org.toFirestore());
    return docRef.id;
  }

  @override
  Future<OrganizationModel?> getOrganizationById(String orgId) async {
    final doc = await _firestore.collection(_collection).doc(orgId).get();
    if (!doc.exists) return null;
    return OrganizationModel.fromFirestore(doc.id, doc.data() ?? {});
  }

  @override
  Future<List<OrganizationModel>> getAllOrganizations() async {
    final snap = await _firestore.collection(_collection).orderBy('createdAt', descending: true).get();
    return snap.docs.map((d) => OrganizationModel.fromFirestore(d.id, d.data() ?? {})).toList();
  }

  @override
  Future<List<OrganizationModel>> getOrganizationsByType(String type) async {
    final snap = await _firestore
        .collection(_collection)
        .where('type', isEqualTo: type)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map((d) => OrganizationModel.fromFirestore(d.id, d.data() ?? {})).toList();
  }

  @override
  Future<List<OrganizationModel>> getOrganizationsByStatus(String status) async {
    final snap = await _firestore
        .collection(_collection)
        .where('status', isEqualTo: status)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map((d) => OrganizationModel.fromFirestore(d.id, d.data() ?? {})).toList();
  }

  @override
  Future<List<OrganizationModel>> getSocietiesByUniversity(String universityId) async {
    final snap = await _firestore
        .collection(_collection)
        .where('type', isEqualTo: 'society')
        .where('universityId', isEqualTo: universityId)
        .get();
    return snap.docs.map((d) => OrganizationModel.fromFirestore(d.id, d.data() ?? {})).toList();
  }

  @override
  Future<void> updateOrganization(String orgId, Map<String, dynamic> updates) async {
    updates['updatedAt'] = FieldValue.serverTimestamp();
    await _firestore.collection(_collection).doc(orgId).update(updates);
  }

  @override
  Future<void> approveOrganization(String orgId) async {
    await _firestore.collection(_collection).doc(orgId).update({
      'status': 'active',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> rejectOrganization(String orgId) async {
    await _firestore.collection(_collection).doc(orgId).update({
      'status': 'rejected',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> suspendOrganization(String orgId) async {
    await _firestore.collection(_collection).doc(orgId).update({
      'status': 'suspended',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> activateOrganization(String orgId) async {
    await _firestore.collection(_collection).doc(orgId).update({
      'status': 'active',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> deleteOrganization(String orgId) async {
    await _firestore.collection(_collection).doc(orgId).delete();
  }

  @override
  Future<Map<String, int>> getOrganizationCountByType() async {
    final snap = await _firestore.collection(_collection).get();
    final counts = <String, int>{};
    for (final doc in snap.docs) {
      final type = (doc.data()['type'] ?? 'unknown').toString();
      counts[type] = (counts[type] ?? 0) + 1;
    }
    return counts;
  }

  @override
  Future<int> getPendingApprovalCount() async {
    final snap = await _firestore
        .collection(_collection)
        .where('status', isEqualTo: 'pending')
        .count()
        .get();
    return snap.count ?? 0;
  }

  @override
  Future<List<OrganizationModel>> searchOrganizations(String query) async {
    final lowerQuery = query.toLowerCase();
    final snap = await _firestore.collection(_collection).get();
    return snap.docs
        .map((d) => OrganizationModel.fromFirestore(d.id, d.data() ?? {}))
        .where((org) =>
            org.name.toLowerCase().contains(lowerQuery) ||
            org.email.toLowerCase().contains(lowerQuery) ||
            (org.city?.toLowerCase().contains(lowerQuery) ?? false))
        .toList();
  }

  @override
  Future<OrganizationModel?> getOrganizationByAdminId(String adminId) async {
    final snap = await _firestore
        .collection(_collection)
        .where('adminId', isEqualTo: adminId)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return OrganizationModel.fromFirestore(snap.docs.first.id, snap.docs.first.data() ?? {});
  }
}
