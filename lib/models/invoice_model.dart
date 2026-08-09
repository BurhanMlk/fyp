import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents an invoice generated after payment.
class InvoiceModel {
  final String id;
  final String invoiceNumber; // e.g., 'INV-2024-0001'
  final String organizationId;
  final String? organizationName;
  final String subscriptionId;
  final String? planName;
  final String paymentId;
  final double amount;
  final String currency;
  final String paymentMethod;
  final String? transactionId;
  final DateTime invoiceDate;
  final DateTime subscriptionStartDate;
  final DateTime? subscriptionEndDate;
  final String status; // 'paid', 'pending', 'cancelled'
  final Map<String, dynamic>? metadata;

  const InvoiceModel({
    required this.id,
    required this.invoiceNumber,
    required this.organizationId,
    this.organizationName,
    required this.subscriptionId,
    this.planName,
    required this.paymentId,
    required this.amount,
    this.currency = 'PKR',
    required this.paymentMethod,
    this.transactionId,
    required this.invoiceDate,
    required this.subscriptionStartDate,
    this.subscriptionEndDate,
    this.status = 'paid',
    this.metadata,
  });

  factory InvoiceModel.fromFirestore(String docId, Map<String, dynamic> data) {
    return InvoiceModel(
      id: docId,
      invoiceNumber: (data['invoiceNumber'] ?? docId).toString(),
      organizationId: (data['organizationId'] ?? '').toString(),
      organizationName: data['organizationName']?.toString(),
      subscriptionId: (data['subscriptionId'] ?? '').toString(),
      planName: data['planName']?.toString(),
      paymentId: (data['paymentId'] ?? '').toString(),
      amount: (data['amount'] ?? 0).toDouble(),
      currency: (data['currency'] ?? 'PKR').toString(),
      paymentMethod: (data['paymentMethod'] ?? '').toString(),
      transactionId: data['transactionId']?.toString(),
      invoiceDate: _parseDateTime(data['invoiceDate']) ?? DateTime.now(),
      subscriptionStartDate: _parseDateTime(data['subscriptionStartDate']) ?? DateTime.now(),
      subscriptionEndDate: _parseDateTime(data['subscriptionEndDate']),
      status: (data['status'] ?? 'paid').toString(),
      metadata: data['metadata'] is Map ? Map<String, dynamic>.from(data['metadata']) : null,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'invoiceNumber': invoiceNumber,
    'organizationId': organizationId,
    if (organizationName != null) 'organizationName': organizationName,
    'subscriptionId': subscriptionId,
    if (planName != null) 'planName': planName,
    'paymentId': paymentId,
    'amount': amount,
    'currency': currency,
    'paymentMethod': paymentMethod,
    if (transactionId != null) 'transactionId': transactionId,
    'invoiceDate': invoiceDate.toIso8601String(),
    'subscriptionStartDate': subscriptionStartDate.toIso8601String(),
    if (subscriptionEndDate != null) 'subscriptionEndDate': subscriptionEndDate!.toIso8601String(),
    'status': status,
    if (metadata != null) 'metadata': metadata,
  };

  Map<String, dynamic> toJson() => {
    'id': id,
    'invoice_number': invoiceNumber,
    'organization_id': organizationId,
    'organization_name': organizationName,
    'subscription_id': subscriptionId,
    'plan_name': planName,
    'payment_id': paymentId,
    'amount': amount,
    'currency': currency,
    'payment_method': paymentMethod,
    'transaction_id': transactionId,
    'invoice_date': invoiceDate.toIso8601String(),
    'subscription_start_date': subscriptionStartDate.toIso8601String(),
    'subscription_end_date': subscriptionEndDate?.toIso8601String(),
    'status': status,
    'metadata': metadata,
  };

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    return DateTime.tryParse(value.toString());
  }
}
