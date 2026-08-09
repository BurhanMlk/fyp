import 'package:cloud_firestore/cloud_firestore.dart';
import '../i_subscription_plan_repository.dart';
import '../../models/subscription_plan_model.dart';

class FirebaseSubscriptionPlanRepository implements ISubscriptionPlanRepository {
  static const String _collection = 'subscription_plans';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Future<String> createPlan(SubscriptionPlanModel plan) async {
    final docRef = await _firestore.collection(_collection).add(plan.toFirestore());
    return docRef.id;
  }

  @override
  Future<SubscriptionPlanModel?> getPlanById(String planId) async {
    final doc = await _firestore.collection(_collection).doc(planId).get();
    if (!doc.exists) return null;
    return SubscriptionPlanModel.fromFirestore(doc.id, (doc.data() as Map<String, dynamic>?) ?? {});
  }

  @override
  Future<List<SubscriptionPlanModel>> getAllPlans({bool activeOnly = false}) async {
    Query query = _firestore.collection(_collection).orderBy('sortOrder');
    if (activeOnly) {
      query = query.where('isActive', isEqualTo: true);
    }
    final snap = await query.get();
    return snap.docs.map((d) => SubscriptionPlanModel.fromFirestore(d.id, (d.data() as Map<String, dynamic>?) ?? {})).toList();
  }

  @override
  Future<void> updatePlan(String planId, Map<String, dynamic> updates) async {
    updates['updatedAt'] = FieldValue.serverTimestamp();
    await _firestore.collection(_collection).doc(planId).update(updates);
  }

  @override
  Future<void> deletePlan(String planId) async {
    // Soft-delete: mark as inactive
    await _firestore.collection(_collection).doc(planId).update({
      'isActive': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<SubscriptionPlanModel?> getTrialPlan() async {
    final snap = await _firestore
        .collection(_collection)
        .where('trialDays', isGreaterThan: 0)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return SubscriptionPlanModel.fromFirestore(snap.docs.first.id, (snap.docs.first.data() as Map<String, dynamic>?) ?? {});
  }
}
