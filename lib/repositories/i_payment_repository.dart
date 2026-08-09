/// Abstract repository interface for payment operations.
/// Designed to be modular for future payment gateway integration.

import '../models/payment_model.dart';

abstract class IPaymentRepository {
  /// Record a payment
  Future<String> recordPayment(PaymentModel payment);

  /// Get payment by ID
  Future<PaymentModel?> getPaymentById(String paymentId);

  /// Get payments for an organization
  Future<List<PaymentModel>> getPaymentsForOrg(String orgId);

  /// Get payments for a subscription
  Future<List<PaymentModel>> getPaymentsForSubscription(String subscriptionId);

  /// Get all payments (super admin)
  Future<List<PaymentModel>> getAllPayments();

  /// Get payments by status
  Future<List<PaymentModel>> getPaymentsByStatus(String status);

  /// Update payment status (e.g., after gateway callback)
  Future<void> updatePaymentStatus(String paymentId, String status, {String? transactionId});

  /// Get total revenue (super admin analytics)
  Future<double> getTotalRevenue({DateTime? from, DateTime? to});

  /// Process a test/mock payment (for development only)
  Future<String> processMockPayment({
    required String organizationId,
    required String subscriptionId,
    required double amount,
    String paymentMethod = 'test',
  });
}
