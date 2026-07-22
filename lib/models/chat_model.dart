import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a chat message between users.

class ChatModel {
  final String id;
  final String chatId; // Conversation ID
  final String senderId;
  final String senderName;
  final String receiverId;
  final String receiverName;
  final String message;
  final DateTime? sentAt;
  final bool read;

  const ChatModel({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.senderName,
    required this.receiverId,
    required this.receiverName,
    required this.message,
    this.sentAt,
    this.read = false,
  });

  factory ChatModel.fromFirestore(String docId, Map<String, dynamic> data) {
    return ChatModel(
      id: docId,
      chatId: (data['chatId'] ?? '').toString(),
      senderId: (data['senderId'] ?? '').toString(),
      senderName: (data['senderName'] ?? '').toString(),
      receiverId: (data['receiverId'] ?? '').toString(),
      receiverName: (data['receiverName'] ?? '').toString(),
      message: (data['message'] ?? '').toString(),
      sentAt: _parseDateTime(data['sentAt'] ?? data['createdAt']),
      read: data['read'] == true,
    );
  }

  factory ChatModel.fromJson(Map<String, dynamic> json) {
    return ChatModel(
      id: (json['id'] ?? '').toString(),
      chatId: (json['chat_id'] ?? json['chatId'] ?? '').toString(),
      senderId: (json['sender_id'] ?? json['senderId'] ?? '').toString(),
      senderName: (json['sender_name'] ?? json['senderName'] ?? '').toString(),
      receiverId: (json['receiver_id'] ?? json['receiverId'] ?? '').toString(),
      receiverName: (json['receiver_name'] ?? json['receiverName'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      sentAt: _parseDateTime(json['sent_at'] ?? json['sentAt'] ?? json['created_at']),
      read: json['read'] == true,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'chatId': chatId, 'senderId': senderId, 'senderName': senderName,
    'receiverId': receiverId, 'receiverName': receiverName,
    'message': message, 'sentAt': sentAt?.toIso8601String(), 'read': read,
  };

  Map<String, dynamic> toJson() => {
    'id': id, 'chat_id': chatId, 'sender_id': senderId, 'sender_name': senderName,
    'receiver_id': receiverId, 'receiver_name': receiverName,
    'message': message, 'sent_at': sentAt?.toIso8601String(), 'read': read,
  };

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    return DateTime.tryParse(value.toString());
  }
}


