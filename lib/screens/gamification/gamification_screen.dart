import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/firebase_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'leaderboard_screen.dart';

class GamificationScreen extends StatelessWidget {
  const GamificationScreen({super.key});

  Widget _achievementTile(BuildContext context, IconData icon, String title, String subtitle) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1), child: Icon(icon, color: Theme.of(context).primaryColor)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gamification & Engagement'),
        elevation: 1,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(18.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Gamification & Engagement Module', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Container(
                                width: 86,
                                height: 86,
                                decoration: BoxDecoration(color: Theme.of(context).primaryColor.withOpacity(0.06), borderRadius: BorderRadius.circular(8)),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.emoji_events, color: Theme.of(context).primaryColor, size: 28),
                                    const SizedBox(height: 8),
                                    const Text('Level', style: TextStyle(fontSize: 12)),
                                    const Text('3', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                                  onPressed: () async {
                                    await _ensureDemoAchievements();
                                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LeaderboardScreen()));
                                  },
                                  child: const Text('Check Leaderboard', style: TextStyle(fontSize: 16)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text('Achievements', style: TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          _achievementTile(context, Icons.check_circle, 'First Donation', 'Donate blood for the first time'),
                          _achievementTile(context, Icons.star, 'Top Donor', 'Donate 4 times'),
                          _achievementTile(context, Icons.person_add, 'Helper', 'Refer a new donor'),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                              onPressed: () async {
                                await _ensureDemoAchievements();
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Achievements synced locally')));
                              },
                              child: const Text('Sync Achievements', style: TextStyle(fontSize: 16)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<String?> _currentUserEmail() async {
    if (FirebaseService.initialized) {
      final user = FirebaseAuth.instance.currentUser;
      return user?.email;
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('demo_current_email');
  }

  Future<void> _ensureDemoAchievements() async {
    final prefs = await SharedPreferences.getInstance();
    final email = await _currentUserEmail() ?? 'demo_user';
    final key = 'achievements_$email';
    final existing = prefs.getStringList(key);
    if (existing != null && existing.isNotEmpty) return; // already persisted

    final sample = [
      {'id': 'first_donation', 'title': 'First Donation', 'desc': 'Donate blood for the first time', 'unlocked': true, 'unlockedAt': DateTime.now().toIso8601String()},
      {'id': 'top_donor', 'title': 'Top Donor', 'desc': 'Donate 4 times', 'unlocked': false},
      {'id': 'helper', 'title': 'Helper', 'desc': 'Refer a new donor', 'unlocked': false},
    ];
    await prefs.setStringList(key, sample.map((e) => jsonEncode(e)).toList());

    // Update leaderboard entry for this user (simple score = unlocked count)
    final lb = prefs.getStringList('leaderboard') ?? <String>[];
    final score = sample.where((e) => e['unlocked'] == true).length;
    final name = email.split('@').first;
    // If user exists in leaderboard, update score, else add new
    bool updated = false;
    final newLb = lb.map((s) {
      try {
        final m = jsonDecode(s) as Map<String, dynamic>;
        if ((m['email'] ?? '') == email) {
          updated = true;
          m['score'] = score;
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
}
