/// Abstract repository interface for chat/messaging operations.
/// Implementations: [FirebaseChatRepository], [SupabaseChatRepository]

import '../models/chat_model.dart';

abstract class IChatRepository {
  /// Send a message
  Future<void> sendMessage(ChatModel message);

  /// Get messages for a chat conversation
  Future<List<ChatModel>> getMessages(String chatId);

  /// Get all active chats (distinct conversations)
  Future<List<Map<String, dynamic>>> getActiveChats();

  /// Get messages for today (admin overview)
  Future<List<ChatModel>> getMessagesToday();

  /// Get unread messages count for a user
  Future<int> getUnreadCount(String userId);

  /// Mark messages as read
  Future<void> markAsRead(String chatId, String userId);

  /// Generate a unique chat ID from two user IDs
  String generateChatId(String user1, String user2);
}
