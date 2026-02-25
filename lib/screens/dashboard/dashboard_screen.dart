import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../services/firebase_service.dart';
import '../../widgets/animated_blood_bg.dart';
import '../profile/profile_screen.dart';
import '../emergency/emergency_request_screen.dart';
import '../donors/donor_list_screen.dart';
import 'all_users_screen.dart';
import 'pending_requests_screen.dart';
import 'donors_detail_screen.dart';
import 'recipients_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _userName = '';
  String _userRole = '';
  int _totalDonors = 0;
  int _totalRecipients = 0;
  int _pendingRequests = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
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
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          _userName = userDoc.data()?['name'] ?? 'User';
          _userRole = userDoc.data()?['role'] ?? 'user';
        }
      }

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
      final currentEmail = prefs.getString('demo_current_email');
      final users = prefs.getStringList('demo_users') ?? <String>[];
      
      for (final userStr in users) {
        try {
          final user = jsonDecode(userStr) as Map<String, dynamic>;
          if (user['email'] == currentEmail) {
            _userName = user['name'] ?? 'User';
            _userRole = user['role'] ?? 'user';
          }
          
          if (user['role'] == 'donor') _totalDonors++;
          if (user['role'] == 'recipient') _totalRecipients++;
        } catch (_) {}
      }

      final requests = prefs.getStringList('donor_requests') ?? <String>[];
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
      return Center(child: CircularProgressIndicator());
    }

    return Scaffold(
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
            onRefresh: _loadDashboardData,
            child: SingleChildScrollView(
              physics: AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(16),
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Card
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFF6B9D), Color(0xFFFF8FAB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFFFF6B9D).withOpacity(0.3),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.waving_hand, color: Colors.white, size: 28),
                        SizedBox(width: 8),
                        Text(
                          'Welcome Back!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      _userName.toUpperCase(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 4),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF00BCD4), Color(0xFF00ACC1)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        _userRole.toUpperCase(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),

              // Quick Actions
              Row(
                children: [
                  Icon(Icons.flash_on, color: Color(0xFFFFB74D), size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Quick Actions',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF212121),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              _buildQuickActionCard(
                'My Profile',
                'View and update your profile information',
                Icons.account_circle,
                Colors.purple.shade600,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ProfileScreen()),
                  );
                },
              ),
              SizedBox(height: 12),
              _buildQuickActionCard(
                'Blood Request',
                'Request blood from available donors',
                Icons.bloodtype,
                Colors.red.shade600,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => EmergencyRequestScreen()),
                  );
                },
              ),
              SizedBox(height: 12),
              _buildQuickActionCard(
                'Search Donors',
                'Find donors by blood group and location',
                Icons.person_search,
                Colors.green.shade600,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => DonorListScreen()),
                  );
                },
              ),
              SizedBox(height: 24),
              
              // Modules Section
              Row(
                children: [
                  Icon(Icons.apps, color: Color(0xFF1976D2), size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Features',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF212121),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              
              // Donation History
              _buildQuickActionCard(
                'Donation History',
                'View your donation records and reminders',
                Icons.history,
                Colors.teal.shade600,
                onTap: () => _showDonationHistoryDialog(),
              ),
              SizedBox(height: 12),
              
              // Communication
              _buildQuickActionCard(
                'Messages',
                'Chat with hospitals and blood banks',
                Icons.chat,
                Colors.indigo.shade600,
                onTap: () => _showMessagesDialog(),
              ),
              SizedBox(height: 12),
              
              // Achievements & Badges (Only for Donors)
              if (_userRole == 'donor')
                _buildQuickActionCard(
                  'Achievements',
                  'View your badges and points',
                  Icons.emoji_events,
                  Colors.amber.shade700,
                  onTap: () => _showAchievementsDialog(),
                ),
              if (_userRole == 'donor') SizedBox(height: 12),
              
              // Verification Status
              if (_userRole == 'donor')
                _buildQuickActionCard(
                  'Verification Status',
                  'Check your verification and reputation',
                  Icons.verified_user,
                  Colors.blue.shade600,
                  onTap: () => _showVerificationDialog(),
                ),
              if (_userRole == 'donor') SizedBox(height: 12),
              
              // Nearby Blood Banks
              _buildQuickActionCard(
                'Blood Banks',
                'Find nearby hospitals and blood banks',
                Icons.local_hospital,
                Colors.red.shade700,
                onTap: () => _showBloodBanksDialog(),
              ),
            ],
          ),
        ),
          ),
        ],
      ),
    );
  }

  // =====================================================================
  // Module Dialogs
  // =====================================================================
  
  void _showDonationHistoryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white.withOpacity(0.85),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.black, width: 2),
        ),
        title: Row(
          children: [
            Icon(Icons.history, color: Colors.teal),
            SizedBox(width: 8),
            Text('Donation History'),
          ],
        ),
        content: SizedBox(
          width: 400,
          height: 400,
          child: _userRole == 'donor' ? _buildDonorHistory() : _buildRecipientHistory(),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.black,
              side: BorderSide(color: Colors.black, width: 2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDonorHistory() {
    return FutureBuilder(
      future: _loadDonationHistory(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        final donations = snapshot.data as List<Map<String, dynamic>>? ?? [];
        if (donations.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 64, color: Colors.grey[300]),
                SizedBox(height: 16),
                Text('No donation history yet', style: TextStyle(color: Colors.grey)),
                SizedBox(height: 8),
                Text('Your donations will appear here', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
              ],
            ),
          );
        }
        return ListView.builder(
          itemCount: donations.length,
          itemBuilder: (context, i) {
            final d = donations[i];
            return Card(
              margin: EdgeInsets.symmetric(vertical: 4),
              color: Colors.white.withOpacity(0.85),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.black, width: 2),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.red[50],
                  child: Icon(Icons.water_drop, color: Colors.red),
                ),
                title: Text(d['location'] ?? 'Blood Donation'),
                subtitle: Text(d['date'] ?? 'Unknown date'),
                trailing: Icon(Icons.check_circle, color: Colors.green),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRecipientHistory() {
    return FutureBuilder(
      future: _loadReceivedHistory(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        final received = snapshot.data as List<Map<String, dynamic>>? ?? [];
        if (received.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.favorite, size: 64, color: Colors.grey[300]),
                SizedBox(height: 16),
                Text('No received donations yet', style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }
        return ListView.builder(
          itemCount: received.length,
          itemBuilder: (context, i) {
            final r = received[i];
            return Card(
              margin: EdgeInsets.symmetric(vertical: 4),
              color: Colors.white.withOpacity(0.85),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.black, width: 2),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.green[50],
                  child: Icon(Icons.favorite, color: Colors.green),
                ),
                title: Text('Blood received from ${r['donor'] ?? 'Anonymous'}'),
                subtitle: Text(r['date'] ?? 'Unknown date'),
              ),
            );
          },
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _loadDonationHistory() async {
    // Demo data for now
    return [
      {'location': 'City Hospital', 'date': '2026-02-15', 'bloodGroup': 'A+'},
      {'location': 'Red Crescent', 'date': '2025-11-20', 'bloodGroup': 'A+'},
      {'location': 'Blood Bank Center', 'date': '2025-08-10', 'bloodGroup': 'A+'},
    ];
  }

  Future<List<Map<String, dynamic>>> _loadReceivedHistory() async {
    return [
      {'donor': 'Ahmad Khan', 'date': '2026-02-10', 'bloodGroup': 'A+'},
    ];
  }

  void _showMessagesDialog() {
    final messageCtl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.chat, color: Colors.indigo),
            SizedBox(width: 8),
            Text('Messages'),
          ],
        ),
        content: SizedBox(
          width: 400,
          height: 450,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  children: [
                    _chatBubble('City Hospital', 'Your blood request has been received. We will contact you shortly.', '10:30 AM', false),
                    _chatBubble('You', 'Thank you! I need O- blood urgently.', '10:25 AM', true),
                    _chatBubble('Blood Bank', 'Welcome to Blood Bridge! How can we help?', '09:00 AM', false),
                  ],
                ),
              ),
              Divider(),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: messageCtl,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.send, color: Colors.indigo),
                    onPressed: () {
                      if (messageCtl.text.trim().isNotEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Message sent!')));
                        messageCtl.clear();
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Close')),
        ],
      ),
    );
  }

  Widget _chatBubble(String sender, String message, String time, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 4),
        padding: EdgeInsets.all(12),
        constraints: BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: isMe ? Colors.indigo[100] : Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe) Text(sender, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.indigo)),
            SizedBox(height: 4),
            Text(message),
            SizedBox(height: 4),
            Text(time, style: TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  void _showAchievementsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.emoji_events, color: Colors.amber[700]),
            SizedBox(width: 8),
            Text('Achievements'),
          ],
        ),
        content: SizedBox(
          width: 400,
          height: 400,
          child: Column(
            children: [
              // Points Summary
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.amber[600]!, Colors.amber[400]!]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.stars, color: Colors.white, size: 32),
                    SizedBox(width: 12),
                    Text('150 Points', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              SizedBox(height: 16),
              Text('Your Badges', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              SizedBox(height: 12),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  children: [
                    _badgeItem(Icons.favorite, 'First Donation', Colors.red, true),
                    _badgeItem(Icons.star, '5 Donations', Colors.amber, false),
                    _badgeItem(Icons.verified, 'Verified', Colors.blue, true),
                    _badgeItem(Icons.emergency, 'Emergency Hero', Colors.orange, false),
                    _badgeItem(Icons.groups, 'Community', Colors.green, false),
                    _badgeItem(Icons.health_and_safety, 'Life Saver', Colors.purple, false),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Close')),
        ],
      ),
    );
  }

  Widget _badgeItem(IconData icon, String label, Color color, bool earned) {
    return Container(
      decoration: BoxDecoration(
        color: earned ? color.withOpacity(0.1) : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: earned ? color : Colors.grey[300]!),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: earned ? color : Colors.grey[400], size: 28),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 9, color: earned ? color : Colors.grey[400], fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          if (!earned)
            Icon(Icons.lock, size: 12, color: Colors.grey[400]),
        ],
      ),
    );
  }

  void _showVerificationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.verified_user, color: Colors.blue),
            SizedBox(width: 8),
            Text('Verification Status'),
          ],
        ),
        content: SizedBox(
          width: 400,
          height: 350,
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green),
                ),
                child: Row(
                  children: [
                    Icon(Icons.verified, color: Colors.green, size: 48),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Verified Donor', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green)),
                          Text('Your account is verified', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
              _verificationRow('ID Verification', true),
              _verificationRow('Medical Certificate', true),
              _verificationRow('Blood Test Report', false),
              SizedBox(height: 16),
              Text('Your Reputation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ...List.generate(5, (i) => Icon(Icons.star, color: i < 4 ? Colors.amber : Colors.grey[300], size: 32)),
                  SizedBox(width: 8),
                  Text('4.5', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                ],
              ),
              SizedBox(height: 8),
              Text('Based on 12 reviews', style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
        actions: [
          ElevatedButton.icon(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload feature coming soon'))),
            icon: Icon(Icons.upload_file),
            label: Text('Upload Document'),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Close')),
        ],
      ),
    );
  }

  Widget _verificationRow(String label, bool verified) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            verified ? Icons.check_circle : Icons.pending,
            color: verified ? Colors.green : Colors.orange,
          ),
          SizedBox(width: 12),
          Text(label),
          Spacer(),
          Text(
            verified ? 'Verified' : 'Pending',
            style: TextStyle(color: verified ? Colors.green : Colors.orange, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  void _showBloodBanksDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.local_hospital, color: Colors.red[700]),
            SizedBox(width: 8),
            Text('Nearby Blood Banks'),
          ],
        ),
        content: SizedBox(
          width: 400,
          height: 400,
          child: ListView(
            children: [
              _bloodBankTile('City General Hospital', '2.3 km away', 'Open 24/7', true),
              _bloodBankTile('Red Crescent Blood Bank', '3.5 km away', 'Open 8AM - 10PM', true),
              _bloodBankTile('Medical Center', '5.1 km away', 'Open 9AM - 6PM', false),
              _bloodBankTile('Community Blood Bank', '7.8 km away', 'Open 24/7', true),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Close')),
        ],
      ),
    );
  }

  Widget _bloodBankTile(String name, String distance, String hours, bool hasStock) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.red[50],
          child: Icon(Icons.local_hospital, color: Colors.red),
        ),
        title: Text(name, style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(distance),
            Text(hours, style: TextStyle(fontSize: 11)),
          ],
        ),
        trailing: Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: hasStock ? Colors.green[50] : Colors.red[50],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            hasStock ? 'Available' : 'Low Stock',
            style: TextStyle(color: hasStock ? Colors.green : Colors.red, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
        onTap: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Opening $name...'))),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color startColor, Color endColor, {VoidCallback? onTap, bool isWhiteCard = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.all(10),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: startColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: startColor, size: 18),
            ),
            SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 2),
            Flexible(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionCard(
    String title,
    String subtitle,
    IconData icon,
    Color color, {
    VoidCallback? onTap,
  }) {
    // Define different colors based on the icon
    Color iconColor;
    
    if (icon == Icons.account_circle) {
      iconColor = Color(0xFF9575CD);
    } else if (icon == Icons.bloodtype) {
      iconColor = Color(0xFFFF6B9D);
    } else if (icon == Icons.person_search) {
      iconColor = Color(0xFF66BB6A);
    } else {
      iconColor = Color(0xFF1976D2);
    }
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.all(18),
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
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon, 
                color: iconColor, 
                size: 28
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios, 
              size: 18, 
              color: Colors.black38
            ),
          ],
        ),
      ),
    );
  }
}
