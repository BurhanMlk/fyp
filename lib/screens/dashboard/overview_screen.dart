import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../services/firebase_service.dart';
import '../../widgets/animated_blood_bg.dart';
import 'donors_detail_screen.dart';
import 'pending_requests_screen.dart';

class OverviewScreen extends StatefulWidget {
  const OverviewScreen({super.key});

  @override
  _OverviewScreenState createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  int _totalDonors = 0;
  int _totalRecipients = 0;
  int _pendingRequests = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOverviewData();
  }

  Future<void> _loadOverviewData() async {
    setState(() => _isLoading = true);
    
    if (FirebaseService.initialized) {
      await _loadFirebaseData();
    } else {
      await _loadDemoData();
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _loadFirebaseData() async {
    try {
      final donorsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'donor')
          .get();
      _totalDonors = donorsSnapshot.docs.length;

      final recipientsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'recipient')
          .get();
      _totalRecipients = recipientsSnapshot.docs.length;

      final requestsSnapshot = await FirebaseFirestore.instance
          .collection('donor_requests')
          .where('status', isEqualTo: 'pending')
          .get();
      _pendingRequests = requestsSnapshot.docs.length;
    } catch (e) {
      print('Error loading Firebase data: $e');
    }
  }

  Future<void> _loadDemoData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final users = prefs.getStringList('demo_users') ?? <String>[];
      
      _totalDonors = 0;
      _totalRecipients = 0;
      
      for (final userStr in users) {
        try {
          final user = jsonDecode(userStr) as Map<String, dynamic>;
          if (user['role'] == 'donor') _totalDonors++;
          if (user['role'] == 'recipient') _totalRecipients++;
        } catch (_) {}
      }

      final requests = prefs.getStringList('donor_requests') ?? <String>[];
      _pendingRequests = 0;
      for (final reqStr in requests) {
        try {
          final req = jsonDecode(reqStr) as Map<String, dynamic>;
          if (req['status'] == 'pending') _pendingRequests++;
        } catch (_) {}
      }
    } catch (e) {
      print('Error loading demo data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Overview',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.red.shade700, Colors.red.shade400, Colors.pink.shade300],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          // Gradient background
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFF3F4F6), Color(0xFFFFFFFF)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          // Animated blood cells
          Positioned.fill(child: AnimatedBloodBackground(cellCount: 9)),
          // Main content
          RefreshIndicator(
            onRefresh: _loadOverviewData,
            child: SingleChildScrollView(
              physics: AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 16),
                  Text(
                    'Statistics Overview',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF212121),
                    ),
                  ),
                  SizedBox(height: 16),
                  GridView.count(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.3,
                    children: [
                      _buildStatCard(
                        'Total Donors',
                        _totalDonors.toString(),
                        Icons.bloodtype,
                        Color(0xFFFF6B9D),
                        Color(0xFFFF8FAB),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => DonorsDetailScreen()),
                          );
                        },
                      ),
                      _buildStatCard(
                        'Pending Requests',
                        _pendingRequests.toString(),
                        Icons.pending_actions,
                        Color(0xFFFFB74D),
                        Color(0xFFFFCC80),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => PendingRequestsScreen()),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color startColor, Color endColor, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: startColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: startColor, size: 32),
            ),
            SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
