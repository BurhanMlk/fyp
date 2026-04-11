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
import 'package:image_picker/image_picker.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _userName = '';
  String _userRole = '';
  String _userEmail = '';
  int _totalDonors = 0;
  int _totalRecipients = 0;
  int _pendingRequests = 0;
  bool _isLoading = true;
  final ImagePicker _picker = ImagePicker();
  bool _hasUploadedDocument = false;
  String _verificationStatus = 'not_uploaded';
  bool _firstDonationApprovedByAdmin = false;

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
        _userEmail = user.email ?? '';
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          final data = userDoc.data() ?? <String, dynamic>{};
          _userName = data['name'] ?? 'User';
          _userRole = data['role'] ?? 'user';
          _hasUploadedDocument = (data['verificationDocumentData'] ?? '').toString().isNotEmpty;
          final status = (data['verificationStatus'] ?? '').toString();
          _verificationStatus = status.isEmpty
              ? (_hasUploadedDocument ? 'pending' : 'not_uploaded')
              : status;
          _firstDonationApprovedByAdmin = data['firstDonationApproved'] == true;
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
      _userEmail = currentEmail ?? '';
      final users = prefs.getStringList('demo_users') ?? <String>[];

      _totalDonors = 0;
      _totalRecipients = 0;
      _pendingRequests = 0;
      
      for (final userStr in users) {
        try {
          final user = jsonDecode(userStr) as Map<String, dynamic>;
          if (user['email'] == currentEmail) {
            _userName = user['name'] ?? 'User';
            _userRole = user['role'] ?? 'user';
            _hasUploadedDocument = (user['verificationDocumentData'] ?? '').toString().isNotEmpty;
            final status = (user['verificationStatus'] ?? '').toString();
            _verificationStatus = status.isEmpty
                ? (_hasUploadedDocument ? 'pending' : 'not_uploaded')
                : status;
            _firstDonationApprovedByAdmin = user['firstDonationApproved'] == true;
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

  String _welcomeDisplayName() {
    final name = _userName.trim();
    if (name.isNotEmpty) return name;

    final email = _userEmail.trim();
    if (email.isNotEmpty && email.contains('@')) {
      return email.split('@').first;
    }
    return 'User';
  }

  String _welcomeRoleLabel() {
    final role = _userRole.trim().toLowerCase();
    if (role == 'user') return 'RECIPIENT';
    if (role == 'donor' || role == 'recipient' || role == 'super_admin') {
      return role.toUpperCase();
    }
    return 'RECIPIENT';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    final displayName = _welcomeDisplayName();
    final roleLabel = _welcomeRoleLabel();
    final normalizedRole = _userRole.trim().toLowerCase();
    final isPrimaryRole =
      normalizedRole == 'donor' || normalizedRole == 'recipient' || normalizedRole == 'user';

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
                    colors: [Color(0xFFD84343), Color(0xFFEF5350)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFFD84343).withOpacity(0.2),
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
                      displayName.toUpperCase(),
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
                          colors: isPrimaryRole
                              ? [Color(0xFFDDE5B6), Color(0xFFC8D59C)]
                              : [Color(0xFFBDBDBD), Color(0xFF9E9E9E)],
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
                        roleLabel,
                        style: TextStyle(
                          color: isPrimaryRole ? Colors.black87 : Colors.white,
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
              if (_userRole == 'recipient')
                _buildQuickActionCard(
                  'Verification Status',
                  'Check your verification and reputation',
                  Icons.verified_user,
                  Colors.blue.shade600,
                  onTap: () => _showVerificationDialog(),
                ),
              if (_userRole == 'recipient') SizedBox(height: 12),
              
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
        backgroundColor: Colors.white,
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
              color: Colors.white,
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
              color: Colors.white,
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
    if (_userRole != 'donor') return [];

    if (FirebaseService.initialized) {
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('donor_requests')
            .get();

        final donations = <Map<String, dynamic>>[];
        for (final doc in snapshot.docs) {
          final data = doc.data();
          if (!_isApprovedDonation(data) || !_belongsToCurrentDonor(data)) continue;

          final donatedAt = _donationRequestTime(data);
          final sharedData = data['sharedData'] is Map
              ? Map<String, dynamic>.from(data['sharedData'] as Map)
              : <String, dynamic>{};

          donations.add({
            'id': doc.id,
            'location': _donationRequestLocation(data),
            'date': _formatDateOnly(donatedAt),
            'bloodGroup': (data['bloodGroup'] ?? sharedData['bloodGroup'] ?? 'N/A').toString(),
            'timestamp': donatedAt,
          });
        }

        donations.sort((a, b) => (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime));
        return donations;
      } catch (e) {
        print('Error loading donation history: $e');
        return [];
      }
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final requests = prefs.getStringList('donor_requests') ?? <String>[];
      final donations = <Map<String, dynamic>>[];

      for (final reqStr in requests) {
        try {
          final data = jsonDecode(reqStr) as Map<String, dynamic>;
          if (!_isApprovedDonation(data) || !_belongsToCurrentDonor(data)) continue;

          final donatedAt = _donationRequestTime(data);
          final sharedData = data['sharedData'] is Map
              ? Map<String, dynamic>.from(data['sharedData'] as Map)
              : <String, dynamic>{};

          donations.add({
            'id': (data['id'] ?? '').toString(),
            'location': _donationRequestLocation(data),
            'date': _formatDateOnly(donatedAt),
            'bloodGroup': (data['bloodGroup'] ?? sharedData['bloodGroup'] ?? 'N/A').toString(),
            'timestamp': donatedAt,
          });
        } catch (_) {}
      }

      donations.sort((a, b) => (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime));
      return donations;
    } catch (e) {
      print('Error loading demo donation history: $e');
      return [];
    }
  }

  bool _isApprovedDonation(Map<String, dynamic> request) {
    final status = (request['status'] ?? '').toString().trim().toLowerCase();
    return status == 'approved' || status == 'completed' || status == 'handled';
  }

  bool _belongsToCurrentDonor(Map<String, dynamic> request) {
    final normalizedEmail = _userEmail.trim().toLowerCase();
    final normalizedName = _userName.trim().toLowerCase();
    final sharedData = request['sharedData'] is Map
        ? Map<String, dynamic>.from(request['sharedData'] as Map)
        : <String, dynamic>{};

    final emails = <String>{
      (request['donorEmail'] ?? '').toString().trim().toLowerCase(),
      (request['email'] ?? '').toString().trim().toLowerCase(),
      (request['userEmail'] ?? '').toString().trim().toLowerCase(),
      (request['from'] ?? '').toString().trim().toLowerCase(),
      (request['requestedBy'] ?? '').toString().trim().toLowerCase(),
      (sharedData['donorEmail'] ?? '').toString().trim().toLowerCase(),
      (sharedData['email'] ?? '').toString().trim().toLowerCase(),
      (sharedData['userEmail'] ?? '').toString().trim().toLowerCase(),
    }..removeWhere((value) => value.isEmpty);

    if (normalizedEmail.isNotEmpty && emails.contains(normalizedEmail)) {
      return true;
    }

    final names = <String>{
      (request['donorName'] ?? '').toString().trim().toLowerCase(),
      (request['name'] ?? '').toString().trim().toLowerCase(),
      (sharedData['donorName'] ?? '').toString().trim().toLowerCase(),
      (sharedData['name'] ?? '').toString().trim().toLowerCase(),
    }..removeWhere((value) => value.isEmpty);

    return normalizedName.isNotEmpty && names.contains(normalizedName);
  }

  DateTime _donationRequestTime(Map<String, dynamic> request) {
    final sharedData = request['sharedData'] is Map
        ? Map<String, dynamic>.from(request['sharedData'] as Map)
        : <String, dynamic>{};

    final dynamic rawTime = request['handledAt'] ??
        request['requestedAt'] ??
        request['createdAt'] ??
        sharedData['handledAt'] ??
        sharedData['requestedAt'] ??
        sharedData['createdAt'];

    if (rawTime is Timestamp) return rawTime.toDate();
    if (rawTime is DateTime) return rawTime;
    if (rawTime is String) return DateTime.tryParse(rawTime) ?? DateTime.now();
    return DateTime.now();
  }

  String _donationRequestLocation(Map<String, dynamic> request) {
    final sharedData = request['sharedData'] is Map
        ? Map<String, dynamic>.from(request['sharedData'] as Map)
        : <String, dynamic>{};

    final candidates = [
      request['hospital'],
      request['hospitalName'],
      request['location'],
      sharedData['hospital'],
      sharedData['hospitalName'],
      sharedData['location'],
    ];

    for (final candidate in candidates) {
      final value = (candidate ?? '').toString().trim();
      if (value.isNotEmpty) return value;
    }
    return 'Blood Donation';
  }

  String _formatDateOnly(DateTime dateTime) {
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    return '${dateTime.year}-$month-$day';
  }

  Future<List<Map<String, dynamic>>> _loadReceivedHistory() async {
    return [
      {'donor': 'Ahmad Khan', 'date': '2026-02-10', 'bloodGroup': 'A+'},
    ];
  }

  String _getConversationId(String userEmail) {
    // Generate consistent conversation ID for user-admin chat
    return 'conv_${userEmail.replaceAll('.', '_').replaceAll('@', '_at_')}_admin';
  }

  void _showMessagesDialog() {
    final messageCtl = TextEditingController();
    final conversationId = _getConversationId(_userEmail);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final screenSize = MediaQuery.of(context).size;
          final dialogWidth = screenSize.width < 460 ? screenSize.width * 0.88 : 400.0;
          final dialogHeight = screenSize.height < 760 ? screenSize.height * 0.6 : 450.0;

          return AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.black, width: 1.5),
          ),
          icon: Icon(Icons.chat, color: Colors.indigo),
          title: Text(
            'Messages with Admin',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: screenSize.width < 360 ? 18 : 20,
            ),
          ),
          content: SizedBox(
            width: dialogWidth,
            height: dialogHeight,
            child: Column(
              children: [
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseService.initialized
                        ? FirebaseFirestore.instance
                            .collection('messages')
                            .where('conversationId', isEqualTo: conversationId)
                            .orderBy('sentAt', descending: true)
                            .limit(100)
                            .snapshots()
                        : null,
                    builder: (context, snapshot) {
                      List<Map<String, dynamic>> allMessages = [];

                      if (FirebaseService.initialized) {
                        if (snapshot.hasData) {
                          for (var doc in snapshot.data!.docs) {
                            final data = doc.data() as Map<String, dynamic>;
                            final from = data['from'] ?? '';
                            final isMe = from == _userEmail;

                            allMessages.add({
                              'id': doc.id,
                              'sender': isMe ? 'You' : 'Admin',
                              'message': data['message'] ?? '',
                              'time': data['sentAt'],
                              'isMe': isMe,
                              'read': data['read'] ?? false,
                            });

                            if (!isMe && data['read'] == false) {
                              FirebaseFirestore.instance
                                  .collection('messages')
                                  .doc(doc.id)
                                  .update({'read': true}).catchError((e) => print('Error marking read: $e'));
                            }
                          }
                        }
                      } else {
                        allMessages = [
                          {'sender': 'Admin', 'message': 'Welcome to Blood Bridge! How can we help?', 'time': null, 'isMe': false},
                        ];
                      }

                      if (allMessages.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[300]),
                              SizedBox(height: 16),
                              Text('No messages yet', style: TextStyle(color: Colors.grey[600])),
                              SizedBox(height: 8),
                              Text('Send a message to admin', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        reverse: true,
                        itemCount: allMessages.length,
                        itemBuilder: (context, index) {
                          final msg = allMessages[index];
                          String timeStr = 'Just now';
                          if (msg['time'] != null) {
                            final time = (msg['time'] as Timestamp).toDate();
                            final now = DateTime.now();
                            final diff = now.difference(time);

                            if (diff.inMinutes < 60) {
                              timeStr = '${diff.inMinutes}m ago';
                            } else if (diff.inHours < 24) {
                              timeStr = '${diff.inHours}h ago';
                            } else {
                              timeStr = '${diff.inDays}d ago';
                            }
                          }

                          return _chatBubble(
                            msg['sender'] ?? '',
                            msg['message'] ?? '',
                            timeStr,
                            msg['isMe'] ?? false,
                            msg['read'] ?? false,
                          );
                        },
                      );
                    },
                  ),
                ),
                Divider(),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: messageCtl,
                        decoration: InputDecoration(
                          hintText: 'Type a message to admin...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(color: Color(0xFFB7C8A4), width: 1.5),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(color: Color(0xFFB7C8A4), width: 1.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(color: Color(0xFF9FB38A), width: 2),
                          ),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.black,
                        side: BorderSide(color: Colors.black, width: 2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      ),
                      child: Icon(Icons.send, color: Colors.white),
                      onPressed: () async {
                        final message = messageCtl.text.trim();
                        if (message.isNotEmpty) {
                          if (FirebaseService.initialized) {
                            try {
                              final now = Timestamp.now();

                              await FirebaseFirestore.instance.collection('messages').add({
                                'conversationId': conversationId,
                                'from': _userEmail,
                                'to': 'Admin',
                                'message': message,
                                'sentAt': now,
                                'type': 'user_to_admin',
                                'read': false,
                                'userRole': _userRole,
                              });

                              await FirebaseFirestore.instance
                                  .collection('chats')
                                  .doc(conversationId)
                                  .set({
                                'conversationId': conversationId,
                                'participants': [_userEmail, 'Admin'],
                                'participantNames': [_userName, 'Admin'],
                                'lastMessage': message,
                                'lastMessageAt': now,
                                'lastMessageFrom': _userEmail,
                                'status': 'active',
                                'unreadCount': FieldValue.increment(1),
                                'updatedAt': now,
                              }, SetOptions(merge: true));

                              messageCtl.clear();
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error sending message: $e'), backgroundColor: Colors.red),
                              );
                            }
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Message sent! (Demo mode)'), backgroundColor: Colors.green),
                            );
                            messageCtl.clear();
                          }
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.black,
                side: BorderSide(color: Colors.black, width: 2),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('Close', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
        },
      ),
    );
  }

  Widget _chatBubble(String sender, String message, String time, bool isMe, bool isRead) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bubbleMaxWidth = screenWidth < 420 ? screenWidth * 0.5 : 280.0;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 4),
        padding: EdgeInsets.all(12),
        constraints: BoxConstraints(maxWidth: bubbleMaxWidth),
        decoration: BoxDecoration(
          color: isMe ? Colors.indigo[100] : Colors.grey[100],
          border: Border.all(color: Color(0xFFB7C8A4), width: 1.4),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe) Text(sender, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.indigo)),
            SizedBox(height: 4),
            Text(message),
            SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(time, style: TextStyle(fontSize: 10, color: Colors.grey)),
                if (isMe) ...[
                  SizedBox(width: 4),
                  _buildTickIndicator(isRead),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTickIndicator(bool isRead) {
    return Icon(
      Icons.done_all,
      size: 14,
      color: isRead ? Colors.blue : Colors.grey,
    );
  }

  void _showAchievementsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.black, width: 1.8),
        ),
        title: Row(
          children: [
            Icon(Icons.emoji_events, color: Colors.amber[700]),
            SizedBox(width: 8),
            Text('Achievements'),
          ],
        ),
        content: SizedBox(
          width: 420,
          height: 440,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _loadDonationHistory(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }

              final donations = snapshot.data ?? [];
              final donationCount = donations.length;
                final firstDonationEarned = donationCount >= 1 || _firstDonationApprovedByAdmin;
              final fiveDonationsEarned = donationCount >= 5;
              final verifiedEarned = _verificationStatus == 'approved';
                final displayDonationCount = donationCount > 0
                  ? donationCount
                  : (firstDonationEarned ? 1 : 0);
                final points = (displayDonationCount * 100) + (verifiedEarned ? 50 : 0);

              return Column(
                children: [
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black, width: 1.6),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.stars, color: Colors.amber[700], size: 30),
                        SizedBox(width: 10),
                        Text(
                          '$points Points',
                          style: TextStyle(color: Colors.black, fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Your Badges', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      OutlinedButton.icon(
                        onPressed: () {
                          if (!firstDonationEarned) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Complete your first donation to unlock certificate.'),
                                backgroundColor: Colors.black87,
                              ),
                            );
                            return;
                          }
                          _showCertificateDialog(donationCount: displayDonationCount);
                        },
                        icon: Icon(Icons.workspace_premium, size: 18),
                        label: Text('Certificate'),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          side: BorderSide(color: Colors.black, width: 1.6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      children: [
                        _badgeItem(
                          Icons.favorite,
                          'First Donation',
                          Colors.red,
                          firstDonationEarned,
                          onTap: firstDonationEarned
                              ? () => _showCertificateDialog(donationCount: displayDonationCount)
                              : null,
                        ),
                        _badgeItem(Icons.star, '5 Donations', Colors.amber, fiveDonationsEarned),
                        _badgeItem(Icons.verified, 'Verified', Colors.blue, verifiedEarned),
                        _badgeItem(Icons.emergency, 'Emergency Hero', Colors.orange, false),
                        _badgeItem(Icons.groups, 'Community', Colors.green, false),
                        _badgeItem(Icons.health_and_safety, 'Life Saver', Colors.purple, false),
                      ],
                    ),
                  ),
                  if (firstDonationEarned)
                    Text(
                      'Tap First Donation badge to open your certificate',
                      style: TextStyle(fontSize: 11, color: Colors.black54),
                    ),
                ],
              );
            },
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              side: BorderSide(color: Colors.black, width: 2),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Close', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  Widget _badgeItem(IconData icon, String label, Color color, bool earned, {VoidCallback? onTap}) {
    final badge = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: earned ? color : Colors.black.withOpacity(0.16),
          width: earned ? 1.4 : 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: earned ? color : Colors.grey[400], size: 28),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 9, color: earned ? color : Colors.grey[500], fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          if (!earned)
            Icon(Icons.lock, size: 12, color: Colors.grey[400]),
        ],
      ),
    );

    if (onTap == null) return badge;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: badge,
      ),
    );
  }

  Color _certificateAccentColor() {
    const palette = [
      Color(0xFF1565C0),
      Color(0xFF2E7D32),
      Color(0xFF6A1B9A),
      Color(0xFFEF6C00),
      Color(0xFF00838F),
    ];

    final seed = _userName.trim().toLowerCase();
    if (seed.isEmpty) return palette.first;
    return palette[seed.hashCode.abs() % palette.length];
  }

  String _certificateInitials() {
    final parts = _userName
        .trim()
        .split(RegExp(r'\\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'D';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  void _showCertificateDialog({required int donationCount}) {
    final accentColor = _certificateAccentColor();
    final donorName = _userName.trim().isEmpty ? 'Valued Donor' : _userName.trim();
    final issuedOn = _formatDateOnly(DateTime.now());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.black, width: 1.8),
        ),
        title: Row(
          children: [
            Icon(Icons.workspace_premium, color: accentColor),
            SizedBox(width: 8),
            Text('Donation Certificate'),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.black, width: 1.5),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Certificate of Appreciation',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Container(
                            padding: EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: accentColor.withOpacity(0.14),
                              shape: BoxShape.circle,
                              border: Border.all(color: accentColor, width: 1.5),
                            ),
                            child: Text(
                              _certificateInitials(),
                              style: TextStyle(color: accentColor, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Text('This certifies that', style: TextStyle(color: Colors.black54)),
                      SizedBox(height: 8),
                      Text(
                        donorName.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: accentColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                          letterSpacing: 0.6,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'has successfully completed $donationCount blood donation${donationCount == 1 ? '' : 's'} with Blood Bridge.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black87),
                      ),
                      SizedBox(height: 10),
                      Text('Issued on: $issuedOn', style: TextStyle(color: Colors.black54)),
                    ],
                  ),
                ),
                SizedBox(height: 14),
                Text('Download Options', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _certificateActionButton('Download PDF', Icons.picture_as_pdf),
                    _certificateActionButton('Download PNG', Icons.image),
                    _certificateActionButton('Download JPG', Icons.photo),
                    _certificateActionButton('Download DOC', Icons.description),
                    _certificateActionButton('Download TXT', Icons.text_snippet),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              side: BorderSide(color: Colors.black, width: 2),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Close', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  Widget _certificateActionButton(String label, IconData icon) {
    return OutlinedButton.icon(
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$label started'),
            backgroundColor: Colors.black87,
          ),
        );
      },
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        side: BorderSide(color: Colors.black, width: 1.6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showVerificationDialog() {
    final String roleLabel = _userRole == 'recipient' ? 'Recipient' : 'Donor';
    final bool isVerified = _verificationStatus == 'approved';
    final bool isPending = _verificationStatus == 'pending';
    final bool isRejected = _verificationStatus == 'rejected';
    final Color statusColor = isVerified
      ? Colors.green
      : isRejected
        ? Colors.red
        : Colors.orange;
    final IconData statusIcon = isVerified
      ? Icons.verified
      : isRejected
        ? Icons.cancel
        : Icons.pending_actions;
    final String statusTitle = isVerified
      ? 'Verified $roleLabel'
      : isRejected
        ? 'Verification Rejected'
        : _hasUploadedDocument
          ? 'Verification Pending'
          : 'Not Verified Yet';
    final String statusSubtitle = isVerified
      ? 'Your account is verified'
      : isRejected
        ? 'Please re-upload your document'
        : _hasUploadedDocument
          ? 'Your document is pending verification'
          : 'No verification document uploaded';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Icon(Icons.verified_user, color: Colors.blue),
            SizedBox(width: 8),
            Text('Verification Status'),
          ],
        ),
        content: SizedBox(
          width: 400,
          height: 270,
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor),
                ),
                child: Row(
                  children: [
                    Icon(statusIcon, color: statusColor, size: 48),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(statusTitle, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: statusColor)),
                          Text(statusSubtitle, style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
              _verificationRow('ID Verification', isVerified),
              _verificationRow('Medical Certificate', isVerified),
              _verificationRow(
                'Blood Test Report',
                isVerified,
                isPendingUpload: _hasUploadedDocument && isPending,
              ),
            ],
          ),
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
          SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: _uploadDocument,
            icon: Icon(isVerified ? Icons.check_circle : Icons.upload_file),
            label: Text(_hasUploadedDocument ? 'Re-upload Document' : 'Upload Document'),
            style: OutlinedButton.styleFrom(
              backgroundColor: isVerified
                  ? Colors.green[50]
                  : (_hasUploadedDocument ? Colors.orange[50] : Colors.transparent),
              foregroundColor: isVerified
                  ? Colors.green[700]
                  : (_hasUploadedDocument ? Colors.orange[800] : Colors.black),
              side: BorderSide(
                color: isVerified
                    ? Colors.green
                    : (_hasUploadedDocument ? Colors.orange : Colors.black),
                width: 2,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadDocument() async {
    bool loadingShown = false;
    try {
      // Show dialog to choose between camera and gallery
      final ImageSource? source = await showDialog<ImageSource>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.white.withOpacity(0.92),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.black, width: 2),
          ),
          title: Text('Choose Document Source'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.black, width: 1.5),
                ),
                child: ListTile(
                  leading: Icon(Icons.camera_alt, color: Color(0xFFD32F2F)),
                  title: Text('Camera'),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.black, width: 1.5),
                ),
                child: ListTile(
                  leading: Icon(Icons.photo_library, color: Color(0xFFD32F2F)),
                  title: Text('Gallery'),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
              ),
            ],
          ),
        ),
      );
      
      if (source == null) return;
      
      final xfile = await _picker.pickImage(
        source: source,
        maxWidth: 900,
        maxHeight: 900,
        imageQuality: 60,
      );
      
      if (xfile == null) return;
      
      // Show loading
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Uploading document...'),
                  ],
                ),
              ),
            ),
          ),
        );
        loadingShown = true;
      }

      final bytes = await xfile.readAsBytes();
      final encodedDocument = base64Encode(bytes);

      if (FirebaseService.initialized) {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          throw Exception('You must be logged in to upload documents.');
        }
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'verificationDocumentData': encodedDocument,
          'verificationDocumentUploadedAt': FieldValue.serverTimestamp(),
          'verificationStatus': 'pending',
          'verified': false,
        }, SetOptions(merge: true));
      } else {
        final prefs = await SharedPreferences.getInstance();
        final currentEmail = prefs.getString('demo_current_email') ?? _userEmail;
        final users = prefs.getStringList('demo_users') ?? <String>[];
        final updated = <String>[];
        for (final u in users) {
          try {
            final Map<String, dynamic> user = jsonDecode(u);
            if ((user['email'] ?? '').toString() == currentEmail) {
              user['verificationDocumentData'] = encodedDocument;
              user['verificationDocumentUploadedAt'] = DateTime.now().toIso8601String();
              user['verificationStatus'] = 'pending';
              user['verified'] = false;
              updated.add(jsonEncode(user));
            } else {
              updated.add(u);
            }
          } catch (_) {
            updated.add(u);
          }
        }
        await prefs.setStringList('demo_users', updated);
      }
      
      setState(() {
        _hasUploadedDocument = true;
        _verificationStatus = 'pending';
      });
      
      // Close loading dialog
      if (mounted && loadingShown) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Document uploaded successfully!'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if open
      if (mounted && loadingShown) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _verificationRow(String label, bool verified, {bool isPendingUpload = false}) {
    final bool isPending = !verified && isPendingUpload;
    final Color statusColor = verified
        ? Colors.green
        : (isPending ? Colors.orange : Colors.orange);
    final String statusText = verified ? 'Verified' : (isPending ? 'Pending' : 'Pending');

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            verified ? Icons.check_circle : Icons.pending,
            color: statusColor,
          ),
          SizedBox(width: 12),
          Text(label),
          Spacer(),
          Text(
            statusText,
            style: TextStyle(color: statusColor, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  void _showBloodBanksDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
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
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.black,
              side: BorderSide(color: Colors.black, width: 2),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Close', style: TextStyle(color: Colors.white)),
          ),
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
            color: hasStock ? Colors.green[600] : Colors.red[600],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            hasStock ? 'Available' : 'Low Stock',
            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
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
      iconColor = Color(0xFFC62828);
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
          border: Border.all(color: Colors.black, width: 1.8),
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
