/// Supabase implementation of [IDonationRepository].

import 'package:supabase_flutter/supabase_flutter.dart';
import '../i_donation_repository.dart';
import '../../models/donation_model.dart';

class SupabaseDonationRepository implements IDonationRepository {
  final SupabaseClient _client;

  SupabaseDonationRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  @override
  Future<void> recordDonation(DonationModel donation) async {
    await _client.from('donations').insert(donation.toJson());
  }

  @override
  Future<List<DonationModel>> getDonationHistory(String donorId) async {
    final data = await _client
        .from('donations')
        .select()
        .eq('donor_id', donorId)
        .eq('is_reminder', false)
        .order('donation_date', ascending: false);
    return (data as List).map((json) => DonationModel.fromJson(json)).toList();
  }

  @override
  Future<List<DonationModel>> getAllDonationHistory() async {
    final data = await _client
        .from('donations')
        .select()
        .eq('is_reminder', false)
        .order('donation_date', ascending: false);
    return (data as List).map((json) => DonationModel.fromJson(json)).toList();
  }

  @override
  Future<void> createReminder(DonationModel reminder) async {
    final data = reminder.toJson();
    data['is_reminder'] = true;
    await _client.from('donations').insert(data);
  }

  @override
  Future<List<DonationModel>> getPendingReminders(String donorId) async {
    final data = await _client
        .from('donations')
        .select()
        .eq('donor_id', donorId)
        .eq('is_reminder', true)
        .eq('reminder_sent', false)
        .order('reminder_date', ascending: true);
    return (data as List).map((json) => DonationModel.fromJson(json)).toList();
  }

  @override
  Future<List<DonationModel>> getAllPendingReminders() async {
    final data = await _client
        .from('donations')
        .select()
        .eq('is_reminder', true)
        .eq('reminder_sent', false)
        .order('reminder_date', ascending: true);
    return (data as List).map((json) => DonationModel.fromJson(json)).toList();
  }

  @override
  Future<void> markReminderSent(String reminderId) async {
    await _client.from('donations').update({'reminder_sent': true}).eq('id', reminderId);
  }

  @override
  Future<void> deleteReminder(String reminderId) async {
    await _client.from('donations').delete().eq('id', reminderId);
  }
}
