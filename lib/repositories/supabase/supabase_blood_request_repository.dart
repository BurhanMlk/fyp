/// Supabase implementation of [IBloodRequestRepository].

import 'package:supabase_flutter/supabase_flutter.dart';
import '../i_blood_request_repository.dart';
import '../../models/blood_request_model.dart';

class SupabaseBloodRequestRepository implements IBloodRequestRepository {
  final SupabaseClient _client;

  SupabaseBloodRequestRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  @override
  Future<String> createRequest(BloodRequestModel request) async {
    final data = await _client
        .from('blood_requests')
        .insert(request.toJson())
        .select('id')
        .single();
    return (data['id'] ?? '').toString();
  }

  @override
  Future<BloodRequestModel?> getRequestById(String requestId) async {
    try {
      final data = await _client.from('blood_requests').select().eq('id', requestId).single();
      return BloodRequestModel.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<BloodRequestModel>> getAllRequests() async {
    final data = await _client
        .from('blood_requests')
        .select()
        .order('requested_at', ascending: false);
    return (data as List).map((json) => BloodRequestModel.fromJson(json)).toList();
  }

  @override
  Future<List<BloodRequestModel>> getRequestsForDonor(String donorEmail) async {
    final data = await _client
        .from('blood_requests')
        .select()
        .eq('donor_email', donorEmail)
        .order('requested_at', ascending: false);
    return (data as List).map((json) => BloodRequestModel.fromJson(json)).toList();
  }

  @override
  Future<List<BloodRequestModel>> getRequestsForRecipient(String recipientEmail) async {
    final data = await _client
        .from('blood_requests')
        .select()
        .eq('recipient_email', recipientEmail)
        .order('requested_at', ascending: false);
    return (data as List).map((json) => BloodRequestModel.fromJson(json)).toList();
  }

  @override
  Future<List<BloodRequestModel>> getPendingRequests() => getRequestsByStatus('pending');

  @override
  Future<List<BloodRequestModel>> getRequestsByStatus(String status) async {
    final data = await _client
        .from('blood_requests')
        .select()
        .eq('status', status)
        .order('requested_at', ascending: false);
    return (data as List).map((json) => BloodRequestModel.fromJson(json)).toList();
  }

  @override
  Future<List<BloodRequestModel>> getRequestsByType(String type) async {
    final data = await _client
        .from('blood_requests')
        .select()
        .eq('type', type)
        .order('requested_at', ascending: false);
    return (data as List).map((json) => BloodRequestModel.fromJson(json)).toList();
  }

  @override
  Future<void> updateRequestStatus(String requestId, String status, {String? responseMessage}) async {
    final updates = <String, dynamic>{
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (responseMessage != null) updates['response_message'] = responseMessage;
    if (status == 'approved' || status == 'rejected') {
      updates['responded_at'] = DateTime.now().toIso8601String();
    }
    await _client.from('blood_requests').update(updates).eq('id', requestId);
  }

  @override
  Future<void> updateRequest(String requestId, Map<String, dynamic> updates) async {
    updates['updated_at'] = DateTime.now().toIso8601String();
    await _client.from('blood_requests').update(updates).eq('id', requestId);
  }

  @override
  Future<void> deleteRequest(String requestId) async {
    await _client.from('blood_requests').delete().eq('id', requestId);
  }

  @override
  Future<int> getPendingRequestsCount() async {
    final data = await _client
        .from('blood_requests')
        .select('id')
        .eq('status', 'pending');
    return (data as List).length;
  }

  @override
  Future<bool> hasApprovedDonorAccess(String requesterEmail, String donorEmail) async {
    final data = await _client
        .from('blood_requests')
        .select('id')
        .eq('type', 'donor_access_request')
        .eq('requester_email', requesterEmail)
        .eq('donor_email', donorEmail)
        .eq('status', 'approved')
        .limit(1);
    return (data as List).isNotEmpty;
  }
}
