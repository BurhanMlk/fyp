/// Firebase implementation of [IBroadcastRepository].

import 'package:cloud_firestore/cloud_firestore.dart';
import '../i_broadcast_repository.dart';
import '../../models/broadcast_model.dart';

class FirebaseBroadcastRepository implements IBroadcastRepository {
  final FirebaseFirestore _firestore;

  FirebaseBroadcastRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('broadcasts');

  @override
  Future<void> sendBroadcast(BroadcastModel broadcast) async {
    await _col.add(broadcast.toFirestore());
  }

  @override
  Future<List<BroadcastModel>> getBroadcastHistory() async {
    final snap = await _col
        .orderBy('sentAt', descending: true)
        .get();
    return snap.docs
        .map((doc) => BroadcastModel.fromFirestore(doc.id, doc.data()))
        .toList();
  }

  @override
  Future<List<BroadcastModel>> getBroadcastsForAudience(String audience) async {
    final snap = await _col
        .where('targetAudience', isEqualTo: audience)
        .orderBy('sentAt', descending: true)
        .get();
    return snap.docs
        .map((doc) => BroadcastModel.fromFirestore(doc.id, doc.data()))
        .toList();
  }
}
