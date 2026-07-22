/// Supabase implementation of [IChatRepository].

import 'package:supabase_flutter/supabase_flutter.dart';
import '../i_chat_repository.dart';
import '../../models/chat_model.dart';

class SupabaseChatRepository implements IChatRepository {
  final SupabaseClient _client;

  SupabaseChatRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  @override
  Future<void> sendMessage(ChatModel message) async {
    await _client.from('messages').insert(message.toJson());
  }

  @override
  Future<List<ChatModel>> getMessages(String chatId) async {
    final data = await _client
        .from('messages')
        .select()
        .eq('chat_id', chatId)
        .order('sent_at', ascending: true);
    return (data as List).map((json) => ChatModel.fromJson(json)).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getActiveChats() async {
    // Use a raw SQL query for distinct chat grouping
    final data = await _client.rpc('get_active_chats');
    return (data as List).map((row) => Map<String, dynamic>.from(row)).toList();
  }

  @override
  Future<List<ChatModel>> getMessagesToday() async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day).toIso8601String();
    final data = await _client
        .from('messages')
        .select()
        .gte('sent_at', startOfDay)
        .order('sent_at', ascending: false);
    return (data as List).map((json) => ChatModel.fromJson(json)).toList();
  }

  @override
  Future<int> getUnreadCount(String userId) async {
    final data = await _client
        .from('messages')
        .select('id')
        .eq('receiver_id', userId)
        .eq('read', false);
    return (data as List).length;
  }

  @override
  Future<void> markAsRead(String chatId, String userId) async {
    await _client
        .from('messages')
        .update({'read': true})
        .eq('chat_id', chatId)
        .eq('receiver_id', userId)
        .eq('read', false);
  }

  @override
  String generateChatId(String user1, String user2) {
    final sorted = [user1, user2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }
}
