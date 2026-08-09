import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a payment record for a subscription.
/// Designed to be modular for future payment gateway integration
/// (JazzCash, Easypaisa, Bank Transfer, Cards, etc.)
class PaymentModel {
  final String id;
  final String organizationId;
  final String subscriptionId;
  final String? invoiceId;
  final double amount;
  final String currency;
  final String paymentMethod; // 'jazzcash', 'easypaisa', 'bank_transfer', 'credit_card', 'debit_card', 'manual', 'test'
  final String status; // 'pending', 'completed', 'failed', 'refunded'
  final String? transactionId; // External gateway transaction ID
  final String? receiptUrl;
  final String? notes;
  final DateTime? paymentDate;
  final DateTime? createdAt;

  const PaymentModel({
    required this.id,
    required this.organizationId,
    required this.subscriptionId,
    this.invoiceId,
    required this.amount,
    this.currency = 'PKR',
    required this.paymentMethod,
    this.status = 'pending',
    this.transactionId,
    this.receiptUrl,
    this.notes,
    this.paymentDate,
    this.createdAt,
  });

  factory PaymentModel.fromFirestore(String docId, Map<String, dynamic> data) {
    return PaymentModel(
      id: docId,
      organizationId: (data['organizationId'] ?? '').toString(),
      subscriptionId: (data['subscriptionId'] ?? '').toString(),
      invoiceId: data['invoiceId']?.toString(),
      amount: (data['amount'] ?? 0).toDouble(),
      currency: (data['currency'] ?? 'PKR').toString(),
      paymentMethod: (data['paymentMethod'] ?? 'manual').toString(),
      status: (data['status'] ?? 'pending').toString(),
      transactionId: data['transactionId']?.toString(),
      receiptUrl: data['receiptUrl']?.toString(),
      notes: data['notes']?.toString(),
      paymentDate: _parseDateTime(data['paymentDate']),
      createdAt: _parseDateTime(data['createdAt']),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'organizationId': organizationId,
    'subscriptionId': subscriptionId,
    if (invoiceId != null) 'invoiceId': invoiceId,
    'amount': amount,
    'currency': currency,
    'paymentMethod': paymentMethod,
    'status': status,
    if (transactionId != null) 'transactionId': transactionId,
    if (receiptUrl != null) 'receiptUrl': receiptUrl,
    if (notes != null) 'notes': notes,
    if (paymentDate != null) 'paymentDate': paymentDate!.toIso8601String(),
    'createdAt': createdAt?.toIso8601String() ?? FieldValue.serverTimestamp(),
  };

  Map<String, dynamic> toJson() => {
    'id': id,
    'organization_id': organizationId,
    'subscription_id': subscriptionId,
    'invoice_id': invoiceId,
    'amount': amount,
    'currency': currency,
    'payment_method': paymentMethod,
    'status': status,
    'transaction_id': transactionId,
    'receipt_url': receiptUrl,
    'notes': notes,
    'payment_date': paymentDate?.toIso8601String(),
    'created_at': createdAt?.toIso8601String(),
  };

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    return DateTime.tryParse(value.toString());
  }
}
