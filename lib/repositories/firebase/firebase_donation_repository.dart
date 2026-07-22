/// Firebase implementation of [IDonationRepository].

import 'package:cloud_firestore/cloud_firestore.dart';
import '../i_donation_repository.dart';
import '../../models/donation_model.dart';

class FirebaseDonationRepository implements IDonationRepository {
  final FirebaseFirestore _firestore;

  FirebaseDonationRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('donations');

  @override
  Future<void> recordDonation(DonationModel donation) async {
    await _col.add(donation.toFirestore());
  }

  @override
  Future<List<DonationModel>> getDonationHistory(String donorId) async {
    final snap = await _col
        .where('donorId', isEqualTo: donorId)
        .where('isReminder', isEqualTo: false)
        .orderBy('donationDate', descending: true)
        .get();
    return snap.docs
        .map((doc) => DonationModel.fromFirestore(doc.id, doc.data()))
        .toList();
  }

  @override
  Future<List<DonationModel>> getAllDonationHistory() async {
    final snap = await _col
        .where('isReminder', isEqualTo: false)
        .orderBy('donationDate', descending: true)
        .get();
    return snap.docs
        .map((doc) => DonationModel.fromFirestore(doc.id, doc.data()))
        .toList();
  }

  @override
  Future<void> createReminder(DonationModel reminder) async {
    await _col.add(reminder.copyWith(isReminder: true).toFirestore());
  }

  @override
  Future<List<DonationModel>> getPendingReminders(String donorId) async {
    final snap = await _col
        .where('donorId', isEqualTo: donorId)
        .where('isReminder', isEqualTo: true)
        .where('reminderSent', isEqualTo: false)
        .orderBy('reminderDate', descending: false)
        .get();
    return snap.docs
        .map((doc) => DonationModel.fromFirestore(doc.id, doc.data()))
        .toList();
  }

  @override
  Future<List<DonationModel>> getAllPendingReminders() async {
    final snap = await _col
        .where('isReminder', isEqualTo: true)
        .where('reminderSent', isEqualTo: false)
        .orderBy('reminderDate', descending: false)
        .get();
    return snap.docs
        .map((doc) => DonationModel.fromFirestore(doc.id, doc.data()))
        .toList();
  }

  @override
  Future<void> markReminderSent(String reminderId) async {
    await _col.doc(reminderId).update({'reminderSent': true});
  }

  @override
  Future<void> deleteReminder(String reminderId) async {
    await _col.doc(reminderId).delete();
  }
}
