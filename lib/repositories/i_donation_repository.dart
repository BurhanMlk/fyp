/// Abstract repository interface for donation history and reminders.
/// Implementations: [FirebaseDonationRepository], [SupabaseDonationRepository]

import '../models/donation_model.dart';

abstract class IDonationRepository {
  /// Record a donation
  Future<void> recordDonation(DonationModel donation);

  /// Get donation history for a donor
  Future<List<DonationModel>> getDonationHistory(String donorId);

  /// Get all donation history (admin)
  Future<List<DonationModel>> getAllDonationHistory();

  /// Create a donation reminder
  Future<void> createReminder(DonationModel reminder);

  /// Get pending reminders for a donor
  Future<List<DonationModel>> getPendingReminders(String donorId);

  /// Get all pending reminders (admin)
  Future<List<DonationModel>> getAllPendingReminders();

  /// Mark a reminder as sent
  Future<void> markReminderSent(String reminderId);

  /// Delete a reminder
  Future<void> deleteReminder(String reminderId);
}
