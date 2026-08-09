/// Abstract repository interface for organization (tenant) operations.

import '../models/organization_model.dart';

abstract class IOrganizationRepository {
  /// Create a new organization registration request
  Future<String> createOrganization(OrganizationModel org);

  /// Get organization by ID
  Future<OrganizationModel?> getOrganizationById(String orgId);

  /// Get all organizations (super admin only)
  Future<List<OrganizationModel>> getAllOrganizations();

  /// Get organizations by type (university, society, blood_bank, ngo)
  Future<List<OrganizationModel>> getOrganizationsByType(String type);

  /// Get organizations by status (pending, approved, active, suspended)
  Future<List<OrganizationModel>> getOrganizationsByStatus(String status);

  /// Get societies belonging to a university
  Future<List<OrganizationModel>> getSocietiesByUniversity(String universityId);

  /// Update organization details
  Future<void> updateOrganization(String orgId, Map<String, dynamic> updates);

  /// Approve an organization registration
  Future<void> approveOrganization(String orgId);

  /// Reject an organization registration
  Future<void> rejectOrganization(String orgId);

  /// Suspend an organization
  Future<void> suspendOrganization(String orgId);

  /// Activate a suspended organization
  Future<void> activateOrganization(String orgId);

  /// Delete an organization (only if safe — no active users/requests)
  Future<void> deleteOrganization(String orgId);

  /// Get organization count by type
  Future<Map<String, int>> getOrganizationCountByType();

  /// Get pending approval count
  Future<int> getPendingApprovalCount();

  /// Search organizations by name or email
  Future<List<OrganizationModel>> searchOrganizations(String query);

  /// Get organizations for a specific admin user
  Future<OrganizationModel?> getOrganizationByAdminId(String adminId);
}
