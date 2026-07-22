import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a broadcast message sent by admin.

class BroadcastModel {
  final String id;
  final String message;
  final String targetAudience; // 'all', 'donors', 'recipients'
  final String senderId;
  final String senderName;
  final DateTime? sentAt;

  const BroadcastModel({
    required this.id,
    required this.message,
    required this.targetAudience,
    required this.senderId,
    required this.senderName,
    this.sentAt,
  });

  factory BroadcastModel.fromFirestore(String docId, Map<String, dynamic> data) {
    return BroadcastModel(
      id: docId,
      message: (data['message'] ?? '').toString(),
      targetAudience: (data['targetAudience'] ?? data['target'] ?? 'all').toString(),
      senderId: (data['senderId'] ?? '').toString(),
      senderName: (data['senderName'] ?? '').toString(),
      sentAt: _parseDateTime(data['sentAt'] ?? data['createdAt']),
    );
  }

  factory BroadcastModel.fromJson(Map<String, dynamic> json) {
    return BroadcastModel(
      id: (json['id'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      targetAudience: (json['target_audience'] ?? json['targetAudience'] ?? 'all').toString(),
      senderId: (json['sender_id'] ?? json['senderId'] ?? '').toString(),
      senderName: (json['sender_name'] ?? json['senderName'] ?? '').toString(),
      sentAt: _parseDateTime(json['sent_at'] ?? json['sentAt'] ?? json['created_at']),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'message': message, 'targetAudience': targetAudience,
    'senderId': senderId, 'senderName': senderName,
    'sentAt': sentAt?.toIso8601String(),
  };

  Map<String, dynamic> toJson() => {
    'id': id, 'message': message, 'target_audience': targetAudience,
    'sender_id': senderId, 'sender_name': senderName,
    'sent_at': sentAt?.toIso8601String(),
  };

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    return DateTime.tryParse(value.toString());
  }
}


