/// Abstract repository interface for blood request operations.
/// Implementations: [FirebaseBloodRequestRepository], [SupabaseBloodRequestRepository]

import '../models/blood_request_model.dart';

abstract class IBloodRequestRepository {
  /// Create a new blood request
  Future<String> createRequest(BloodRequestModel request);

  /// Get a single request by ID
  Future<BloodRequestModel?> getRequestById(String requestId);

  /// Get all requests
  Future<List<BloodRequestModel>> getAllRequests();

  /// Get requests for a specific donor
  Future<List<BloodRequestModel>> getRequestsForDonor(String donorEmail);

  /// Get requests made by a specific recipient
  Future<List<BloodRequestModel>> getRequestsForRecipient(String recipientEmail);

  /// Get pending requests
  Future<List<BloodRequestModel>> getPendingRequests();

  /// Get requests by status
  Future<List<BloodRequestModel>> getRequestsByStatus(String status);

  /// Get requests by type (e.g., 'donor_access_request', 'emergency')
  Future<List<BloodRequestModel>> getRequestsByType(String type);

  /// Update request status
  Future<void> updateRequestStatus(String requestId, String status, {String? responseMessage});

  /// Update a request
  Future<void> updateRequest(String requestId, Map<String, dynamic> updates);

  /// Delete a request
  Future<void> deleteRequest(String requestId);

  /// Get pending requests count
  Future<int> getPendingRequestsCount();

  /// Check if a requester has approved donor access
  Future<bool> hasApprovedDonorAccess(String requesterEmail, String donorEmail);
}
