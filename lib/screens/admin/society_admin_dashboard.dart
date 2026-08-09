import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/service_locator.dart';
import '../../widgets/blood_bridge_loader.dart';
import '../../widgets/top_snackbar.dart';

/// Society Admin Dashboard
/// Manages a single society: members, donors, events, campaigns.

class SocietyAdminDashboard extends StatefulWidget {
  const SocietyAdminDashboard({super.key});

  @override
  State<SocietyAdminDashboard> createState() => _SocietyAdminDashboardState();
}

class _SocietyAdminDashboardState extends State<SocietyAdminDashboard> {
  String? _societyId;
  String _societyName = '';
  Map<String, dynamic>? _societyData;
  int _totalMembers = 0;
  int _activeDonors = 0;
  int _totalDonations = 0;
  int _pendingRequests = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};
      _societyId = userData['societyId']?.toString();

      if (_societyId != null) {
        final orgDoc = await FirebaseFirestore.instance.collection('organizations').doc(_societyId).get();
        if (orgDoc.exists) {
          _societyData = orgDoc.data();
          _societyName = (_societyData?['name'] ?? 'Society').toString();
        }

        // Count members
        final membersSnap = await FirebaseFirestore.instance
            .collection('users')
            .where('societyId', isEqualTo: _societyId)
            .get();
        _totalMembers = membersSnap.docs.length;
        _activeDonors = membersSnap.docs.where((d) =>
            d.data()['isDonor'] == true && d.data()['approved'] == true).length;
      }
    } catch (e) {
      if (mounted) showTopSnackBar(context, message: 'Error: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _showAddMemberDialog() {
    final emailCtl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Member'),
        content: TextField(
          controller: emailCtl,
          decoration: const InputDecoration(
            labelText: 'Member Email',
            hintText: 'Enter email to invite',
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final email = emailCtl.text.trim();
              if (email.isEmpty) return;

              // Find user by email and update their societyId
              try {
                final snap = await FirebaseFirestore.instance
                    .collection('users')
                    .where('email', isEqualTo: email)
                    .limit(1)
                    .get();

                if (snap.docs.isEmpty) {
                  showTopSnackBar(context, message: 'User not found with that email');
                  return;
                }

                final userId = snap.docs.first.id;
                final userData = snap.docs.first.data();
                await FirebaseFirestore.instance.collection('users').doc(userId).update({
                  'societyId': _societyId,
                  'universityId': _societyData?['universityId'],
                  'organizationId': _societyId,
                  'role': userData['isDonor'] == true ? 'donor' : 'volunteer',
                });

                Navigator.pop(context);
                showTopSnackBar(context, message: 'Member added!', backgroundColor: Colors.green.shade700);
                _loadData();
              } catch (e) {
                showTopSnackBar(context, message: 'Error: $e');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: BloodBridgeLoader()));

    if (_societyId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Society'), backgroundColor: Colors.red.shade700),
        body: const Center(child: Text('No society assigned to your account.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_societyName),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Society Info
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.green.shade100,
                        child: const Icon(Icons.groups, size: 30, color: Colors.green),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_societyName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            if (_societyData?['description'] != null)
                              Text(_societyData!['description'], style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Stats
              Row(
                children: [
                  _statCard('Members', '$_totalMembers', Icons.people, Colors.blue),
                  const SizedBox(width: 8),
                  _statCard('Donors', '$_activeDonors', Icons.volunteer_activism, Colors.red),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _statCard('Donations', '$_totalDonations', Icons.favorite, Colors.pink),
                  const SizedBox(width: 8),
                  _statCard('Requests', '$_pendingRequests', Icons.bloodtype, Colors.orange),
                ],
              ),
              const SizedBox(height: 20),

              // Quick Actions
              const Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _actionCard(Icons.person_add, 'Add Member', _showAddMemberDialog),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _actionCard(Icons.campaign, 'Campaign', () {
                      showTopSnackBar(context, message: 'Coming soon!', backgroundColor: Colors.blue.shade700);
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _actionCard(Icons.event, 'Create Event', () {
                      showTopSnackBar(context, message: 'Coming soon!', backgroundColor: Colors.blue.shade700);
                    }),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _actionCard(Icons.analytics, 'Reports', () {
                      showTopSnackBar(context, message: 'Coming soon!', backgroundColor: Colors.blue.shade700);
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 11), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionCard(IconData icon, String label, VoidCallback onTap) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: Colors.red.shade700, size: 32),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}
