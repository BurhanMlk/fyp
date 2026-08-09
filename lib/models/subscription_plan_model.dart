import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a subscription plan.
/// Super Admin can dynamically manage plans — no hard-coded prices.
class SubscriptionPlanModel {
  final String id;
  final String name; // 'Free Trial', 'Starter', 'Professional', 'Enterprise'
  final String? description;
  final double price; // Monthly price in PKR (or base currency)
  final String currency; // 'PKR', 'USD', etc.
  final int? maxUsers;
  final int? maxSocieties;
  final int? maxAdmins;
  final int? maxBloodRequests; // Per month
  final int? maxStorageMb;
  final List<String> features; // ['analytics', 'reports', 'notifications', 'white_label', etc.]
  final bool isActive;
  final int? trialDays; // Trial period in days (for free/trial plan)
  final int sortOrder;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const SubscriptionPlanModel({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    this.currency = 'PKR',
    this.maxUsers,
    this.maxSocieties,
    this.maxAdmins,
    this.maxBloodRequests,
    this.maxStorageMb,
    this.features = const [],
    this.isActive = true,
    this.trialDays,
    this.sortOrder = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory SubscriptionPlanModel.fromFirestore(String docId, Map<String, dynamic> data) {
    return SubscriptionPlanModel(
      id: docId,
      name: (data['name'] ?? '').toString(),
      description: data['description']?.toString(),
      price: (data['price'] ?? 0).toDouble(),
      currency: (data['currency'] ?? 'PKR').toString(),
      maxUsers: data['maxUsers'] is int ? data['maxUsers'] : int.tryParse(data['maxUsers']?.toString() ?? ''),
      maxSocieties: data['maxSocieties'] is int ? data['maxSocieties'] : int.tryParse(data['maxSocieties']?.toString() ?? ''),
      maxAdmins: data['maxAdmins'] is int ? data['maxAdmins'] : int.tryParse(data['maxAdmins']?.toString() ?? ''),
      maxBloodRequests: data['maxBloodRequests'] is int ? data['maxBloodRequests'] : int.tryParse(data['maxBloodRequests']?.toString() ?? ''),
      maxStorageMb: data['maxStorageMb'] is int ? data['maxStorageMb'] : int.tryParse(data['maxStorageMb']?.toString() ?? ''),
      features: (data['features'] is List) ? List<String>.from(data['features']) : [],
      isActive: data['isActive'] != false,
      trialDays: data['trialDays'] is int ? data['trialDays'] : int.tryParse(data['trialDays']?.toString() ?? ''),
      sortOrder: data['sortOrder'] is int ? data['sortOrder'] : (int.tryParse(data['sortOrder']?.toString() ?? '0') ?? 0),
      createdAt: _parseDateTime(data['createdAt']),
      updatedAt: _parseDateTime(data['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'name': name,
    if (description != null) 'description': description,
    'price': price,
    'currency': currency,
    if (maxUsers != null) 'maxUsers': maxUsers,
    if (maxSocieties != null) 'maxSocieties': maxSocieties,
    if (maxAdmins != null) 'maxAdmins': maxAdmins,
    if (maxBloodRequests != null) 'maxBloodRequests': maxBloodRequests,
    if (maxStorageMb != null) 'maxStorageMb': maxStorageMb,
    'features': features,
    'isActive': isActive,
    if (trialDays != null) 'trialDays': trialDays,
    'sortOrder': sortOrder,
    'createdAt': createdAt?.toIso8601String() ?? FieldValue.serverTimestamp(),
    'updatedAt': updatedAt?.toIso8601String() ?? FieldValue.serverTimestamp(),
  };

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'price': price,
    'currency': currency,
    'max_users': maxUsers,
    'max_societies': maxSocieties,
    'max_admins': maxAdmins,
    'max_blood_requests': maxBloodRequests,
    'max_storage_mb': maxStorageMb,
    'features': features,
    'is_active': isActive,
    'trial_days': trialDays,
    'sort_order': sortOrder,
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
