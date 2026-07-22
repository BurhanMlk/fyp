/// Supabase implementation of [IBroadcastRepository].

import 'package:supabase_flutter/supabase_flutter.dart';
import '../i_broadcast_repository.dart';
import '../../models/broadcast_model.dart';

class SupabaseBroadcastRepository implements IBroadcastRepository {
  final SupabaseClient _client;

  SupabaseBroadcastRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  @override
  Future<void> sendBroadcast(BroadcastModel broadcast) async {
    await _client.from('broadcasts').insert(broadcast.toJson());
  }

  @override
  Future<List<BroadcastModel>> getBroadcastHistory() async {
    final data = await _client
        .from('broadcasts')
        .select()
        .order('sent_at', ascending: false);
    return (data as List).map((json) => BroadcastModel.fromJson(json)).toList();
  }

  @override
  Future<List<BroadcastModel>> getBroadcastsForAudience(String audience) async {
    final data = await _client
        .from('broadcasts')
        .select()
        .eq('target_audience', audience)
        .order('sent_at', ascending: false);
    return (data as List).map((json) => BroadcastModel.fromJson(json)).toList();
  }
}
