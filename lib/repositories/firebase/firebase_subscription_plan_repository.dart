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
    // Fetch all plans ordered by sortOrder (single-field orderBy — no composite index needed)
    // and filter in Dart to avoid a composite index requirement.
    final snap = await _firestore.collection(_collection).orderBy('sortOrder').get();
    final plans = snap.docs
        .map((d) => SubscriptionPlanModel.fromFirestore(d.id, (d.data() as Map<String, dynamic>?) ?? {}))
        .toList();
    if (activeOnly) {
      return plans.where((p) => p.isActive).toList();
    }
    return plans;
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
    // Fetch all plans and filter in Dart to avoid a composite index requirement
    // (range query `trialDays > 0` + equality `isActive == true` would need an index).
    final snap = await _firestore.collection(_collection).get();
    for (final doc in snap.docs) {
      final plan = SubscriptionPlanModel.fromFirestore(doc.id, (doc.data() as Map<String, dynamic>?) ?? {});
      if (plan.isActive && (plan.trialDays ?? 0) > 0) {
        return plan;
      }
    }
    return null;
  }
}
