import 'package:cloud_firestore/cloud_firestore.dart';
import '../i_payment_repository.dart';
import '../../models/payment_model.dart';

class FirebasePaymentRepository implements IPaymentRepository {
  static const String _collection = 'payments';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Future<String> recordPayment(PaymentModel payment) async {
    final docRef = await _firestore.collection(_collection).add(payment.toFirestore());
    return docRef.id;
  }

  @override
  Future<PaymentModel?> getPaymentById(String paymentId) async {
    final doc = await _firestore.collection(_collection).doc(paymentId).get();
    if (!doc.exists) return null;
    return PaymentModel.fromFirestore(doc.id, doc.data() ?? {});
  }

  @override
  Future<List<PaymentModel>> getPaymentsForOrg(String orgId) async {
    final snap = await _firestore
        .collection(_collection)
        .where('organizationId', isEqualTo: orgId)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map((d) => PaymentModel.fromFirestore(d.id, d.data())).toList();
  }

  @override
  Future<List<PaymentModel>> getPaymentsForSubscription(String subscriptionId) async {
    final snap = await _firestore
        .collection(_collection)
        .where('subscriptionId', isEqualTo: subscriptionId)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map((d) => PaymentModel.fromFirestore(d.id, d.data())).toList();
  }

  @override
  Future<List<PaymentModel>> getAllPayments() async {
    final snap = await _firestore
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map((d) => PaymentModel.fromFirestore(d.id, d.data())).toList();
  }

  @override
  Future<List<PaymentModel>> getPaymentsByStatus(String status) async {
    final snap = await _firestore
        .collection(_collection)
        .where('status', isEqualTo: status)
        .get();
    return snap.docs.map((d) => PaymentModel.fromFirestore(d.id, d.data())).toList();
  }

  @override
  Future<void> updatePaymentStatus(String paymentId, String status, {String? transactionId}) async {
    final updates = <String, dynamic>{
      'status': status,
      'paymentDate': DateTime.now().toIso8601String(),
    };
    if (transactionId != null) updates['transactionId'] = transactionId;
    await _firestore.collection(_collection).doc(paymentId).update(updates);
  }

  @override
  Future<double> getTotalRevenue({DateTime? from, DateTime? to}) async {
    final snap = await _firestore.collection(_collection).where('status', isEqualTo: 'completed').get();
    double total = 0;
    for (final doc in snap.docs) {
      final data = doc.data();
      final date = PaymentModel.fromFirestore(doc.id, data).paymentDate;
      if (date != null) {
        if (from != null && date.isBefore(from)) continue;
        if (to != null && date.isAfter(to)) continue;
      }
      total += (data['amount'] ?? 0).toDouble();
    }
    return total;
  }

  @override
  Future<String> processMockPayment({
    required String organizationId,
    required String subscriptionId,
    required double amount,
    String paymentMethod = 'test',
  }) async {
    // Mock payment: simulate a successful payment for development/testing
    final payment = PaymentModel(
      id: '', // Will be assigned
      organizationId: organizationId,
      subscriptionId: subscriptionId,
      amount: amount,
      currency: 'PKR',
      paymentMethod: paymentMethod,
      status: 'completed',
      transactionId: 'TEST-${DateTime.now().millisecondsSinceEpoch}',
      paymentDate: DateTime.now(),
      notes: 'Mock payment for development',
    );
    return recordPayment(payment);
  }
}
