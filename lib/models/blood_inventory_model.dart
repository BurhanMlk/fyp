import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a blood inventory record for a blood bank.
/// Tracks blood stock with expiry and batch management.
class BloodInventoryModel {
  final String id;
  final String bloodBankId;
  final String bloodGroup; // 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'
  final int quantity; // Units available
  final String unit; // 'units', 'ml', 'bags'
  final DateTime collectionDate;
  final DateTime expiryDate;
  final String status; // 'available', 'low_stock', 'expiring_soon', 'expired', 'used'
  final String? batchNumber;
  final String? donorId;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const BloodInventoryModel({
    required this.id,
    required this.bloodBankId,
    required this.bloodGroup,
    this.quantity = 0,
    this.unit = 'units',
    required this.collectionDate,
    required this.expiryDate,
    this.status = 'available',
    this.batchNumber,
    this.donorId,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  /// Determine status based on quantity and expiry date.
  static String computeStatus(int quantity, DateTime expiryDate) {
    final now = DateTime.now();
    final daysUntilExpiry = expiryDate.difference(now).inDays;

    if (quantity <= 0) return 'expired'; // or 'used'
    if (daysUntilExpiry < 0) return 'expired';
    if (daysUntilExpiry <= 7) return 'expiring_soon';
    if (quantity <= 5) return 'low_stock';
    return 'available';
  }

  factory BloodInventoryModel.fromFirestore(String docId, Map<String, dynamic> data) {
    final qty = data['quantity'] is int ? data['quantity'] as int : int.tryParse(data['quantity']?.toString() ?? '0') ?? 0;
    final expiry = _parseDateTime(data['expiryDate']) ?? DateTime.now();

    return BloodInventoryModel(
      id: docId,
      bloodBankId: (data['bloodBankId'] ?? '').toString(),
      bloodGroup: (data['bloodGroup'] ?? '').toString(),
      quantity: qty,
      unit: (data['unit'] ?? 'units').toString(),
      collectionDate: _parseDateTime(data['collectionDate']) ?? DateTime.now(),
      expiryDate: expiry,
      status: (data['status'] ?? computeStatus(qty, expiry)).toString(),
      batchNumber: data['batchNumber']?.toString(),
      donorId: data['donorId']?.toString(),
      notes: data['notes']?.toString(),
      createdAt: _parseDateTime(data['createdAt']),
      updatedAt: _parseDateTime(data['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    final computedStatus = computeStatus(quantity, expiryDate);
    return {
      'bloodBankId': bloodBankId,
      'bloodGroup': bloodGroup,
      'quantity': quantity,
      'unit': unit,
      'collectionDate': collectionDate.toIso8601String(),
      'expiryDate': expiryDate.toIso8601String(),
      'status': status == 'available' ? computedStatus : status,
      if (batchNumber != null) 'batchNumber': batchNumber,
      if (donorId != null) 'donorId': donorId,
      if (notes != null) 'notes': notes,
      'createdAt': createdAt?.toIso8601String() ?? FieldValue.serverTimestamp(),
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'blood_bank_id': bloodBankId,
    'blood_group': bloodGroup,
    'quantity': quantity,
    'unit': unit,
    'collection_date': collectionDate.toIso8601String(),
    'expiry_date': expiryDate.toIso8601String(),
    'status': status,
    'batch_number': batchNumber,
    'donor_id': donorId,
    'notes': notes,
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    return DateTime.tryParse(value.toString());
  }
}
