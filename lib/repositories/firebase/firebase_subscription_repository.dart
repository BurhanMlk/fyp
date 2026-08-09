import 'package:cloud_firestore/cloud_firestore.dart';
import '../i_subscription_repository.dart';
import '../../models/subscription_model.dart';

class FirebaseSubscriptionRepository implements ISubscriptionRepository {
  static const String _collection = 'subscriptions';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Future<String> createSubscription(SubscriptionModel subscription) async {
    final docRef = await _firestore.collection(_collection).add(subscription.toFirestore());
    return docRef.id;
  }

  @override
  Future<SubscriptionModel?> getSubscriptionById(String subId) async {
    final doc = await _firestore.collection(_collection).doc(subId).get();
    if (!doc.exists) return null;
    return SubscriptionModel.fromFirestore(doc.id, doc.data() ?? {});
  }

  @override
  Future<SubscriptionModel?> getActiveSubscriptionForOrg(String orgId) async {
    final snap = await _firestore
        .collection(_collection)
        .where('organizationId', isEqualTo: orgId)
        .where('status', whereIn: ['trial', 'active', 'expiring_soon'])
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return SubscriptionModel.fromFirestore(snap.docs.first.id, snap.docs.first.data());
  }

  @override
  Future<List<SubscriptionModel>> getSubscriptionsForOrg(String orgId) async {
    final snap = await _firestore
        .collection(_collection)
        .where('organizationId', isEqualTo: orgId)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map((d) => SubscriptionModel.fromFirestore(d.id, d.data())).toList();
  }

  @override
  Future<List<SubscriptionModel>> getAllSubscriptions() async {
    final snap = await _firestore
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map((d) => SubscriptionModel.fromFirestore(d.id, d.data())).toList();
  }

  @override
  Future<List<SubscriptionModel>> getSubscriptionsByStatus(String status) async {
    final snap = await _firestore
        .collection(_collection)
        .where('status', isEqualTo: status)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map((d) => SubscriptionModel.fromFirestore(d.id, d.data())).toList();
  }

  @override
  Future<void> updateSubscription(String subId, Map<String, dynamic> updates) async {
    updates['updatedAt'] = FieldValue.serverTimestamp();
    await _firestore.collection(_collection).doc(subId).update(updates);
  }

  @override
  Future<void> cancelSubscription(String subId) async {
    await _firestore.collection(_collection).doc(subId).update({
      'status': 'cancelled',
      'autoRenewal': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> renewSubscription(String subId, DateTime newEndDate) async {
    await _firestore.collection(_collection).doc(subId).update({
      'endDate': newEndDate.toIso8601String(),
      'status': 'active',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<int> getActiveSubscriptionCount() async {
    final snap = await _firestore
        .collection(_collection)
        .where('status', whereIn: ['trial', 'active', 'expiring_soon'])
        .count()
        .get();
    return snap.count ?? 0;
  }

  @override
  Future<int> getExpiringSoonCount({int days = 7}) async {
    final now = DateTime.now();
    final cutoff = now.add(Duration(days: days));
    final snap = await _firestore
        .collection(_collection)
        .where('status', isEqualTo: 'active')
        .get();
    int count = 0;
    for (final doc in snap.docs) {
      final endDate = SubscriptionModel.fromFirestore(doc.id, doc.data()).endDate;
      if (endDate != null && endDate.isBefore(cutoff) && endDate.isAfter(now)) {
        count++;
      }
    }
    return count;
  }
}
