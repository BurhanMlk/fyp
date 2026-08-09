import 'package:cloud_firestore/cloud_firestore.dart';
import '../i_blood_inventory_repository.dart';
import '../../models/blood_inventory_model.dart';

class FirebaseBloodInventoryRepository implements IBloodInventoryRepository {
  static const String _collection = 'blood_inventory';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Future<String> addInventory(BloodInventoryModel inventory) async {
    final docRef = await _firestore.collection(_collection).add(inventory.toFirestore());
    return docRef.id;
  }

  @override
  Future<BloodInventoryModel?> getInventoryById(String inventoryId) async {
    final doc = await _firestore.collection(_collection).doc(inventoryId).get();
    if (!doc.exists) return null;
    return BloodInventoryModel.fromFirestore(doc.id, doc.data() ?? {});
  }

  @override
  Future<List<BloodInventoryModel>> getInventoryForBloodBank(String bloodBankId) async {
    final snap = await _firestore
        .collection(_collection)
        .where('bloodBankId', isEqualTo: bloodBankId)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map((d) => BloodInventoryModel.fromFirestore(d.id, d.data())).toList();
  }

  @override
  Future<List<BloodInventoryModel>> getInventoryByBloodGroup(String bloodBankId, String bloodGroup) async {
    final snap = await _firestore
        .collection(_collection)
        .where('bloodBankId', isEqualTo: bloodBankId)
        .where('bloodGroup', isEqualTo: bloodGroup)
        .get();
    return snap.docs.map((d) => BloodInventoryModel.fromFirestore(d.id, d.data())).toList();
  }

  @override
  Future<List<BloodInventoryModel>> getLowStockItems(String bloodBankId) async {
    final snap = await _firestore
        .collection(_collection)
        .where('bloodBankId', isEqualTo: bloodBankId)
        .where('quantity', isLessThanOrEqualTo: 5)
        .where('quantity', isGreaterThan: 0)
        .get();
    return snap.docs.map((d) => BloodInventoryModel.fromFirestore(d.id, d.data())).toList();
  }

  @override
  Future<List<BloodInventoryModel>> getExpiringSoonItems(String bloodBankId) async {
    final now = DateTime.now();
    final cutoff = now.add(const Duration(days: 7));
    final snap = await _firestore
        .collection(_collection)
        .where('bloodBankId', isEqualTo: bloodBankId)
        .get();
    return snap.docs
        .map((d) => BloodInventoryModel.fromFirestore(d.id, d.data()))
        .where((item) => item.expiryDate.isBefore(cutoff) && item.expiryDate.isAfter(now))
        .toList();
  }

  @override
  Future<void> updateQuantity(String inventoryId, int newQuantity) async {
    await _firestore.collection(_collection).doc(inventoryId).update({
      'quantity': newQuantity,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> updateStatus(String inventoryId, String status) async {
    await _firestore.collection(_collection).doc(inventoryId).update({
      'status': status,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> deleteInventory(String inventoryId) async {
    await _firestore.collection(_collection).doc(inventoryId).delete();
  }

  @override
  Future<Map<String, int>> getBloodGroupSummary(String bloodBankId) async {
    final snap = await _firestore
        .collection(_collection)
        .where('bloodBankId', isEqualTo: bloodBankId)
        .get();
    final summary = <String, int>{};
    for (final doc in snap.docs) {
      final bg = (doc.data()['bloodGroup'] ?? '').toString();
      final qty = doc.data()['quantity'] is int ? doc.data()['quantity'] as int : 0;
      summary[bg] = (summary[bg] ?? 0) + qty;
    }
    return summary;
  }

  @override
  Future<int> getTotalAvailableUnits(String bloodBankId) async {
    final snap = await _firestore
        .collection(_collection)
        .where('bloodBankId', isEqualTo: bloodBankId)
        .get();
    int total = 0;
    for (final doc in snap.docs) {
      final status = (doc.data()['status'] ?? '').toString();
      if (status != 'expired' && status != 'used') {
        total += doc.data()['quantity'] is int ? doc.data()['quantity'] as int : 0;
      }
    }
    return total;
  }
}
