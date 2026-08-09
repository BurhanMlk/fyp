import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/service_locator.dart';
import '../../widgets/blood_bridge_loader.dart';
import '../../widgets/top_snackbar.dart';

/// University Admin Dashboard
/// Manages university profile, societies, donors, and reports.

class UniversityAdminDashboard extends StatefulWidget {
  const UniversityAdminDashboard({super.key});

  @override
  State<UniversityAdminDashboard> createState() => _UniversityAdminDashboardState();
}

class _UniversityAdminDashboardState extends State<UniversityAdminDashboard> {
  String? _universityId;
  String _universityName = '';
  Map<String, dynamic>? _universityData;
  List<Map<String, dynamic>> _societies = [];
  int _totalMembers = 0;
  int _totalDonors = 0;
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
      _universityId = userData['universityId']?.toString();

      if (_universityId != null) {
        // Get university details
        final orgDoc = await FirebaseFirestore.instance.collection('organizations').doc(_universityId).get();
        if (orgDoc.exists) {
          _universityData = orgDoc.data();
          _universityName = (_universityData?['name'] ?? 'University').toString();
        }

        // Get societies
        final societiesSnap = await FirebaseFirestore.instance
            .collection('organizations')
            .where('type', isEqualTo: 'society')
            .where('universityId', isEqualTo: _universityId)
            .get();
        _societies = societiesSnap.docs.map((d) {
          final data = d.data();
          data['id'] = d.id;
          return data;
        }).toList();

        // Count members/donors
        final membersSnap = await FirebaseFirestore.instance
            .collection('users')
            .where('universityId', isEqualTo: _universityId)
            .get();
        _totalMembers = membersSnap.docs.length;
        _totalDonors = membersSnap.docs.where((d) => d.data()['isDonor'] == true).length;
      }
    } catch (e) {
      if (mounted) showTopSnackBar(context, message: 'Error: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: BloodBridgeLoader()));

    return Scaffold(
      appBar: AppBar(
        title: Text(_universityName),
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
              // University Info Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.red.shade100,
                        child: const Icon(Icons.school, size: 30, color: Colors.red),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_universityName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            if (_universityData?['city'] != null)
                              Text('📍 ${_universityData?['city']}', style: TextStyle(color: Colors.grey.shade600)),
                            if (_universityData?['email'] != null)
                              Text('📧 ${_universityData?['email']}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Stats Cards
              Row(
                children: [
                  _statCard('Total Members', '$_totalMembers', Icons.people, Colors.blue),
                  const SizedBox(width: 8),
                  _statCard('Total Donors', '$_totalDonors', Icons.volunteer_activism, Colors.red),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _statCard('Societies', '${_societies.length}', Icons.groups, Colors.green),
                  const SizedBox(width: 8),
                  _statCard('Approved', '${_societies.where((s) => s['status'] == 'active' || s['status'] == 'approved').length}', Icons.check_circle, Colors.teal),
                ],
              ),
              const SizedBox(height: 20),

              // Societies List
              const Text('University Societies', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (_societies.isEmpty)
                const Card(child: Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No societies yet'))))
              else
                ..._societies.map((society) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.green.shade100,
                      child: const Icon(Icons.groups, color: Colors.green),
                    ),
                    title: Text(society['name'] ?? 'Society', style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(society['email'] ?? ''),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: (society['status'] == 'active' || society['status'] == 'approved')
                            ? Colors.green.shade100 : Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        (society['status'] ?? 'pending').toString().toUpperCase(),
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green.shade700),
                      ),
                    ),
                  ),
                )),
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
}
