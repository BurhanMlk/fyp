import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents an active subscription for an organization.
class SubscriptionModel {
  final String id;
  final String organizationId;
  final String planId;
  final String? planName; // Denormalized for quick display
  final DateTime startDate;
  final DateTime? endDate;
  final String status; // 'trial', 'active', 'expiring_soon', 'expired', 'suspended', 'cancelled'
  final String paymentStatus; // 'paid', 'pending', 'failed', 'not_required' (for trial)
  final bool autoRenewal;
  final double amount;
  final String currency;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const SubscriptionModel({
    required this.id,
    required this.organizationId,
    required this.planId,
    this.planName,
    required this.startDate,
    this.endDate,
    this.status = 'trial',
    this.paymentStatus = 'not_required',
    this.autoRenewal = false,
    this.amount = 0,
    this.currency = 'PKR',
    this.createdAt,
    this.updatedAt,
  });

  /// Whether the subscription is currently active (not expired/suspended/cancelled)
  bool get isActive => status == 'active' || status == 'trial' || status == 'expiring_soon';

  /// Whether the subscription has expired
  bool get isExpired {
    if (status == 'expired' || status == 'cancelled' || status == 'suspended') return true;
    if (endDate != null && endDate!.isBefore(DateTime.now())) return true;
    return false;
  }

  factory SubscriptionModel.fromFirestore(String docId, Map<String, dynamic> data) {
    return SubscriptionModel(
      id: docId,
      organizationId: (data['organizationId'] ?? '').toString(),
      planId: (data['planId'] ?? '').toString(),
      planName: data['planName']?.toString(),
      startDate: _parseDateTime(data['startDate']) ?? DateTime.now(),
      endDate: _parseDateTime(data['endDate']),
      status: (data['status'] ?? 'trial').toString(),
      paymentStatus: (data['paymentStatus'] ?? 'not_required').toString(),
      autoRenewal: data['autoRenewal'] == true,
      amount: (data['amount'] ?? 0).toDouble(),
      currency: (data['currency'] ?? 'PKR').toString(),
      createdAt: _parseDateTime(data['createdAt']),
      updatedAt: _parseDateTime(data['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'organizationId': organizationId,
    'planId': planId,
    if (planName != null) 'planName': planName,
    'startDate': startDate.toIso8601String(),
    if (endDate != null) 'endDate': endDate!.toIso8601String(),
    'status': status,
    'paymentStatus': paymentStatus,
    'autoRenewal': autoRenewal,
    'amount': amount,
    'currency': currency,
    'createdAt': createdAt?.toIso8601String() ?? FieldValue.serverTimestamp(),
    'updatedAt': updatedAt?.toIso8601String() ?? FieldValue.serverTimestamp(),
  };

  Map<String, dynamic> toJson() => {
    'id': id,
    'organization_id': organizationId,
    'plan_id': planId,
    'plan_name': planName,
    'start_date': startDate.toIso8601String(),
    'end_date': endDate?.toIso8601String(),
    'status': status,
    'payment_status': paymentStatus,
    'auto_renewal': autoRenewal,
    'amount': amount,
    'currency': currency,
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    return DateTime.tryParse(value.toString());
  }
}
