/// Firebase implementation of [IBloodRequestRepository].
/// Wraps Cloud Firestore donor_requests collection.

import 'package:cloud_firestore/cloud_firestore.dart';
import '../i_blood_request_repository.dart';
import '../../models/blood_request_model.dart';

class FirebaseBloodRequestRepository implements IBloodRequestRepository {
  final FirebaseFirestore _firestore;

  FirebaseBloodRequestRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col => _firestore.collection('donor_requests');

  @override
  Future<String> createRequest(BloodRequestModel request) async {
    final docRef = await _col.add(request.toFirestore());
    return docRef.id;
  }

  @override
  Future<BloodRequestModel?> getRequestById(String requestId) async {
    final doc = await _col.doc(requestId).get();
    if (!doc.exists) return null;
    return BloodRequestModel.fromFirestore(requestId, doc.data() ?? {});
  }

  @override
  Future<List<BloodRequestModel>> getAllRequests() async {
    final snap = await _col.orderBy('requestedAt', descending: true).get();
    return snap.docs
        .map((doc) => BloodRequestModel.fromFirestore(doc.id, doc.data()))
        .toList();
  }

  @override
  Future<List<BloodRequestModel>> getRequestsForDonor(String donorEmail) async {
    final snap = await _col
        .where('donorEmail', isEqualTo: donorEmail)
        .orderBy('requestedAt', descending: true)
        .get();
    return snap.docs
        .map((doc) => BloodRequestModel.fromFirestore(doc.id, doc.data()))
        .toList();
  }

  @override
  Future<List<BloodRequestModel>> getRequestsForRecipient(String recipientEmail) async {
    final snap = await _col
        .where('recipientEmail', isEqualTo: recipientEmail)
        .orderBy('requestedAt', descending: true)
        .get();
    return snap.docs
        .map((doc) => BloodRequestModel.fromFirestore(doc.id, doc.data()))
        .toList();
  }

  @override
  Future<List<BloodRequestModel>> getPendingRequests() async {
    return getRequestsByStatus('pending');
  }

  @override
  Future<List<BloodRequestModel>> getRequestsByStatus(String status) async {
    final snap = await _col
        .where('status', isEqualTo: status)
        .orderBy('requestedAt', descending: true)
        .get();
    return snap.docs
        .map((doc) => BloodRequestModel.fromFirestore(doc.id, doc.data()))
        .toList();
  }

  @override
  Future<List<BloodRequestModel>> getRequestsByType(String type) async {
    final snap = await _col
        .where('type', isEqualTo: type)
        .orderBy('requestedAt', descending: true)
        .get();
    return snap.docs
        .map((doc) => BloodRequestModel.fromFirestore(doc.id, doc.data()))
        .toList();
  }

  @override
  Future<void> updateRequestStatus(String requestId, String status, {String? responseMessage}) async {
    final updates = <String, dynamic>{
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (responseMessage != null) {
      updates['responseMessage'] = responseMessage;
    }
    if (status == 'approved' || status == 'rejected') {
      updates['respondedAt'] = FieldValue.serverTimestamp();
    }
    await _col.doc(requestId).update(updates);
  }

  @override
  Future<void> updateRequest(String requestId, Map<String, dynamic> updates) async {
    updates['updatedAt'] = FieldValue.serverTimestamp();
    await _col.doc(requestId).update(updates);
  }

  @override
  Future<void> deleteRequest(String requestId) async {
    await _col.doc(requestId).delete();
  }

  @override
  Future<int> getPendingRequestsCount() async {
    final snap = await _col.where('status', isEqualTo: 'pending').count().get();
    return snap.count ?? 0;
  }

  @override
  Future<bool> hasApprovedDonorAccess(String requesterEmail, String donorEmail) async {
    final snap = await _col
        .where('type', isEqualTo: 'donor_access_request')
        .where('requesterEmail', isEqualTo: requesterEmail)
        .where('donorEmail', isEqualTo: donorEmail)
        .where('status', isEqualTo: 'approved')
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }
}
