/// Firebase implementation of [IChatRepository].
/// Wraps Cloud Firestore chats/messages collections.

import 'package:cloud_firestore/cloud_firestore.dart';
import '../i_chat_repository.dart';
import '../../models/chat_model.dart';

class FirebaseChatRepository implements IChatRepository {
  final FirebaseFirestore _firestore;

  FirebaseChatRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _messagesCol =>
      _firestore.collection('messages');

  @override
  Future<void> sendMessage(ChatModel message) async {
    await _messagesCol.add(message.toFirestore());
  }

  @override
  Future<List<ChatModel>> getMessages(String chatId) async {
    final snap = await _messagesCol
        .where('chatId', isEqualTo: chatId)
        .orderBy('sentAt', descending: false)
        .get();
    return snap.docs
        .map((doc) => ChatModel.fromFirestore(doc.id, doc.data()))
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getActiveChats() async {
    // Get all messages and group by chatId to find active conversations
    final snap = await _messagesCol
        .orderBy('sentAt', descending: true)
        .get();

    final chatMap = <String, Map<String, dynamic>>{};
    for (final doc in snap.docs) {
      final data = doc.data();
      final chatId = (data['chatId'] ?? '').toString();
      if (chatId.isEmpty || chatMap.containsKey(chatId)) continue;

      chatMap[chatId] = {
        'chatId': chatId,
        'senderName': data['senderName'] ?? '',
        'receiverName': data['receiverName'] ?? '',
        'lastMessage': data['message'] ?? '',
        'lastMessageTime': data['sentAt'],
        'senderId': data['senderId'] ?? '',
        'receiverId': data['receiverId'] ?? '',
      };
    }
    return chatMap.values.toList();
  }

  @override
  Future<List<ChatModel>> getMessagesToday() async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);

    final snap = await _messagesCol
        .where('sentAt', isGreaterThanOrEqualTo: startOfDay.toIso8601String())
        .orderBy('sentAt', descending: true)
        .get();

    return snap.docs
        .map((doc) => ChatModel.fromFirestore(doc.id, doc.data()))
        .toList();
  }

  @override
  Future<int> getUnreadCount(String userId) async {
    final snap = await _messagesCol
        .where('receiverId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .count()
        .get();
    return snap.count ?? 0;
  }

  @override
  Future<void> markAsRead(String chatId, String userId) async {
    final snap = await _messagesCol
        .where('chatId', isEqualTo: chatId)
        .where('receiverId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .get();

    final batch = _firestore.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  @override
  String generateChatId(String user1, String user2) {
    final sorted = [user1, user2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }
}
