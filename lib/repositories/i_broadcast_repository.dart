/// Abstract repository interface for broadcast operations.
/// Implementations: [FirebaseBroadcastRepository], [SupabaseBroadcastRepository]

import '../models/broadcast_model.dart';

abstract class IBroadcastRepository {
  /// Send a broadcast message
  Future<void> sendBroadcast(BroadcastModel broadcast);

  /// Get all broadcast history
  Future<List<BroadcastModel>> getBroadcastHistory();

  /// Get broadcasts for a specific target audience
  Future<List<BroadcastModel>> getBroadcastsForAudience(String audience);
}
