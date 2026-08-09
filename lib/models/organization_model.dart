import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents an organization (tenant) in the multi-tenant BloodBridge platform.
/// Types: 'university', 'society', 'blood_bank', 'ngo'
class OrganizationModel {
  final String id;
  final String type; // 'university', 'society', 'blood_bank', 'ngo'
  final String name;
  final String? logoUrl;
  final String email;
  final String phone;
  final String? address;
  final String? city;
  final String? province;
  final String? website;
  final String? description;
  final String? licenseNumber; // For blood banks
  final String? universityId; // For societies (parent university)
  final String adminId; // The user ID of the org admin
  final String status; // 'pending', 'approved', 'active', 'suspended', 'rejected'
  final String? subscriptionId;
  final String? trialEndDate;
  final Map<String, dynamic>? branding; // logo, primaryColor, secondaryColor
  final Map<String, dynamic>? settings;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic>? extraData;

  const OrganizationModel({
    required this.id,
    required this.type,
    required this.name,
    this.logoUrl,
    required this.email,
    required this.phone,
    this.address,
    this.city,
    this.province,
    this.website,
    this.description,
    this.licenseNumber,
    this.universityId,
    required this.adminId,
    this.status = 'pending',
    this.subscriptionId,
    this.trialEndDate,
    this.branding,
    this.settings,
    this.createdAt,
    this.updatedAt,
    this.extraData,
  });

  factory OrganizationModel.fromFirestore(String docId, Map<String, dynamic> data) {
    return OrganizationModel(
      id: docId,
      type: (data['type'] ?? '').toString(),
      name: (data['name'] ?? '').toString(),
      logoUrl: data['logoUrl']?.toString(),
      email: (data['email'] ?? '').toString(),
      phone: (data['phone'] ?? '').toString(),
      address: data['address']?.toString(),
      city: data['city']?.toString(),
      province: data['province']?.toString(),
      website: data['website']?.toString(),
      description: data['description']?.toString(),
      licenseNumber: data['licenseNumber']?.toString(),
      universityId: data['universityId']?.toString(),
      adminId: (data['adminId'] ?? '').toString(),
      status: (data['status'] ?? 'pending').toString(),
      subscriptionId: data['subscriptionId']?.toString(),
      trialEndDate: data['trialEndDate']?.toString(),
      branding: data['branding'] is Map ? Map<String, dynamic>.from(data['branding']) : null,
      settings: data['settings'] is Map ? Map<String, dynamic>.from(data['settings']) : null,
      createdAt: _parseDateTime(data['createdAt']),
      updatedAt: _parseDateTime(data['updatedAt']),
      extraData: data,
    );
  }

  factory OrganizationModel.fromJson(Map<String, dynamic> json) {
    return OrganizationModel(
      id: (json['id'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      logoUrl: json['logo_url']?.toString() ?? json['logoUrl']?.toString(),
      email: (json['email'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      address: json['address']?.toString(),
      city: json['city']?.toString(),
      province: json['province']?.toString(),
      website: json['website']?.toString(),
      description: json['description']?.toString(),
      licenseNumber: json['license_number']?.toString() ?? json['licenseNumber']?.toString(),
      universityId: json['university_id']?.toString() ?? json['universityId']?.toString(),
      adminId: (json['admin_id'] ?? json['adminId'] ?? '').toString(),
      status: (json['status'] ?? 'pending').toString(),
      subscriptionId: json['subscription_id']?.toString() ?? json['subscriptionId']?.toString(),
      trialEndDate: json['trial_end_date']?.toString() ?? json['trialEndDate']?.toString(),
      branding: json['branding'] is Map ? Map<String, dynamic>.from(json['branding']) : null,
      settings: json['settings'] is Map ? Map<String, dynamic>.from(json['settings']) : null,
      createdAt: _parseDateTime(json['created_at'] ?? json['createdAt']),
      updatedAt: _parseDateTime(json['updated_at'] ?? json['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'type': type,
    'name': name,
    if (logoUrl != null) 'logoUrl': logoUrl,
    'email': email,
    'phone': phone,
    if (address != null) 'address': address,
    if (city != null) 'city': city,
    if (province != null) 'province': province,
    if (website != null) 'website': website,
    if (description != null) 'description': description,
    if (licenseNumber != null) 'licenseNumber': licenseNumber,
    if (universityId != null) 'universityId': universityId,
    'adminId': adminId,
    'status': status,
    if (subscriptionId != null) 'subscriptionId': subscriptionId,
    if (trialEndDate != null) 'trialEndDate': trialEndDate,
    if (branding != null) 'branding': branding,
    if (settings != null) 'settings': settings,
    'createdAt': createdAt?.toIso8601String() ?? FieldValue.serverTimestamp(),
    'updatedAt': updatedAt?.toIso8601String() ?? FieldValue.serverTimestamp(),
  };

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'name': name,
    'logo_url': logoUrl,
    'email': email,
    'phone': phone,
    'address': address,
    'city': city,
    'province': province,
    'website': website,
    'description': description,
    'license_number': licenseNumber,
    'university_id': universityId,
    'admin_id': adminId,
    'status': status,
    'subscription_id': subscriptionId,
    'trial_end_date': trialEndDate,
    'branding': branding,
    'settings': settings,
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };

  OrganizationModel copyWith({
    String? id, String? type, String? name, String? logoUrl,
    String? email, String? phone, String? address, String? city,
    String? province, String? website, String? description,
    String? licenseNumber, String? universityId, String? adminId,
    String? status, String? subscriptionId, String? trialEndDate,
    Map<String, dynamic>? branding, Map<String, dynamic>? settings,
    DateTime? createdAt, DateTime? updatedAt,
  }) {
    return OrganizationModel(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      logoUrl: logoUrl ?? this.logoUrl,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      city: city ?? this.city,
      province: province ?? this.province,
      website: website ?? this.website,
      description: description ?? this.description,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      universityId: universityId ?? this.universityId,
      adminId: adminId ?? this.adminId,
      status: status ?? this.status,
      subscriptionId: subscriptionId ?? this.subscriptionId,
      trialEndDate: trialEndDate ?? this.trialEndDate,
      branding: branding ?? this.branding,
      settings: settings ?? this.settings,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    return DateTime.tryParse(value.toString());
  }
}
