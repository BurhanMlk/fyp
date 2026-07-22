import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a donation history entry and reminders.

class DonationModel {
  final String id;
  final String donorId;
  final String donorName;
  final String donorEmail;
  final String? recipientId;
  final String? recipientName;
  final String bloodGroup;
  final int units;
  final DateTime? donationDate;
  final String? location;
  final String? notes;
  final bool isReminder; // true = upcoming reminder, false = past donation
  final DateTime? reminderDate;
  final bool reminderSent;

  const DonationModel({
    required this.id,
    required this.donorId,
    required this.donorName,
    required this.donorEmail,
    this.recipientId,
    this.recipientName,
    required this.bloodGroup,
    this.units = 1,
    this.donationDate,
    this.location,
    this.notes,
    this.isReminder = false,
    this.reminderDate,
    this.reminderSent = false,
  });

  factory DonationModel.fromFirestore(String docId, Map<String, dynamic> data) {
    return DonationModel(
      id: docId,
      donorId: (data['donorId'] ?? '').toString(),
      donorName: (data['donorName'] ?? '').toString(),
      donorEmail: (data['donorEmail'] ?? '').toString(),
      recipientId: data['recipientId']?.toString(),
      recipientName: data['recipientName']?.toString(),
      bloodGroup: (data['bloodGroup'] ?? '').toString(),
      units: data['units'] is int ? data['units'] : int.tryParse(data['units']?.toString() ?? '1') ?? 1,
      donationDate: _parseDateTime(data['donationDate'] ?? data['createdAt']),
      location: data['location']?.toString(),
      notes: data['notes']?.toString(),
      isReminder: data['isReminder'] == true,
      reminderDate: _parseDateTime(data['reminderDate']),
      reminderSent: data['reminderSent'] == true,
    );
  }

  factory DonationModel.fromJson(Map<String, dynamic> json) {
    return DonationModel(
      id: (json['id'] ?? '').toString(),
      donorId: (json['donor_id'] ?? json['donorId'] ?? '').toString(),
      donorName: (json['donor_name'] ?? json['donorName'] ?? '').toString(),
      donorEmail: (json['donor_email'] ?? json['donorEmail'] ?? '').toString(),
      recipientId: json['recipient_id']?.toString() ?? json['recipientId']?.toString(),
      recipientName: json['recipient_name']?.toString() ?? json['recipientName']?.toString(),
      bloodGroup: (json['blood_group'] ?? json['bloodGroup'] ?? '').toString(),
      units: json['units'] is int ? json['units'] : int.tryParse(json['units']?.toString() ?? '1') ?? 1,
      donationDate: _parseDateTime(json['donation_date'] ?? json['donationDate'] ?? json['created_at']),
      location: json['location']?.toString(),
      notes: json['notes']?.toString(),
      isReminder: json['is_reminder'] == true || json['isReminder'] == true,
      reminderDate: _parseDateTime(json['reminder_date'] ?? json['reminderDate']),
      reminderSent: json['reminder_sent'] == true || json['reminderSent'] == true,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'donorId': donorId, 'donorName': donorName, 'donorEmail': donorEmail,
    if (recipientId != null) 'recipientId': recipientId,
    if (recipientName != null) 'recipientName': recipientName,
    'bloodGroup': bloodGroup, 'units': units,
    'donationDate': donationDate?.toIso8601String(),
    if (location != null) 'location': location,
    if (notes != null) 'notes': notes,
    'isReminder': isReminder,
    if (reminderDate != null) 'reminderDate': reminderDate!.toIso8601String(),
    'reminderSent': reminderSent,
  };

  Map<String, dynamic> toJson() => {
    'id': id, 'donor_id': donorId, 'donor_name': donorName, 'donor_email': donorEmail,
    'recipient_id': recipientId, 'recipient_name': recipientName,
    'blood_group': bloodGroup, 'units': units,
    'donation_date': donationDate?.toIso8601String(),
    'location': location, 'notes': notes,
    'is_reminder': isReminder,
    'reminder_date': reminderDate?.toIso8601String(),
    'reminder_sent': reminderSent,
  };

  DonationModel copyWith({
    String? id,
    String? donorId,
    String? donorName,
    String? donorEmail,
    String? recipientId,
    String? recipientName,
    String? bloodGroup,
    int? units,
    DateTime? donationDate,
    String? location,
    String? notes,
    bool? isReminder,
    DateTime? reminderDate,
    bool? reminderSent,
  }) {
    return DonationModel(
      id: id ?? this.id,
      donorId: donorId ?? this.donorId,
      donorName: donorName ?? this.donorName,
      donorEmail: donorEmail ?? this.donorEmail,
      recipientId: recipientId ?? this.recipientId,
      recipientName: recipientName ?? this.recipientName,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      units: units ?? this.units,
      donationDate: donationDate ?? this.donationDate,
      location: location ?? this.location,
      notes: notes ?? this.notes,
      isReminder: isReminder ?? this.isReminder,
      reminderDate: reminderDate ?? this.reminderDate,
      reminderSent: reminderSent ?? this.reminderSent,
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    return DateTime.tryParse(value.toString());
  }
}


