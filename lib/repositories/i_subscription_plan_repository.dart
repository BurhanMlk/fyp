/// Abstract repository interface for subscription plan operations.

import '../models/subscription_plan_model.dart';

abstract class ISubscriptionPlanRepository {
  /// Create a new subscription plan (super admin)
  Future<String> createPlan(SubscriptionPlanModel plan);

  /// Get a plan by ID
  Future<SubscriptionPlanModel?> getPlanById(String planId);

  /// Get all plans (active only for orgs, all for super admin)
  Future<List<SubscriptionPlanModel>> getAllPlans({bool activeOnly = false});

  /// Update a plan
  Future<void> updatePlan(String planId, Map<String, dynamic> updates);

  /// Delete/deactivate a plan
  Future<void> deletePlan(String planId);

  /// Get the free/trial plan (if any)
  Future<SubscriptionPlanModel?> getTrialPlan();
}
