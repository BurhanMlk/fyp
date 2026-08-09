/// Abstract repository interface for subscription management.

import '../models/subscription_model.dart';

abstract class ISubscriptionRepository {
  /// Create a subscription for an organization
  Future<String> createSubscription(SubscriptionModel subscription);

  /// Get subscription by ID
  Future<SubscriptionModel?> getSubscriptionById(String subId);

  /// Get active subscription for an organization
  Future<SubscriptionModel?> getActiveSubscriptionForOrg(String orgId);

  /// Get all subscriptions for an organization
  Future<List<SubscriptionModel>> getSubscriptionsForOrg(String orgId);

  /// Get all subscriptions (super admin)
  Future<List<SubscriptionModel>> getAllSubscriptions();

  /// Get subscriptions by status
  Future<List<SubscriptionModel>> getSubscriptionsByStatus(String status);

  /// Update subscription
  Future<void> updateSubscription(String subId, Map<String, dynamic> updates);

  /// Cancel a subscription
  Future<void> cancelSubscription(String subId);

  /// Renew a subscription
  Future<void> renewSubscription(String subId, DateTime newEndDate);

  /// Get count of active subscriptions
  Future<int> getActiveSubscriptionCount();

  /// Get count of expiring subscriptions (within N days)
  Future<int> getExpiringSoonCount({int days = 7});
}
