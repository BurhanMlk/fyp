/// Abstract repository interface for blood inventory operations.

import '../models/blood_inventory_model.dart';

abstract class IBloodInventoryRepository {
  /// Add a blood unit to inventory
  Future<String> addInventory(BloodInventoryModel inventory);

  /// Get inventory by ID
  Future<BloodInventoryModel?> getInventoryById(String inventoryId);

  /// Get all inventory for a blood bank
  Future<List<BloodInventoryModel>> getInventoryForBloodBank(String bloodBankId);

  /// Get inventory by blood group for a blood bank
  Future<List<BloodInventoryModel>> getInventoryByBloodGroup(String bloodBankId, String bloodGroup);

  /// Get low stock items
  Future<List<BloodInventoryModel>> getLowStockItems(String bloodBankId);

  /// Get expiring soon items
  Future<List<BloodInventoryModel>> getExpiringSoonItems(String bloodBankId);

  /// Update inventory quantity
  Future<void> updateQuantity(String inventoryId, int newQuantity);

  /// Mark inventory as used/expired
  Future<void> updateStatus(String inventoryId, String status);

  /// Delete an inventory record
  Future<void> deleteInventory(String inventoryId);

  /// Get blood group summary for a blood bank
  Future<Map<String, int>> getBloodGroupSummary(String bloodBankId);

  /// Get total available units for a blood bank
  Future<int> getTotalAvailableUnits(String bloodBankId);
}
