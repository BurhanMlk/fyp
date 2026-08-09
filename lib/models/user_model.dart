import 'package:cloud_firestore/cloud_firestore.dart';

/// Unified User model used across all repository implementations.
/// Works with both Firebase Firestore and PostgreSQL/Supabase.

class UserModel {
  final String id; // Firebase Auth UID or Supabase user ID
  final String name;
  final String email;
  final String contact;
  final String bloodGroup;
  /// Role: 'super_admin', 'university_admin', 'society_admin',
  /// 'blood_bank_admin', 'donor', 'recipient', 'volunteer'
  final String role;
  final String location;
  final String? designation;
  final int? age;
  final String? gender;
  final String? cnic;
  final bool approved;
  final bool isDonor;
  final bool? firstDonationApproved;
  final String? photoData; // Base64 encoded
  final String? verificationDocumentData; // Base64 encoded
  final String verificationStatus; // 'not_uploaded', 'pending', 'approved', 'rejected'
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? cooldownUntil;

  // ── Multi-tenant fields ──
  final String? organizationId; // The org this user belongs to
  final String? universityId;   // If in a university
  final String? societyId;      // If in a society
  final String? bloodBankId;    // If in a blood bank

  final Map<String, dynamic>? extraData; // For any additional fields

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.contact,
    required this.bloodGroup,
    required this.role,
    required this.location,
    this.designation,
    this.age,
    this.gender,
    this.cnic,
    this.approved = false,
    this.isDonor = false,
    this.firstDonationApproved,
    this.photoData,
    this.verificationDocumentData,
    this.verificationStatus = 'not_uploaded',
    this.createdAt,
    this.updatedAt,
    this.cooldownUntil,
    this.organizationId,
    this.universityId,
    this.societyId,
    this.bloodBankId,
    this.extraData,
  });

  /// Create from a Firestore document snapshot
  factory UserModel.fromFirestore(String docId, Map<String, dynamic> data) {
    return UserModel(
      id: docId,
      name: (data['name'] ?? '').toString(),
      email: (data['email'] ?? '').toString(),
      contact: (data['contact'] ?? data['phone'] ?? '').toString(),
      bloodGroup: (data['bloodGroup'] ?? '').toString(),
      role: (data['role'] ?? 'user').toString(),
      location: (data['location'] ?? '').toString(),
      designation: data['designation']?.toString(),
      age: data['age'] is int ? data['age'] : int.tryParse(data['age']?.toString() ?? ''),
      gender: data['gender']?.toString(),
      cnic: data['cnic']?.toString(),
      approved: data['approved'] == true,
      isDonor: data['isDonor'] == true,
      firstDonationApproved: data['firstDonationApproved'] == true,
      photoData: data['photoData']?.toString(),
      verificationDocumentData: data['verificationDocumentData']?.toString(),
      verificationStatus: (data['verificationStatus'] ?? 'not_uploaded').toString(),
      createdAt: _parseDateTime(data['createdAt']),
      updatedAt: _parseDateTime(data['updatedAt']),
      cooldownUntil: _parseDateTime(data['cooldownUntil']),
      organizationId: data['organizationId']?.toString(),
      universityId: data['universityId']?.toString(),
      societyId: data['societyId']?.toString(),
      bloodBankId: data['bloodBankId']?.toString(),
      extraData: data,
    );
  }

  /// Create from a JSON map (Supabase / REST API)
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: (json['id'] ?? json['user_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      contact: (json['contact'] ?? json['phone'] ?? '').toString(),
      bloodGroup: (json['blood_group'] ?? json['bloodGroup'] ?? '').toString(),
      role: (json['role'] ?? 'user').toString(),
      location: (json['location'] ?? '').toString(),
      designation: json['designation']?.toString(),
      age: json['age'] is int ? json['age'] : int.tryParse(json['age']?.toString() ?? ''),
      gender: json['gender']?.toString(),
      cnic: json['cnic']?.toString(),
      approved: json['approved'] == true,
      isDonor: json['is_donor'] == true || json['isDonor'] == true,
      firstDonationApproved: json['first_donation_approved'] == true || json['firstDonationApproved'] == true,
      photoData: json['photo_data']?.toString() ?? json['photoData']?.toString(),
      verificationDocumentData: json['verification_document_data']?.toString() ?? json['verificationDocumentData']?.toString(),
      verificationStatus: (json['verification_status'] ?? json['verificationStatus'] ?? 'not_uploaded').toString(),
      createdAt: _parseDateTime(json['created_at'] ?? json['createdAt']),
      updatedAt: _parseDateTime(json['updated_at'] ?? json['updatedAt']),
      cooldownUntil: _parseDateTime(json['cooldown_until'] ?? json['cooldownUntil']),
      organizationId: json['organization_id']?.toString() ?? json['organizationId']?.toString(),
      universityId: json['university_id']?.toString() ?? json['universityId']?.toString(),
      societyId: json['society_id']?.toString() ?? json['societyId']?.toString(),
      bloodBankId: json['blood_bank_id']?.toString() ?? json['bloodBankId']?.toString(),
    );
  }

  /// Convert to a map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'contact': contact,
      'bloodGroup': bloodGroup,
      'role': role,
      'location': location,
      if (designation != null) 'designation': designation,
      if (age != null) 'age': age,
      if (gender != null) 'gender': gender,
      if (cnic != null) 'cnic': cnic,
      'approved': approved,
      'isDonor': isDonor,
      if (firstDonationApproved != null) 'firstDonationApproved': firstDonationApproved,
      if (photoData != null) 'photoData': photoData,
      if (verificationDocumentData != null) 'verificationDocumentData': verificationDocumentData,
      'verificationStatus': verificationStatus,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      if (cooldownUntil != null) 'cooldownUntil': cooldownUntil!.toIso8601String(),
      if (organizationId != null) 'organizationId': organizationId,
      if (universityId != null) 'universityId': universityId,
      if (societyId != null) 'societyId': societyId,
      if (bloodBankId != null) 'bloodBankId': bloodBankId,
    };
  }

  /// Convert to JSON (for Supabase / REST API)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'contact': contact,
      'blood_group': bloodGroup,
      'role': role,
      'location': location,
      'designation': designation,
      'age': age,
      'gender': gender,
      'cnic': cnic,
      'approved': approved,
      'is_donor': isDonor,
      'first_donation_approved': firstDonationApproved,
      'photo_data': photoData,
      'verification_document_data': verificationDocumentData,
      'verification_status': verificationStatus,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'cooldown_until': cooldownUntil?.toIso8601String(),
      if (organizationId != null) 'organization_id': organizationId,
      if (universityId != null) 'university_id': universityId,
      if (societyId != null) 'society_id': societyId,
      if (bloodBankId != null) 'blood_bank_id': bloodBankId,
    };
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? contact,
    String? bloodGroup,
    String? role,
    String? location,
    String? designation,
    int? age,
    String? gender,
    String? cnic,
    bool? approved,
    bool? isDonor,
    bool? firstDonationApproved,
    String? photoData,
    String? verificationDocumentData,
    String? verificationStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? cooldownUntil,
    String? organizationId,
    String? universityId,
    String? societyId,
    String? bloodBankId,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      contact: contact ?? this.contact,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      role: role ?? this.role,
      location: location ?? this.location,
      designation: designation ?? this.designation,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      cnic: cnic ?? this.cnic,
      approved: approved ?? this.approved,
      isDonor: isDonor ?? this.isDonor,
      firstDonationApproved: firstDonationApproved ?? this.firstDonationApproved,
      photoData: photoData ?? this.photoData,
      verificationDocumentData: verificationDocumentData ?? this.verificationDocumentData,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      cooldownUntil: cooldownUntil ?? this.cooldownUntil,
      organizationId: organizationId ?? this.organizationId,
      universityId: universityId ?? this.universityId,
      societyId: societyId ?? this.societyId,
      bloodBankId: bloodBankId ?? this.bloodBankId,
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    return DateTime.tryParse(value.toString());
  }
}


