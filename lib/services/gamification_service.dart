import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GamificationService {
  // Demo: achievements stored per-user as 'achievements_<email>' (List<String> of JSON objects)
  // Demo: leaderboard stored as 'leaderboard' (List<String> of JSON objects {name,email,score})

  static Future<void> awardDonationAchievementDemo(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'achievements_$email';
    final existing = prefs.getStringList(key) ?? [];

    // Parse existing into map list
    final parsed = existing.map((s) {
      try {
        return jsonDecode(s) as Map<String, dynamic>;
      } catch (_) {
        return <String, dynamic>{};
      }
    }).where((m) => m.isNotEmpty).toList();

    // Find 'first_donation' achievement and mark unlocked
    bool changed = false;
    for (final m in parsed) {
      if ((m['id'] ?? '') == 'first_donation' && m['unlocked'] != true) {
        m['unlocked'] = true;
        m['unlockedAt'] = DateTime.now().toIso8601String();
        changed = true;
      }
    }

    // If no achievements existed, seed a minimal set with first_donation unlocked
    if (parsed.isEmpty) {
      parsed.addAll([
        {'id': 'first_donation', 'title': 'First Donation', 'desc': 'Donate blood for the first time', 'unlocked': true, 'unlockedAt': DateTime.now().toIso8601String()},
        {'id': 'top_donor', 'title': 'Top Donor', 'desc': 'Donate 4 times', 'unlocked': false},
        {'id': 'helper', 'title': 'Helper', 'desc': 'Refer a new donor', 'unlocked': false},
      ]);
      changed = true;
    }

    if (changed) {
      await prefs.setStringList(key, parsed.map((e) => jsonEncode(e)).toList());
    }

    // Update leaderboard score (score = count unlocked)
    final lb = prefs.getStringList('leaderboard') ?? <String>[];
    final score = parsed.where((e) => e['unlocked'] == true).length;
    final name = email.split('@').first;

    bool updated = false;
    final newLb = lb.map((s) {
      try {
        final m = jsonDecode(s) as Map<String, dynamic>;
        if ((m['email'] ?? '') == email) {
          m['score'] = score;
          updated = true;
          return jsonEncode(m);
        }
      } catch (_) {}
      return s;
    }).toList();
    if (!updated) {
      newLb.add(jsonEncode({'name': name, 'email': email, 'score': score}));
    }
    await prefs.setStringList('leaderboard', newLb);
  }

  // Firestore: writes to user's `gamification` subcollection and updates a `leaderboard` collection
  static Future<void> awardDonationAchievementFirestore(String uid, String email, {FirebaseFirestore? firestore}) async {
    final fs = firestore ?? FirebaseFirestore.instance;
    final userRef = fs.collection('users').doc(uid);

    // Ensure a gamification doc exists and set first_donation unlocked
    final gameref = userRef.collection('gamification').doc('achievements');
    final snapshot = await gameref.get();
    Map<String, dynamic> data = {};
    if (snapshot.exists) data = snapshot.data()!;

    final achievements = Map<String, dynamic>.from(data['list'] ?? {});
    if (achievements['first_donation'] != true) {
      achievements['first_donation'] = {'unlocked': true, 'unlockedAt': FieldValue.serverTimestamp()};
      await gameref.set({'list': achievements}, SetOptions(merge: true));
    }

    // Compute score = unlocked count
    final unlockedCount = achievements.values.where((v) => (v is Map && v['unlocked'] == true)).length;

    // Upsert leaderboard entry in a `leaderboard` collection keyed by uid
    final lbRef = fs.collection('leaderboard').doc(uid);
    await lbRef.set({'name': email.split('@').first, 'email': email, 'score': unlockedCount}, SetOptions(merge: true));
  }
}
