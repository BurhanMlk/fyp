import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a blood donation request (donor_requests collection).

class BloodRequestModel {
  final String id;
  final String type; // 'donor_request', 'donor_access_request', 'emergency', etc.
  final String? donorEmail;
  final String? donorName;
  final String? donorId;
  final String? requesterEmail;
  final String? requesterName;
  final String? recipientEmail;
  final String? recipientName;
  final String? bloodGroup;
  final String status; // 'pending', 'approved', 'rejected', 'completed'
  final String? message;
  final String? location;
  final String? urgency; // 'normal', 'high', 'critical'
  final DateTime? requestedAt;
  final DateTime? updatedAt;
  final DateTime? respondedAt;
  final String? responseMessage;
  final int? units;
  final bool? isEmergency;
  final Map<String, dynamic>? extraData;

  const BloodRequestModel({
    required this.id,
    required this.type,
    this.donorEmail,
    this.donorName,
    this.donorId,
    this.requesterEmail,
    this.requesterName,
    this.recipientEmail,
    this.recipientName,
    this.bloodGroup,
    this.status = 'pending',
    this.message,
    this.location,
    this.urgency = 'normal',
    this.requestedAt,
    this.updatedAt,
    this.respondedAt,
    this.responseMessage,
    this.units,
    this.isEmergency = false,
    this.extraData,
  });

  factory BloodRequestModel.fromFirestore(String docId, Map<String, dynamic> data) {
    return BloodRequestModel(
      id: docId,
      type: (data['type'] ?? 'donor_request').toString(),
      donorEmail: data['donorEmail']?.toString(),
      donorName: data['donorName']?.toString(),
      donorId: data['donorId']?.toString(),
      requesterEmail: data['requesterEmail']?.toString(),
      requesterName: data['requesterName']?.toString(),
      recipientEmail: data['recipientEmail']?.toString(),
      recipientName: data['recipientName']?.toString(),
      bloodGroup: data['bloodGroup']?.toString(),
      status: (data['status'] ?? 'pending').toString(),
      message: data['message']?.toString(),
      location: data['location']?.toString(),
      urgency: (data['urgency'] ?? 'normal').toString(),
      requestedAt: _parseDateTime(data['requestedAt'] ?? data['createdAt']),
      updatedAt: _parseDateTime(data['updatedAt']),
      respondedAt: _parseDateTime(data['respondedAt']),
      responseMessage: data['responseMessage']?.toString(),
      units: data['units'] is int ? data['units'] : int.tryParse(data['units']?.toString() ?? ''),
      isEmergency: data['isEmergency'] == true,
      extraData: data,
    );
  }

  factory BloodRequestModel.fromJson(Map<String, dynamic> json) {
    return BloodRequestModel(
      id: (json['id'] ?? '').toString(),
      type: (json['type'] ?? 'donor_request').toString(),
      donorEmail: json['donor_email']?.toString() ?? json['donorEmail']?.toString(),
      donorName: json['donor_name']?.toString() ?? json['donorName']?.toString(),
      donorId: json['donor_id']?.toString() ?? json['donorId']?.toString(),
      requesterEmail: json['requester_email']?.toString() ?? json['requesterEmail']?.toString(),
      requesterName: json['requester_name']?.toString() ?? json['requesterName']?.toString(),
      recipientEmail: json['recipient_email']?.toString() ?? json['recipientEmail']?.toString(),
      recipientName: json['recipient_name']?.toString() ?? json['recipientName']?.toString(),
      bloodGroup: json['blood_group']?.toString() ?? json['bloodGroup']?.toString(),
      status: (json['status'] ?? 'pending').toString(),
      message: json['message']?.toString(),
      location: json['location']?.toString(),
      urgency: (json['urgency'] ?? 'normal').toString(),
      requestedAt: _parseDateTime(json['requested_at'] ?? json['requestedAt'] ?? json['created_at'] ?? json['createdAt']),
      updatedAt: _parseDateTime(json['updated_at'] ?? json['updatedAt']),
      respondedAt: _parseDateTime(json['responded_at'] ?? json['respondedAt']),
      responseMessage: json['response_message']?.toString() ?? json['responseMessage']?.toString(),
      units: json['units'] is int ? json['units'] : int.tryParse(json['units']?.toString() ?? ''),
      isEmergency: json['is_emergency'] == true || json['isEmergency'] == true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'type': type,
      if (donorEmail != null) 'donorEmail': donorEmail,
      if (donorName != null) 'donorName': donorName,
      if (donorId != null) 'donorId': donorId,
      if (requesterEmail != null) 'requesterEmail': requesterEmail,
      if (requesterName != null) 'requesterName': requesterName,
      if (recipientEmail != null) 'recipientEmail': recipientEmail,
      if (recipientName != null) 'recipientName': recipientName,
      if (bloodGroup != null) 'bloodGroup': bloodGroup,
      'status': status,
      if (message != null) 'message': message,
      if (location != null) 'location': location,
      'urgency': urgency,
      'requestedAt': requestedAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      if (respondedAt != null) 'respondedAt': respondedAt!.toIso8601String(),
      if (responseMessage != null) 'responseMessage': responseMessage,
      if (units != null) 'units': units,
      'isEmergency': isEmergency,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'donor_email': donorEmail,
      'donor_name': donorName,
      'donor_id': donorId,
      'requester_email': requesterEmail,
      'requester_name': requesterName,
      'recipient_email': recipientEmail,
      'recipient_name': recipientName,
      'blood_group': bloodGroup,
      'status': status,
      'message': message,
      'location': location,
      'urgency': urgency,
      'requested_at': requestedAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'responded_at': respondedAt?.toIso8601String(),
      'response_message': responseMessage,
      'units': units,
      'is_emergency': isEmergency,
    };
  }

  BloodRequestModel copyWith({
    String? id, String? type, String? donorEmail, String? donorName,
    String? donorId, String? requesterEmail, String? requesterName,
    String? recipientEmail, String? recipientName, String? bloodGroup,
    String? status, String? message, String? location, String? urgency,
    DateTime? requestedAt, DateTime? updatedAt, DateTime? respondedAt,
    String? responseMessage, int? units, bool? isEmergency,
  }) {
    return BloodRequestModel(
      id: id ?? this.id, type: type ?? this.type,
      donorEmail: donorEmail ?? this.donorEmail,
      donorName: donorName ?? this.donorName,
      donorId: donorId ?? this.donorId,
      requesterEmail: requesterEmail ?? this.requesterEmail,
      requesterName: requesterName ?? this.requesterName,
      recipientEmail: recipientEmail ?? this.recipientEmail,
      recipientName: recipientName ?? this.recipientName,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      status: status ?? this.status,
      message: message ?? this.message,
      location: location ?? this.location,
      urgency: urgency ?? this.urgency,
      requestedAt: requestedAt ?? this.requestedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      respondedAt: respondedAt ?? this.respondedAt,
      responseMessage: responseMessage ?? this.responseMessage,
      units: units ?? this.units,
      isEmergency: isEmergency ?? this.isEmergency,
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    return DateTime.tryParse(value.toString());
  }
}


