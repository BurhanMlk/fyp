import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/firebase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../widgets/blood_bridge_loader.dart';
import 'user_profile_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import '../auth/login_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _totalUsers = 0;
  int _donors = 0;
  int _recipients = 0;
  // Selection for inbox details
  Map<String, dynamic>? _selectedItem;
  String? _selectedType; // 'donor_request' | 'emergency' | 'forgot' | 'registration'
  String? _selectedId; // firebase doc id or demo index as string
  
  // Current selected module from drawer
  String _currentModule = 'overview'; // 'overview' | 'donor_requests' | 'recipients' | 'emergency' | 'admin_profile'
  
  // Blood Banks Data
  List<Map<String, dynamic>> _bloodBanks = [];

  @override
  void initState() {
    super.initState();
    // Ensure only super admin can view. If not super admin, navigate back.
    _isSuperAdmin().then((ok) {
      if (!ok) {
        // show brief message and pop
        Future.microtask(() {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Access denied: super admin only')));
          Navigator.of(context).pop();
        });
      } else {
        _loadStats();
        _loadBloodBanks();
      }
    });
  }

  // Guard: if not super_admin, redirect back (demo & Firebase)
  Future<bool> _isSuperAdmin() async {
    if (FirebaseService.initialized) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return false;
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        final role = doc.data()?['role'] ?? '';
        return role == 'super_admin';
      } catch (_) {
        return false;
      }
    } else {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('demo_current_email');
      if (email == null) return false;
      final list = prefs.getStringList('demo_users') ?? <String>[];
      for (final s in list) {
        try {
          final Map<String, dynamic> u = jsonDecode(s);
          if ((u['email'] ?? '') == email) return (u['role'] ?? '') == 'super_admin';
        } catch (_) {}
      }
      return false;
    }
  }

  Future<void> _loadStats() async {
    if (FirebaseService.initialized) {
      try {
        final snap = await FirebaseFirestore.instance.collection('users').get();
        final docs = snap.docs;
        int donors = 0, recipients = 0;
        for (final d in docs) {
          final r = d.data()['role'] ?? '';
          if (r == 'donor') {
            donors++;
          } else if (r == 'recipient') recipients++;
        }
        setState(() {
          _totalUsers = docs.length;
          _donors = donors;
          _recipients = recipients;
        });
      } catch (e) {
        setState(() {
          _totalUsers = 0;
        });
      }
    } else {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('demo_users') ?? <String>[];
      try {
        int donors = 0, recipients = 0;
        for (final s in list) {
          final Map<String, dynamic> u = jsonDecode(s);
          if ((u['role'] ?? '') == 'donor') {
            donors++;
          } else if ((u['role'] ?? '') == 'recipient') recipients++;
        }
        setState(() {
          _totalUsers = list.length;
          _donors = donors;
          _recipients = recipients;
        });
      } catch (e) {
        setState(() {
          _totalUsers = 0;
          _donors = 0;
          _recipients = 0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getModuleTitle(), style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFD32F2F), Color(0xFFE57373), Color(0xFFEF5350)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      drawer: _buildDrawer(),
      backgroundColor: Color(0xFFF5F5F5),
      body: SafeArea(
        child: _buildCurrentModule(),
      ),
    );
  }

  String _getModuleTitle() {
    switch (_currentModule) {
      case 'donor_requests':
        return 'Donor Requests';
      case 'recipients':
        return 'Recipients';
      case 'emergency':
        return 'Emergency Requests';
      case 'admin_profile':
        return 'Admin Profile';
      case 'user_profile':
        return 'User Registration & Profile';
      case 'donation_history':
        return 'Donation History & Reminders';
      case 'communication':
        return 'In-App Communication';
      case 'gamification':
        return 'Gamification & Engagement';
      case 'verification':
        return 'Donor Verification & Reputation';
      case 'hospital_bank':
        return 'Blood Bank Management';
      case 'analytics':
        return 'Analytics & Reports';
      case 'ai_matching':
        return 'AI Matching & Prediction';
      default:
        return 'Admin Dashboard';
    }
  }

  Drawer _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(16, 48, 16, 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFD32F2F), Color(0xFFE57373)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: EdgeInsets.all(8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/images/blood_bridge.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stack) => Icon(Icons.admin_panel_settings, size: 40, color: Color(0xFFD32F2F)),
                    ),
                  ),
                ),
                SizedBox(height: 12),
                Text('Admin Panel', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                Text('Blood Bridge Management', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            leading: Icon(Icons.dashboard, size: 20, color: _currentModule == 'overview' ? Color(0xFFD32F2F) : Colors.grey),
            title: Text('Overview', style: TextStyle(fontSize: 14, fontWeight: _currentModule == 'overview' ? FontWeight.bold : FontWeight.normal)),
            selected: _currentModule == 'overview',
            onTap: () {
              setState(() => _currentModule = 'overview');
              Navigator.pop(context);
            },
          ),
          Divider(height: 1),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text('ADMIN INBOX', style: TextStyle(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.bold)),
          ),
          // M1: User Registration & Profile Management
          ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            leading: Icon(Icons.person_add, size: 20, color: _currentModule == 'user_profile' ? Color(0xFFD32F2F) : Colors.grey),
            title: Text('User Registration & Profile', style: TextStyle(fontSize: 14, fontWeight: _currentModule == 'user_profile' ? FontWeight.bold : FontWeight.normal)),
            selected: _currentModule == 'user_profile',
            onTap: () {
              setState(() => _currentModule = 'user_profile');
              Navigator.pop(context);
            },
          ),
          // M2: Emergency Alert & Request Module
          ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            leading: Icon(Icons.emergency, size: 20, color: _currentModule == 'emergency' ? Color(0xFFD32F2F) : Colors.grey),
            title: Text('Emergency Requests', style: TextStyle(fontSize: 14, fontWeight: _currentModule == 'emergency' ? FontWeight.bold : FontWeight.normal)),
            selected: _currentModule == 'emergency',
            onTap: () {
              setState(() => _currentModule = 'emergency');
              Navigator.pop(context);
            },
          ),
          // M3: Donation History & Reminders
          ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            leading: Icon(Icons.history, size: 20, color: _currentModule == 'donation_history' ? Color(0xFFD32F2F) : Colors.grey),
            title: Text('Donation History & Reminders', style: TextStyle(fontSize: 14, fontWeight: _currentModule == 'donation_history' ? FontWeight.bold : FontWeight.normal)),
            selected: _currentModule == 'donation_history',
            onTap: () {
              setState(() => _currentModule = 'donation_history');
              Navigator.pop(context);
            },
          ),
          // M4: In-App Communication Module
          ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            leading: Icon(Icons.chat, size: 20, color: _currentModule == 'communication' ? Color(0xFFD32F2F) : Colors.grey),
            title: Text('In-App Communication', style: TextStyle(fontSize: 14, fontWeight: _currentModule == 'communication' ? FontWeight.bold : FontWeight.normal)),
            selected: _currentModule == 'communication',
            onTap: () {
              setState(() => _currentModule = 'communication');
              Navigator.pop(context);
            },
          ),
          // M5: Gamification & Engagement Module
          ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            leading: Icon(Icons.emoji_events, size: 20, color: _currentModule == 'gamification' ? Color(0xFFD32F2F) : Colors.grey),
            title: Text('Gamification & Engagement', style: TextStyle(fontSize: 14, fontWeight: _currentModule == 'gamification' ? FontWeight.bold : FontWeight.normal)),
            selected: _currentModule == 'gamification',
            onTap: () {
              setState(() => _currentModule = 'gamification');
              Navigator.pop(context);
            },
          ),
          // M6: Donor Verification & Reputation System
          ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            leading: Icon(Icons.verified_user, size: 20, color: _currentModule == 'verification' ? Color(0xFFD32F2F) : Colors.grey),
            title: Text('Donor Verification & Reputation', style: TextStyle(fontSize: 14, fontWeight: _currentModule == 'verification' ? FontWeight.bold : FontWeight.normal)),
            selected: _currentModule == 'verification',
            onTap: () {
              setState(() => _currentModule = 'verification');
              Navigator.pop(context);
            },
          ),
          // M7: Hospital / Blood Bank Management
          ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            leading: Icon(Icons.local_hospital, size: 20, color: _currentModule == 'hospital_bank' ? Color(0xFFD32F2F) : Colors.grey),
            title: Text('Blood Bank Management', style: TextStyle(fontSize: 14, fontWeight: _currentModule == 'hospital_bank' ? FontWeight.bold : FontWeight.normal)),
            selected: _currentModule == 'hospital_bank',
            onTap: () {
              setState(() => _currentModule = 'hospital_bank');
              Navigator.pop(context);
            },
          ),
          // M8: Analytics & Reports Dashboard
          ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            leading: Icon(Icons.analytics, size: 20, color: _currentModule == 'analytics' ? Color(0xFFD32F2F) : Colors.grey),
            title: Text('Analytics & Reports', style: TextStyle(fontSize: 14, fontWeight: _currentModule == 'analytics' ? FontWeight.bold : FontWeight.normal)),
            selected: _currentModule == 'analytics',
            onTap: () {
              setState(() => _currentModule = 'analytics');
              Navigator.pop(context);
            },
          ),
          // M9: AI-Powered Matching & Prediction
          ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            leading: Icon(Icons.auto_awesome, size: 20, color: _currentModule == 'ai_matching' ? Color(0xFFD32F2F) : Colors.grey),
            title: Text('AI Matching & Prediction', style: TextStyle(fontSize: 14, fontWeight: _currentModule == 'ai_matching' ? FontWeight.bold : FontWeight.normal)),
            selected: _currentModule == 'ai_matching',
            onTap: () {
              setState(() => _currentModule = 'ai_matching');
              Navigator.pop(context);
            },
          ),
          Divider(height: 1),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text('SETTINGS', style: TextStyle(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.bold)),
          ),
          ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            leading: Icon(Icons.account_circle, size: 20, color: _currentModule == 'admin_profile' ? Color(0xFFD32F2F) : Colors.grey),
            title: Text('Admin Profile', style: TextStyle(fontSize: 14, fontWeight: _currentModule == 'admin_profile' ? FontWeight.bold : FontWeight.normal)),
            selected: _currentModule == 'admin_profile',
            onTap: () {
              setState(() => _currentModule = 'admin_profile');
              Navigator.pop(context);
            },
          ),
          Divider(height: 1),
          ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            leading: Icon(Icons.exit_to_app, size: 20, color: Colors.grey),
            title: Text('Logout', style: TextStyle(fontSize: 14)),
            onTap: () async {
              Navigator.pop(context);
              if (FirebaseService.initialized) {
                await FirebaseAuth.instance.signOut();
              }
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('demo_logged_in', false);
              await prefs.remove('demo_current_email');
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => LoginScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentModule() {
    switch (_currentModule) {
      case 'donor_requests':
        return _buildModulePage('Donor Requests', _inboxDonorRequests());
      case 'all_donors':
        return _buildModulePage('All Donors', _inboxAllDonors());
      case 'recipients':
        return _buildModulePage('Recipients', _inboxRecipients());
      case 'emergency':
        return _buildModulePage('Emergency Requests', _inboxEmergencyRequests());
      case 'admin_profile':
        return _buildAdminProfile();
      case 'user_profile':
        return _buildUserProfileModule();
      case 'donation_history':
        return _buildDonationHistoryModule();
      case 'communication':
        return _buildCommunicationModule();
      case 'gamification':
        return _buildGamificationModule();
      case 'verification':
        return _buildVerificationModule();
      case 'hospital_bank':
        return _buildHospitalBankModule();
      case 'analytics':
        return _buildAnalyticsModule();
      case 'ai_matching':
        return _buildAIMatchingModule();
      default:
        return _buildOverview();
    }
  }

  Widget _buildOverview() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Overview', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF424242))),
          const SizedBox(height: 8),
          Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              children: [
                SizedBox(
                  width: 130,
                  child: _statCard('Total users', _totalUsers.toString(), Colors.blue, Icons.people),
                ),
                SizedBox(
                  width: 130,
                  child: InkWell(
                    onTap: () {
                      setState(() => _currentModule = 'all_donors');
                    },
                    child: _statCard('Donors', _donors.toString(), Colors.red, Icons.bloodtype),
                  ),
                ),
                SizedBox(
                  width: 130,
                  child: InkWell(
                    onTap: () {
                      setState(() => _currentModule = 'recipients');
                    },
                    child: _statCard('Recipients', _recipients.toString(), Colors.green, Icons.local_hospital),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Quick Access Section
          Row(
            children: [
              Icon(Icons.flash_on, color: Color(0xFFD32F2F), size: 24),
              SizedBox(width: 8),
              Text('Quick Access', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF424242))),
            ],
          ),
          const SizedBox(height: 16),
          
          // Module Grid
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 900 ? 4 : constraints.maxWidth > 600 ? 3 : 2;
              return GridView.count(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.3,
                children: [
                  _quickAccessCard(
                    'User Registration',
                    'Manage all users',
                    Icons.person_add,
                    Color(0xFF1976D2),
                    () => setState(() => _currentModule = 'user_profile'),
                  ),
                  _quickAccessCard(
                    'Emergency Requests',
                    'Urgent blood needs',
                    Icons.emergency,
                    Color(0xFFD32F2F),
                    () => setState(() => _currentModule = 'emergency'),
                  ),
                  _quickAccessCard(
                    'Donation History',
                    'Track donations',
                    Icons.history,
                    Colors.teal,
                    () => setState(() => _currentModule = 'donation_history'),
                  ),
                  _quickAccessCard(
                    'Communication',
                    'Messages & notifications',
                    Icons.chat,
                    Colors.indigo,
                    () => setState(() => _currentModule = 'communication'),
                  ),
                  _quickAccessCard(
                    'Gamification',
                    'Badges & rewards',
                    Icons.emoji_events,
                    Colors.amber.shade700,
                    () => setState(() => _currentModule = 'gamification'),
                  ),
                  _quickAccessCard(
                    'Verification',
                    'User verification',
                    Icons.verified_user,
                    Colors.blue,
                    () => setState(() => _currentModule = 'verification'),
                  ),
                  _quickAccessCard(
                    'Hospital/Bank',
                    'Manage hospitals',
                    Icons.local_hospital,
                    Colors.red.shade700,
                    () => setState(() => _currentModule = 'hospital_bank'),
                  ),
                  _quickAccessCard(
                    'Analytics',
                    'Reports & insights',
                    Icons.analytics,
                    Colors.purple,
                    () => setState(() => _currentModule = 'analytics'),
                  ),
                  _quickAccessCard(
                    'AI Matching',
                    'Smart blood matching',
                    Icons.psychology,
                    Colors.deepPurple,
                    () => setState(() => _currentModule = 'ai_matching'),
                  ),
                  _quickAccessCard(
                    'All Donors',
                    'View all donors',
                    Icons.bloodtype,
                    Colors.red,
                    () => setState(() => _currentModule = 'all_donors'),
                  ),
                  _quickAccessCard(
                    'Recipients',
                    'View all recipients',
                    Icons.favorite,
                    Colors.green,
                    () => setState(() => _currentModule = 'recipients'),
                  ),
                  _quickAccessCard(
                    'Donor Requests',
                    'Pending approvals',
                    Icons.pending_actions,
                    Colors.orange,
                    () => setState(() => _currentModule = 'donor_requests'),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _quickAccessCard(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        padding: EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF424242)),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModulePage(String title, Widget content) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back, color: Color(0xFFD32F2F)),
                onPressed: () {
                  setState(() => _currentModule = 'overview');
                },
              ),
              Icon(Icons.inbox, color: Color(0xFFD32F2F), size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF424242))),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            color: Colors.white,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: 200,
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              child: content,
            ),
          ),
          const SizedBox(height: 16),
          if (_selectedItem != null) ...[
            Text('Details', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF424242))),
            const SizedBox(height: 12),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: _buildDetailsPanel(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- Superadmin manager -----------------------------------------------
  void _openSuperadminManager() {
    showDialog(context: context, builder: (_) {
      return AlertDialog(
        backgroundColor: Colors.white.withOpacity(0.85),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade300, width: 1.5),
        ),
        title: Text('Manage Superadmins'),
        content: SizedBox(width: 600, height: 400, child: _superadminManagerBody()),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('Close'))],
      );
    });
  }

  Widget _superadminManagerBody() {
    // Provide contacts manager + user list. Contacts are stored in demo prefs or in Firestore under 'meta/app_config'.
    if (FirebaseService.initialized) {
      // Firebase path
      return FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance.collection('users').orderBy('createdAt', descending: true).get(),
        builder: (context, snap) {
          if (!snap.hasData) return Center(child: BloodBridgeLoader());
          final docs = snap.data!.docs;
          if (docs.isEmpty) return Center(child: Text('No users found'));
          return Column(
            children: [
              // Contacts manager (firebase)
              FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('meta').doc('app_config').get(),
                builder: (context, csnap) {
                  if (!csnap.hasData) return SizedBox.shrink();
                  final data = csnap.data!.data() as Map<String, dynamic>? ?? {};
                  final List contacts = data['superadmin_contacts'] ?? [];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Superadmin Contacts', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, children: [
                        for (int i = 0; i < contacts.length; i++) Chip(label: Text('${contacts[i]}'), onDeleted: () async { final newList = contacts.map((e) => e.toString()).toList(); newList.removeAt(i); await FirebaseFirestore.instance.collection('meta').doc('app_config').set({'superadmin_contacts': newList}, SetOptions(merge: true)); setState(() {}); }),
                        ActionChip(label: Text('Add'), onPressed: () => _editContactFirebase(null)),
                      ])
                    ]),
                  );
                },
              ),

              const SizedBox(height: 8),

              Expanded(
                child: ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => Divider(height: 1),
            itemBuilder: (context, i) {
              final d = docs[i];
              final Map<String, dynamic> u = d.data() as Map<String, dynamic>;
              final role = (u['role'] ?? '').toString();
              final isSuper = role == 'super_admin';
              return ListTile(
                title: Text(u['name'] ?? u['email'] ?? 'User'),
                subtitle: Text(u['email'] ?? ''),
                trailing: isSuper
                    ? ElevatedButton(onPressed: null, child: Text('Superadmin'))
                    : ElevatedButton(child: Text('Make super'), onPressed: () async { await _setSuperadminFirebase(d.id, true); setState(() {}); }),
              );
            },
                ),
              ),
            ],
          );
        },
      );
    }

    return FutureBuilder<List<String>>(
      future: SharedPreferences.getInstance().then((p) => p.getStringList('demo_users') ?? <String>[]),
      builder: (context, snap) {
        if (!snap.hasData) return Center(child: BloodBridgeLoader());
        final list = snap.data!;
        if (list.isEmpty) return Center(child: Text('No demo users'));
        return Column(
          children: [
            // Contacts manager (demo)
            FutureBuilder<List<String>>(
              future: SharedPreferences.getInstance().then((p) => p.getStringList('superadmin_contacts') ?? <String>[]),
              builder: (context, csnap) {
                if (!csnap.hasData) return SizedBox.shrink();
                final contacts = csnap.data!;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Superadmin Contacts', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, children: [
                      for (int i = 0; i < contacts.length; i++) Chip(label: Text(contacts[i]), onDeleted: () async { final prefs = await SharedPreferences.getInstance(); final newList = contacts.map((e) => e.toString()).toList(); newList.removeAt(i); await prefs.setStringList('superadmin_contacts', newList); setState(() {}); }),
                      ActionChip(label: Text('Add'), onPressed: () => _editContactDemo(null)),
                    ])
                  ]),
                );
              },
            ),

            const SizedBox(height: 8),

            Expanded(
              child: ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, __) => Divider(height: 1),
                itemBuilder: (context, i) {
            try {
              final Map<String, dynamic> u = jsonDecode(list[i]);
              final role = (u['role'] ?? '').toString();
              final isSuper = role == 'super_admin';
              return ListTile(
                title: Text(u['name'] ?? u['email'] ?? 'User'),
                subtitle: Text(u['email'] ?? ''),
                trailing: isSuper
                    ? ElevatedButton(onPressed: null, child: Text('Superadmin'))
                    : ElevatedButton(child: Text('Make super'), onPressed: () async { await _setSuperadminDemo(i, true); setState(() {}); }),
              );
            } catch (e) {
              return ListTile(title: Text('Invalid entry'));
            }
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // --- Contact editing helpers -----------------------------------------
  void _editContactDemo(int? index) async {
    final prefs = await SharedPreferences.getInstance();
    final contacts = prefs.getStringList('superadmin_contacts') ?? <String>[];
    final controller = TextEditingController(text: index != null && index >= 0 && index < contacts.length ? contacts[index] : '');
    final ok = await showDialog<bool>(context: context, builder: (_) {
      return AlertDialog(
        backgroundColor: Colors.white.withOpacity(0.85),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade300, width: 1.5),
        ),
        title: Text(index == null ? 'Add contact' : 'Edit contact'),
        content: TextField(controller: controller, decoration: InputDecoration(labelText: 'Phone number')),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.black,
              side: BorderSide(color: Colors.black, width: 2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: Text('Cancel'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.black,
              side: BorderSide(color: Colors.black, width: 2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: Text('Save'),
          ),
        ],
      );
    });
    if (ok != true) return;
    final t = controller.text.trim();
    final newList = List<String>.from(contacts);
    if (index == null) {
      newList.add(t);
    } else {
      newList[index] = t;
    }
    await prefs.setStringList('superadmin_contacts', newList);
    setState(() {});
  }

  void _editContactFirebase(String? indexStr) async {
    final docRef = FirebaseFirestore.instance.collection('meta').doc('app_config');
    final doc = await docRef.get();
    final data = doc.data() ?? {};
    final List contacts = data['superadmin_contacts'] ?? [];
    int? index = indexStr == null ? null : int.tryParse(indexStr);
    final controller = TextEditingController(text: index != null && index >= 0 && index < contacts.length ? contacts[index] : '');
    final ok = await showDialog<bool>(context: context, builder: (_) {
      return AlertDialog(
        backgroundColor: Colors.white.withOpacity(0.85),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade300, width: 1.5),
        ),
        title: Text(index == null ? 'Add contact' : 'Edit contact'),
        content: TextField(controller: controller, decoration: InputDecoration(labelText: 'Phone number')),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.black,
              side: BorderSide(color: Colors.black, width: 2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: Text('Cancel'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.black,
              side: BorderSide(color: Colors.black, width: 2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: Text('Save'),
          ),
        ],
      );
    });
    if (ok != true) return;
    final t = controller.text.trim();
    final newList = contacts.map((e) => e.toString()).toList();
    if (index == null) {
      newList.add(t);
    } else {
      newList[index] = t;
    }
    await docRef.set({'superadmin_contacts': newList}, SetOptions(merge: true));
    setState(() {});
  }

  Future<void> _setSuperadminFirebase(String uid, bool makeSuper) async {
    try {
      final docRef = FirebaseFirestore.instance.collection('users').doc(uid);
      await docRef.update({'role': makeSuper ? 'super_admin' : 'recipient'});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(makeSuper ? 'Granted super admin' : 'Revoked super admin')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _setSuperadminDemo(int index, bool makeSuper) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('demo_users') ?? <String>[];
    if (index < 0 || index >= list.length) return;
    try {
      final Map<String, dynamic> u = jsonDecode(list[index]);
      u['role'] = makeSuper ? 'super_admin' : 'recipient';
      list[index] = jsonEncode(u);
      await prefs.setStringList('demo_users', list);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(makeSuper ? 'Granted super admin (demo)' : 'Revoked super admin (demo)')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  // --- Inbox list builders ------------------------------------------------
  Widget _inboxDonorRequests() {
    if (FirebaseService.initialized) {
      return FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance.collection('donor_requests').orderBy('requestedAt', descending: true).get(),
        builder: (context, snap) {
          if (!snap.hasData) return Center(child: BloodBridgeLoader());
          final docs = snap.data!.docs;
          if (docs.isEmpty) return Center(child: Text('No donor requests'));
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final d = docs[i];
              final Map<String, dynamic> rd = d.data() as Map<String, dynamic>;
              return Card(
                margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedItem = Map<String, dynamic>.from(rd);
                      _selectedType = 'donor_request';
                      _selectedId = d.id;
                    });
                  },
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Donor Request', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: (rd['status'] ?? 'pending') == 'approved' ? Colors.green : Colors.orange,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(rd['status'] ?? 'pending', style: TextStyle(color: Colors.white, fontSize: 10)),
                            ),
                          ],
                      ),
                        SizedBox(height: 8),
                        Text('Donor: ${rd['donorEmail'] ?? 'Unknown'}', style: TextStyle(fontWeight: FontWeight.bold)),
                        SizedBox(height: 4),
                        Text('Requester: ${rd['requesterEmail'] ?? 'N/A'}'),
                        SizedBox(height: 2),
                        Text('Phone: ${rd['requesterPhone'] ?? 'N/A'}', style: TextStyle(color: Colors.grey[700])),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    }

    return FutureBuilder<List<String>>(
      future: SharedPreferences.getInstance().then((p) => p.getStringList('donor_requests') ?? <String>[]),
      builder: (context, snap) {
        if (!snap.hasData) return Center(child: BloodBridgeLoader());
        final list = snap.data!;
        if (list.isEmpty) return Center(child: Text('No donor requests (demo)'));
        return ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, i) {
            try {
              final Map<String, dynamic> r = jsonDecode(list[i]);
              return Card(
                margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: InkWell(
                  onTap: () => setState(() { _selectedItem = Map<String, dynamic>.from(r); _selectedType = 'donor_request'; _selectedId = i.toString(); }),
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Donor Request', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: (r['status'] ?? 'pending') == 'approved' ? Colors.green : Colors.orange,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(r['status'] ?? 'pending', style: TextStyle(color: Colors.white, fontSize: 10)),
                            ),
                          ],
                      ),
                        SizedBox(height: 8),
                        Text('Donor: ${r['donorEmail'] ?? 'Unknown'}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.person, size: 14, color: Colors.grey[600]),
                            SizedBox(width: 4),
                            Text('${r['designation'] ?? 'N/A'}', style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                          ],
                      ),
                        SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.email, size: 14, color: Colors.grey[600]),
                            SizedBox(width: 4),
                            Text('${r['email'] ?? 'N/A'}', style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                          ],
                      ),
                        SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.phone, size: 14, color: Colors.grey[600]),
                            SizedBox(width: 4),
                            Text('${r['contact'] ?? 'N/A'}', style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                          ],
                      ),
                      ],
                    ),
                  ),
                ),
              );
            } catch (e) {
              return Card(child: ListTile(title: Text('Invalid request')));
            }
          },
        );
      },
    );
  }

  Widget _inboxAllDonors() {
    if (FirebaseService.initialized) {
      return FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'donor').get(),
        builder: (context, snap) {
          if (!snap.hasData) return Center(child: BloodBridgeLoader());
          final docs = snap.data!.docs;
          if (docs.isEmpty) return Center(child: Text('No donors found'));
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final d = docs[i];
              final Map<String, dynamic> rd = d.data() as Map<String, dynamic>;
              final approved = rd['approved'] ?? false;
              return Card(
                margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.bloodtype, color: Colors.white, size: 14),
                                    SizedBox(width: 4),
                                    Text(
                                      '${rd['bloodGroup'] ?? 'N/A'}',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: approved ? Colors.green : Colors.orange,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(approved ? 'Approved' : 'Pending', style: TextStyle(color: Colors.white, fontSize: 10)),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text('${rd['name'] ?? 'N/A'}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.person, size: 14, color: Colors.grey[600]),
                          SizedBox(width: 4),
                          Text('${rd['designation'] ?? 'N/A'}', style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                        ],
                      ),
                      SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.email, size: 14, color: Colors.grey[600]),
                          SizedBox(width: 4),
                          Text('${rd['email'] ?? 'N/A'}', style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                        ],
                      ),
                      SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.phone, size: 14, color: Colors.grey[600]),
                          SizedBox(width: 4),
                          Text('${rd['contact'] ?? 'N/A'}', style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    }

    return FutureBuilder<List<String>>(
      future: SharedPreferences.getInstance().then((p) => p.getStringList('demo_users') ?? <String>[]),
      builder: (context, snap) {
        if (!snap.hasData) return Center(child: BloodBridgeLoader());
        final list = snap.data!;
        final donors = list.where((s) {
          try {
            final Map<String, dynamic> u = jsonDecode(s);
            return (u['role'] ?? '') == 'donor';
          } catch (_) {
            return false;
          }
        }).toList();
        
        if (donors.isEmpty) return Center(child: Text('No donors found (demo)'));
        
        return ListView.builder(
          itemCount: donors.length,
          itemBuilder: (context, i) {
            try {
              final Map<String, dynamic> rd = jsonDecode(donors[i]);
              final approved = rd['approved'] ?? false;
              return Card(
                margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.bloodtype, color: Colors.white, size: 14),
                                    SizedBox(width: 4),
                                    Text(
                                      '${rd['bloodGroup'] ?? 'N/A'}',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: approved ? Colors.green : Colors.orange,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(approved ? 'Approved' : 'Pending', style: TextStyle(color: Colors.white, fontSize: 10)),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text('${rd['name'] ?? 'N/A'}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.person, size: 14, color: Colors.grey[600]),
                          SizedBox(width: 4),
                          Text('${rd['designation'] ?? 'N/A'}', style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                        ],
                      ),
                      SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.email, size: 14, color: Colors.grey[600]),
                          SizedBox(width: 4),
                          Text('${rd['email'] ?? 'N/A'}', style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                        ],
                      ),
                      SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.phone, size: 14, color: Colors.grey[600]),
                          SizedBox(width: 4),
                          Text('${rd['contact'] ?? 'N/A'}', style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            } catch (e) {
              return Card(child: ListTile(title: Text('Invalid donor data')));
            }
          },
        );
      },
    );
  }

  Widget _inboxRecipients() {
    if (FirebaseService.initialized) {
      return FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'recipient').get(),
        builder: (context, snap) {
          if (!snap.hasData) return Center(child: BloodBridgeLoader());
          final docs = snap.data!.docs;
          if (docs.isEmpty) return Center(child: Text('No recipients found'));
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, i) {
              try {
              final d = docs[i];
              final Map<String, dynamic> rd = d.data() as Map<String, dynamic>;
              return Card(
                margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.add, color: Colors.white, size: 14),
                                    SizedBox(width: 4),
                                    Text(
                                      '${rd['bloodGroup'] ?? 'N/A'}',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.green),
                            ),
                            child: Text(
                              'NORMAL',
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Text(
                        '${rd['name'] ?? 'Unknown'}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                      ),
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                          SizedBox(width: 4),
                          Text(
                            '${rd['location'] ?? 'N/A'}',
                            style: TextStyle(color: Colors.grey[600], fontSize: 13),
                          ),
                        ],
                      ),
                      Divider(height: 20),
                      Row(
                        children: [
                          Icon(Icons.work, size: 16, color: Colors.grey[700]),
                          SizedBox(width: 8),
                          Text(
                            '${rd['designation'] ?? 'Medical Emergency'}',
                            style: TextStyle(color: Colors.grey[700], fontSize: 13),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Icon(Icons.phone, size: 16, color: Colors.grey[700]),
                                SizedBox(width: 8),
                                Text(
                                  '${rd['contact'] ?? 'N/A'}',
                                  style: TextStyle(color: Colors.grey[700], fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Row(
                              children: [
                                Icon(Icons.email, size: 16, color: Colors.grey[700]),
                                SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    '${rd['email'] ?? 'N/A'}',
                                    style: TextStyle(color: Colors.grey[700], fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            } catch (e) {
              return SizedBox.shrink();
            }
          },
        );
      },
    );
    }

    return Center(child: Text('Recipients not available'));
  }

  Widget _inboxEmergencyRequests() {
    if (FirebaseService.initialized) {
      return FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance.collection('emergency_requests').orderBy('requestedAt', descending: true).get(),
        builder: (context, snap) {
          if (!snap.hasData) return Center(child: BloodBridgeLoader());
          final docs = snap.data!.docs;
          if (docs.isEmpty) return Center(child: Text('No emergency requests'));
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final d = docs[i];
              final Map<String, dynamic> rd = d.data() as Map<String, dynamic>;
              return Card(
                margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.red.withOpacity(0.2), width: 1),
                ),
                child: InkWell(
                  onTap: () => setState(() { _selectedItem = Map<String, dynamic>.from(rd); _selectedType = 'emergency'; _selectedId = d.id; }),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.red.withOpacity(0.05), Colors.white],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.red[700],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.emergency, color: Colors.white, size: 14),
                                    SizedBox(width: 4),
                                    Text('Emergency Request', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: (rd['urgency'] ?? 'normal') == 'critical' ? Colors.red[900] : Colors.orange[700],
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: ((rd['urgency'] ?? 'normal') == 'critical' ? Colors.red : Colors.orange).withOpacity(0.3),
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text((rd['urgency'] ?? 'normal').toUpperCase(), style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          // Blood Group
                          Row(
                            children: [
                              Icon(Icons.bloodtype, color: Colors.red[700], size: 20),
                              SizedBox(width: 8),
                              Text('Blood Group: ${rd['bloodGroup'] ?? 'N/A'}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red[800])),
                            ],
                          ),
                          SizedBox(height: 8),
                          // Phone Number
                          Row(
                            children: [
                              Icon(Icons.phone, size: 18, color: Colors.blue[700]),
                              SizedBox(width: 8),
                              Expanded(child: Text('${rd['requesterPhone'] ?? 'N/A'}', style: TextStyle(fontSize: 14, color: Colors.blue[800]))),
                            ],
                          ),
                          // Location
                          if (rd['location'] != null && rd['location'].toString().isNotEmpty) ...[
                            SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.location_on, size: 18, color: Colors.green[700]),
                                SizedBox(width: 8),
                                Expanded(child: Text('${rd['location'] ?? 'N/A'}', style: TextStyle(color: Colors.green[800], fontSize: 13))),
                              ],
                            ),
                          ],
                          SizedBox(height: 8),
                          // Status
                          Row(
                            children: [
                              Icon(Icons.info_outline, size: 18, color: (rd['status'] ?? 'new') == 'handled' ? Colors.green[700] : Colors.blue[700]),
                              SizedBox(width: 8),
                              Text('Status: ${rd['status'] ?? 'new'}', style: TextStyle(fontSize: 13, color: (rd['status'] ?? 'new') == 'handled' ? Colors.green[800] : Colors.blue[800], fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    }

    return FutureBuilder<List<String>>(
      future: SharedPreferences.getInstance().then((p) => p.getStringList('emergency_requests') ?? <String>[]),
      builder: (context, snap) {
        if (!snap.hasData) return Center(child: BloodBridgeLoader());
        final list = snap.data!;
        if (list.isEmpty) return Center(child: Text('No emergency requests (demo)'));
        return ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, i) {
            try {
              final Map<String, dynamic> r = jsonDecode(list[i]);
              return Card(
                margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.red.withOpacity(0.2), width: 1),
                ),
                child: InkWell(
                  onTap: () => setState(() { _selectedItem = Map<String, dynamic>.from(r); _selectedType = 'emergency'; _selectedId = i.toString(); }),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.red.withOpacity(0.05), Colors.white],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.red[700],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.emergency, color: Colors.white, size: 14),
                                    SizedBox(width: 4),
                                    Text('Emergency Request', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: (r['urgency'] ?? 'normal') == 'critical' ? Colors.red[900] : Colors.orange[700],
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: ((r['urgency'] ?? 'normal') == 'critical' ? Colors.red : Colors.orange).withOpacity(0.3),
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text((r['urgency'] ?? 'normal').toUpperCase(), style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          // Blood Group
                          Row(
                            children: [
                              Icon(Icons.bloodtype, color: Colors.red[700], size: 20),
                              SizedBox(width: 8),
                              Text('Blood Group: ${r['bloodGroup'] ?? 'N/A'}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red[800])),
                            ],
                          ),
                          SizedBox(height: 8),
                          // Phone Number
                          Row(
                            children: [
                              Icon(Icons.phone, size: 18, color: Colors.blue[700]),
                              SizedBox(width: 8),
                              Expanded(child: Text('${r['requesterPhone'] ?? 'N/A'}', style: TextStyle(fontSize: 14, color: Colors.blue[800]))),
                            ],
                          ),
                          // Location
                          if (r['location'] != null && r['location'].toString().isNotEmpty) ...[
                            SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.location_on, size: 18, color: Colors.green[700]),
                                SizedBox(width: 8),
                                Expanded(child: Text('${r['location'] ?? 'N/A'}', style: TextStyle(color: Colors.green[800], fontSize: 13))),
                              ],
                            ),
                          ],
                          SizedBox(height: 8),
                          // Status
                          Row(
                            children: [
                              Icon(Icons.info_outline, size: 18, color: (r['status'] ?? 'new') == 'handled' ? Colors.green[700] : Colors.blue[700]),
                              SizedBox(width: 8),
                              Text('Status: ${r['status'] ?? 'new'}', style: TextStyle(fontSize: 13, color: (r['status'] ?? 'new') == 'handled' ? Colors.green[800] : Colors.blue[800], fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            } catch (e) {
              return Card(child: ListTile(title: Text('Invalid entry')));
            }
          },
        );
      },
    );
  }

  Widget _inboxForgotRequests() {
    if (FirebaseService.initialized) {
      return Center(child: Text('Forgot requests are server-managed'));
    }
    return FutureBuilder<List<String>>(
      future: SharedPreferences.getInstance().then((p) => p.getStringList('forgot_requests') ?? <String>[]),
      builder: (context, snap) {
        if (!snap.hasData) return Center(child: BloodBridgeLoader());
        final list = snap.data!;
        if (list.isEmpty) return Center(child: Text('No requests'));
        return ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, i) {
            try {
              final Map<String, dynamic> r = jsonDecode(list[i]);
              return Card(
                margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: InkWell(
                  onTap: () => setState(() { _selectedItem = Map<String, dynamic>.from(r); _selectedType = 'forgot'; _selectedId = i.toString(); }),
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Password Reset', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: (r['status'] ?? 'pending') == 'handled' ? Colors.green : Colors.blue,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(r['status'] ?? 'pending', style: TextStyle(color: Colors.white, fontSize: 10)),
                            ),
                          ],
                      ),
                        SizedBox(height: 8),
                        Text('Email: ${r['email'] ?? 'Unknown'}', style: TextStyle(fontWeight: FontWeight.bold)),
                        SizedBox(height: 4),
                        Text('Requested: ${r['requestedAt'] ?? 'N/A'}', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                      ],
                    ),
                  ),
                ),
              );
            } catch (e) { return Card(child: ListTile(title: Text('Invalid'))); }
          },
        );
      },
    );
  }

  // --- Details panel ------------------------------------------------------
  Widget _buildDetailsPanel() {
    if (_selectedItem == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'Select an item from the inbox',
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'to view details',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }
    final item = _selectedItem!;
    final type = _selectedType ?? '';
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: type == 'emergency' 
              ? [Color(0xFFFFF5F5), Color(0xFFFFEBEE)] 
              : [Color(0xFFF5F5FF), Color(0xFFEDE7F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: type == 'emergency' ? Colors.red.shade200 : Colors.blue.shade200,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: type == 'emergency'
                    ? [Colors.red[700]!, Colors.red[600]!]
                    : [Colors.blue[700]!, Colors.blue[600]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
              boxShadow: [
                BoxShadow(
                  color: (type == 'emergency' ? Colors.red : Colors.blue).withOpacity(0.3),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      type == 'emergency' ? Icons.emergency_share : Icons.info_outline,
                      color: Colors.white,
                      size: 28,
                    ),
                    SizedBox(width: 12),
                    Text(
                      type.toUpperCase().replaceAll('_', ' '),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _selectedItem = null;
                      _selectedType = null;
                      _selectedId = null;
                    });
                  },
                  icon: Icon(Icons.close, color: Colors.white),
                  tooltip: 'Close',
                ),
              ],
            ),
          ),
          
          // Content
          Padding(
            padding: EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: 300),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (type == 'emergency') ...[
                      // Emergency request with attractive styling
                      _buildDetailRow('Blood Group', item['bloodGroup']?.toString() ?? 'N/A', Icons.bloodtype, Colors.red[700]!, isBold: true, isLarge: true),
                      _buildDetailRow('Urgency', item['urgency']?.toString() ?? 'normal', Icons.warning_amber, 
                        (item['urgency'] ?? 'normal') == 'critical' ? Colors.red[800]! : Colors.orange[700]!, 
                        showBadge: true),
                      _buildDetailRow('Status', item['status']?.toString() ?? 'new', Icons.info_outline, 
                        (item['status'] ?? 'new') == 'handled' ? Colors.green[700]! : Colors.blue[700]!,
                        showBadge: true),
                      
                      SizedBox(height: 8),
                      Container(
                        height: 3,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.red[300]!, Colors.red[100]!, Colors.transparent],
                          ),
                          borderRadius: BorderRadius.circular(2),
                      ),
                      ),
                      SizedBox(height: 16),
                      
                      _buildDetailRow('Phone', item['requesterPhone']?.toString() ?? 'N/A', Icons.phone, Colors.blue[800]!),
                      if (item['location'] != null && item['location'].toString().isNotEmpty)
                        _buildDetailRow('Location', item['location']?.toString() ?? 'N/A', Icons.location_on, Colors.green[700]!),
                      if (item['hospitalName'] != null)
                        _buildDetailRow('Hospital', item['hospitalName']?.toString() ?? '', Icons.local_hospital, Colors.purple[700]!),
                      if (item['requestedAt'] != null)
                        _buildDetailRow('Requested At', item['requestedAt']?.toString() ?? '', Icons.access_time, Colors.grey[700]!),
                      if (item['notes'] != null && item['notes'].toString().isNotEmpty)
                        _buildDetailRow('Notes', item['notes']?.toString() ?? '', Icons.note, Colors.amber[800]!, multiLine: true),
                    ] else ...[
                      // Other request types - enhanced styling
                      ...item.entries.map((e) => Container(
                        margin: EdgeInsets.only(bottom: 12),
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.blue.shade200),
                      ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${e.key}: ',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Colors.blue[800],
                                fontSize: 14,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                '${e.value}',
                                softWrap: true,
                                style: TextStyle(
                                  color: Colors.grey[800],
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                      ),
                      )),
                    ],
                  ],
                ),
              ),
            ),
          ),
          
          // Action Buttons
          Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.end,
              children: [
                if (type == 'donor_request') 
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFF4CAF50).withOpacity(0.4),
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Approve',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      onPressed: () => _approveSelected(),
                    ),
                  ),
                if (type == 'emergency')
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFD32F2F), Color(0xFFEF5350)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFFD32F2F).withOpacity(0.4),
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.done_all, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Mark Handled',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      onPressed: () => _handleSelectedEmergency(),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _approveSelected() async {
    if (_selectedType != 'donor_request' || _selectedItem == null) return;
    if (FirebaseService.initialized) {
      try {
        await FirebaseFirestore.instance.collection('donor_requests').doc(_selectedId).update({'status': 'approved', 'handledBy': FirebaseAuth.instance.currentUser?.email ?? 'admin', 'handledAt': DateTime.now().toIso8601String(), 'sharedData': _selectedItem});
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Approved')));
      } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'))); }
    } else {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('donor_requests') ?? <String>[];
      final idx = int.tryParse(_selectedId ?? '0') ?? 0;
      if (idx < 0 || idx >= list.length) return;
      final Map<String, dynamic> r = jsonDecode(list[idx]);
      r['status'] = 'approved';
      r['handledBy'] = prefs.getString('demo_current_email') ?? 'superadmin@bloodbridge.app';
      r['handledAt'] = DateTime.now().toIso8601String();
      r['sharedData'] = _selectedItem;
      list[idx] = jsonEncode(r);
      await prefs.setStringList('donor_requests', list);
      setState(() { _selectedItem = Map<String, dynamic>.from(r); });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Approved (demo)')));
    }
  }

  Future<void> _handleSelectedEmergency() async {
    if (_selectedType != 'emergency' || _selectedItem == null) return;
    if (FirebaseService.initialized) {
      try {
        await FirebaseFirestore.instance.collection('emergency_requests').doc(_selectedId).update({'status': 'handled', 'handledBy': FirebaseAuth.instance.currentUser?.email ?? 'admin', 'handledAt': DateTime.now().toIso8601String()});
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Marked handled')));
      } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'))); }
    } else {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('emergency_requests') ?? <String>[];
      final idx = int.tryParse(_selectedId ?? '0') ?? 0;
      if (idx < 0 || idx >= list.length) return;
      final Map<String, dynamic> r = jsonDecode(list[idx]);
      r['status'] = 'handled';
      r['handledBy'] = prefs.getString('demo_current_email') ?? 'superadmin@bloodbridge.app';
      r['handledAt'] = DateTime.now().toIso8601String();
      list[idx] = jsonEncode(r);
      await prefs.setStringList('emergency_requests', list);
      setState(() { _selectedItem = Map<String, dynamic>.from(r); });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Marked handled (demo)')));
    }
  }

  Widget _sectionCard(BuildContext context, {required String title, required Widget child}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.inbox, color: Color(0xFFD32F2F), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF212121)))
                ]),
                IconButton(
                  icon: const Icon(Icons.refresh_outlined, color: Color(0xFFD32F2F)),
                  tooltip: 'Refresh',
                  onPressed: () => _loadStats(),
                )
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(borderRadius: BorderRadius.circular(8), child: child),
          ],
        ),
      ),
    );
  }

  // (Replaced by inbox variants: _inboxForgotRequests)

  // Forgot request handler moved to inbox flow (demo handled via details)

  // (Replaced by inbox variants: _inboxDonorRequests)

  // Donor request handling is now via inbox approveSelected / demo flow

  // Demo donor-request approve moved to approveSelected

  // (Replaced by inbox variants: _inboxEmergencyRequests)

  // Emergency handling is via _handleSelectedEmergency

  // Demo emergency handling moved to _handleSelectedEmergency

  Widget _buildRecentList() {
    if (FirebaseService.initialized) {
      return FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance.collection('users').orderBy('createdAt', descending: true).get(),
        builder: (context, snap) {
          if (!snap.hasData) return Center(child: BloodBridgeLoader());
          final docs = snap.data!.docs;
          if (docs.isEmpty) return Center(child: Text('No registrations yet'));
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final d = docs[i];
              final data = d.data() as Map<String, dynamic>;
              final approved = data['approved'] ?? false;
                  return ListTile(
                    title: Text(data['name'] ?? 'No name'),
                    subtitle: Text('${data['bloodGroup'] ?? ''} • ${data['role'] ?? ''}'),
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => UserProfileScreen(firebaseUid: d.id)));
                    },
                    trailing: ElevatedButton(
                      onPressed: approved ? null : () async {
                        await FirebaseFirestore.instance.collection('users').doc(d.id).update({'approved': true});
                        // Try to send SMS notification to the user (open SMS app with prefilled message)
                        try {
                          final data = d.data() as Map<String, dynamic>;
                          final phone = (data['contact'] ?? '').toString();
                          final name = (data['name'] ?? 'User').toString();
                          if (phone.isNotEmpty) {
                            final body = Uri.encodeComponent('Hello $name, your account/request has been approved on Blood Bridge.');
                            final uri = Uri.parse('sms:$phone?body=$body');
                            await launchUrl(uri);
                          }
                        } catch (e) {
                          // ignore SMS send failures
                        }
                        _loadStats();
                      },
                      child: Text(approved ? 'Approved' : 'Approve'),
                    ),
                  );
            },
          );
        },
      );
    }

    // Demo path: read demo_users list
    return FutureBuilder<List<String>>(
      future: SharedPreferences.getInstance().then((p) => p.getStringList('demo_users') ?? <String>[]),
      builder: (context, snap) {
        if (!snap.hasData) return Center(child: BloodBridgeLoader());
        final list = snap.data!;
        if (list.isEmpty) return Center(child: Text('No registrations (demo)'));
        return ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, i) {
            try {
              final Map<String, dynamic> u = jsonDecode(list[i]);
              final isDonor = (u['role'] ?? '') == 'donor';
              final approved = u['approved'] == true;
                  return ListTile(
                    leading: CircleAvatar(child: Text((i+1).toString())),
                    title: Text(u['name'] ?? 'No name'),
                    subtitle: Text('${u['bloodGroup'] ?? ''} • ${u['role'] ?? ''}'),
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => UserProfileScreen(demoData: u)));
                    },
                    trailing: isDonor ? ElevatedButton(
                      onPressed: approved ? null : () async {
                        // toggle approved in prefs
                        final prefs = await SharedPreferences.getInstance();
                        final list2 = prefs.getStringList('demo_users') ?? <String>[];
                        final Map<String, dynamic> uu = jsonDecode(list2[i]);
                        uu['approved'] = true;
                        list2[i] = jsonEncode(uu);
                        await prefs.setStringList('demo_users', list2);
                          // Simulate SMS for demo: save to sent_sms list and show snackbar
                          try {
                            final phone = (uu['contact'] ?? '').toString();
                            final name = (uu['name'] ?? 'User').toString();
                            if (phone.isNotEmpty) {
                              final msgs = prefs.getStringList('sent_sms') ?? <String>[];
                              final msg = {'to': phone, 'body': 'Hello $name, your account/request has been approved on Blood Bridge.', 'at': DateTime.now().toIso8601String()};
                              msgs.add(jsonEncode(msg));
                              await prefs.setStringList('sent_sms', msgs);
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Simulated SMS saved for $phone')));
                            }
                          } catch (_) {}
                        setState(() {});
                      },
                      child: Text(approved ? 'Approved' : 'Approve'),
                    ) : null,
                  );
            } catch (e) {
              return ListTile(title: Text('Invalid entry'));
            }
          },
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon, Color color, {bool isBold = false, bool isLarge = false, bool showBadge = false, bool multiLine = false}) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.08), color.withOpacity(0.02)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.15),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: multiLine ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withOpacity(0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      color: color.withOpacity(0.8),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  SizedBox(height: 6),
                  showBadge
                      ? Container(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [color, color.withOpacity(0.8)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: color.withOpacity(0.4),
                                blurRadius: 6,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Text(
                            value.toUpperCase(),
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              letterSpacing: 1,
                            ),
                          ),
                        )
                      : Text(
                          value,
                          style: TextStyle(
                            fontSize: isLarge ? 22 : 16,
                            fontWeight: isBold ? FontWeight.w800 : FontWeight.w700,
                            color: color.withOpacity(0.95),
                            height: 1.3,
                          ),
                          softWrap: true,
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String title, String value, Color color, IconData icon) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.8), color],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 24),
              SizedBox(height: 6),
              Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
              SizedBox(height: 3),
              Text(title, style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.w500), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  // =====================================================================
  // M1: User Registration & Profile Management
  // =====================================================================
  Widget _buildUserProfileModule() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _moduleHeader('User Registration & Profile', Icons.person_add, Color(0xFF1976D2)),
          const SizedBox(height: 16),
          
          // Stats Row
          Row(
            children: [
              Expanded(child: _miniStatCard('Total Users', _totalUsers.toString(), Icons.people, Colors.blue)),
              SizedBox(width: 12),
              Expanded(child: _miniStatCard('Donors', _donors.toString(), Icons.bloodtype, Colors.red)),
              SizedBox(width: 12),
              Expanded(child: _miniStatCard('Recipients', _recipients.toString(), Icons.local_hospital, Colors.green)),
            ],
          ),
          const SizedBox(height: 20),
          
          // User List
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Color(0xFF1976D2).withOpacity(0.1),
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.list_alt, color: Color(0xFF1976D2)),
                      SizedBox(width: 8),
                      Text('All Registered Users', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1976D2))),
                      Spacer(),
                      ElevatedButton.icon(
                        icon: Icon(Icons.person_add, size: 18),
                        label: Text('Add User'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF1976D2),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onPressed: () => _showAddUserDialog(),
                      ),
                      SizedBox(width: 8),
                      IconButton(
                        icon: Icon(Icons.refresh, color: Color(0xFF1976D2)),
                        onPressed: _loadStats,
                      ),
                    ],
                  ),
                ),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: 400),
                  child: _buildUserList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddUserDialog() {
    final nameCtl = TextEditingController();
    final emailCtl = TextEditingController();
    final phoneCtl = TextEditingController();
    final passwordCtl = TextEditingController();
    final locationCtl = TextEditingController();
    String selectedRole = 'donor';
    String selectedBloodGroup = 'A+';

    final bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
    final roles = ['donor', 'recipient', 'admin', 'super_admin'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white.withOpacity(0.85),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade300, width: 1.5),
          ),
          title: Row(
            children: [
              Icon(Icons.person_add, color: Colors.green),
              SizedBox(width: 8),
              Text('Add New User'),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtl,
                    decoration: InputDecoration(
                      labelText: 'Full Name *',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  SizedBox(height: 12),
                  TextField(
                    controller: emailCtl,
                    decoration: InputDecoration(
                      labelText: 'Email *',
                      prefixIcon: Icon(Icons.email),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  SizedBox(height: 12),
                  TextField(
                    controller: passwordCtl,
                    decoration: InputDecoration(
                      labelText: 'Password *',
                      prefixIcon: Icon(Icons.lock),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    obscureText: true,
                  ),
                  SizedBox(height: 12),
                  TextField(
                    controller: phoneCtl,
                    decoration: InputDecoration(
                      labelText: 'Phone',
                      prefixIcon: Icon(Icons.phone),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  SizedBox(height: 12),
                  TextField(
                    controller: locationCtl,
                    decoration: InputDecoration(
                      labelText: 'Location',
                      prefixIcon: Icon(Icons.location_on),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedRole,
                    decoration: InputDecoration(
                      labelText: 'Role *',
                      prefixIcon: Icon(Icons.badge),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    items: roles.map((r) => DropdownMenuItem(value: r, child: Text(r.toUpperCase()))).toList(),
                    onChanged: (v) => setDialogState(() => selectedRole = v!),
                  ),
                  SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedBloodGroup,
                    decoration: InputDecoration(
                      labelText: 'Blood Group *',
                      prefixIcon: Icon(Icons.bloodtype),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    items: bloodGroups.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                    onChanged: (v) => setDialogState(() => selectedBloodGroup = v!),
                  ),
                ],
              ),
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
              child: Text('Cancel'),
            ),
            OutlinedButton.icon(
              icon: Icon(Icons.add),
              label: Text('Add User'),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.black,
                side: BorderSide(color: Colors.black, width: 2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: () async {
                if (nameCtl.text.trim().isEmpty || emailCtl.text.trim().isEmpty || passwordCtl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please fill all required fields'), backgroundColor: Colors.red));
                  return;
                }
                final newUser = {
                  'name': nameCtl.text.trim(),
                  'email': emailCtl.text.trim(),
                  'password': passwordCtl.text.trim(),
                  'phone': phoneCtl.text.trim(),
                  'location': locationCtl.text.trim(),
                  'role': selectedRole,
                  'bloodGroup': selectedBloodGroup,
                  'verified': false,
                  'createdAt': DateTime.now().toString(),
                };
                await _addUser(newUser);
                if (mounted) {
                  Navigator.pop(context);
                  setState(() {
                    // Trigger rebuild to refresh user list
                  });
                  _loadStats();
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('User added successfully'), backgroundColor: Colors.green));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addUser(Map<String, dynamic> data) async {
    if (FirebaseService.initialized) {
      try {
        await FirebaseFirestore.instance.collection('users').add(data);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } else {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('demo_users') ?? <String>[];
      list.add(jsonEncode(data));
      await prefs.setStringList('demo_users', list);
    }
  }

  Widget _buildUserList() {
    if (FirebaseService.initialized) {
      return FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance.collection('users').get(),
        builder: (context, snap) {
          if (!snap.hasData) return Center(child: BloodBridgeLoader());
          final docs = snap.data!.docs;
          if (docs.isEmpty) return Center(child: Padding(padding: EdgeInsets.all(32), child: Text('No users registered')));
          return ListView.builder(
            shrinkWrap: true,
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final d = docs[i];
              final data = d.data() as Map<String, dynamic>;
              return _userListTile(data, d.id, isFirebase: true);
            },
          );
        },
      );
    } else {
      return FutureBuilder<List<String>>(
        future: SharedPreferences.getInstance().then((p) => p.getStringList('demo_users') ?? <String>[]),
        builder: (context, snap) {
          if (!snap.hasData) return Center(child: BloodBridgeLoader());
          final list = snap.data!;
          if (list.isEmpty) return Center(child: Padding(padding: EdgeInsets.all(32), child: Text('No users registered')));
          return ListView.builder(
            shrinkWrap: true,
            itemCount: list.length,
            itemBuilder: (context, i) {
              try {
                final data = jsonDecode(list[i]) as Map<String, dynamic>;
                return _userListTile(data, i.toString(), isFirebase: false);
              } catch (_) {
                return SizedBox.shrink();
              }
            },
          );
        },
      );
    }
  }

  Widget _userListTile(Map<String, dynamic> data, String id, {required bool isFirebase}) {
    final role = data['role'] ?? 'user';
    final verified = data['verified'] ?? false;
    Color roleColor = role == 'donor' ? Colors.red : role == 'recipient' ? Colors.green : Colors.blue;
    
    return ListTile(
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            backgroundColor: roleColor.withOpacity(0.2),
            radius: 24,
            child: Icon(
              role == 'donor' ? Icons.bloodtype : role == 'recipient' ? Icons.local_hospital : Icons.person,
              color: roleColor,
            ),
          ),
          if (verified)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                padding: EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.verified,
                  color: Colors.blue,
                  size: 16,
                ),
              ),
            ),
        ],
      ),
      title: Text(data['name'] ?? 'Unknown', style: TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text('${data['email'] ?? 'N/A'} • ${data['bloodGroup'] ?? 'N/A'}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: roleColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(role.toUpperCase(), style: TextStyle(fontSize: 10, color: roleColor, fontWeight: FontWeight.bold)),
          ),
          SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.edit, color: Colors.blue, size: 20),
            tooltip: 'Edit User',
            onPressed: () => _showEditUserDialog(data, id, isFirebase),
          ),
          IconButton(
            icon: Icon(Icons.delete, color: Colors.red, size: 20),
            tooltip: 'Delete User',
            onPressed: () => _confirmDeleteUser(data, id, isFirebase),
          ),
        ],
      ),
      onTap: () {
        if (isFirebase) {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => UserProfileScreen(firebaseUid: id)));
        }
      },
    );
  }

  void _showEditUserDialog(Map<String, dynamic> data, String id, bool isFirebase) {
    final nameCtl = TextEditingController(text: data['name'] ?? '');
    final emailCtl = TextEditingController(text: data['email'] ?? '');
    final phoneCtl = TextEditingController(text: data['phone'] ?? '');
    String selectedRole = data['role'] ?? 'donor';
    String selectedBloodGroup = data['bloodGroup'] ?? 'A+';
    bool verified = data['verified'] ?? false;

    final bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
    final roles = ['donor', 'recipient', 'admin', 'super_admin'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white.withOpacity(0.85),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade300, width: 1.5),
          ),
          title: Row(
            children: [
              Icon(Icons.edit, color: Colors.blue),
              SizedBox(width: 8),
              Text('Edit User'),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtl,
                    decoration: InputDecoration(
                      labelText: 'Name',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  SizedBox(height: 12),
                  TextField(
                    controller: emailCtl,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  SizedBox(height: 12),
                  TextField(
                    controller: phoneCtl,
                    decoration: InputDecoration(
                      labelText: 'Phone',
                      prefixIcon: Icon(Icons.phone),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedRole,
                    decoration: InputDecoration(
                      labelText: 'Role',
                      prefixIcon: Icon(Icons.badge),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    items: roles.map((r) => DropdownMenuItem(value: r, child: Text(r.toUpperCase()))).toList(),
                    onChanged: (v) => setDialogState(() => selectedRole = v!),
                  ),
                  SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedBloodGroup,
                    decoration: InputDecoration(
                      labelText: 'Blood Group',
                      prefixIcon: Icon(Icons.bloodtype),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    items: bloodGroups.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                    onChanged: (v) => setDialogState(() => selectedBloodGroup = v!),
                  ),
                  SizedBox(height: 12),
                  SwitchListTile(
                    title: Text('Verified'),
                    subtitle: Text('Mark user as verified'),
                    secondary: Icon(Icons.verified, color: verified ? Colors.blue : Colors.grey),
                    value: verified,
                    onChanged: (v) => setDialogState(() => verified = v),
                  ),
                ],
              ),
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
              child: Text('Cancel'),
            ),
            OutlinedButton.icon(
              icon: Icon(Icons.save),
              label: Text('Save Changes'),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.black,
                side: BorderSide(color: Colors.black, width: 2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: () async {
                final updated = {
                  'name': nameCtl.text.trim(),
                  'email': emailCtl.text.trim(),
                  'phone': phoneCtl.text.trim(),
                  'role': selectedRole,
                  'bloodGroup': selectedBloodGroup,
                  'verified': verified,
                };
                await _updateUser(id, updated, isFirebase);
                if (mounted) {
                  Navigator.pop(context);
                  setState(() {
                    // Trigger rebuild to refresh user list
                  });
                  _loadStats();
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('User updated successfully'), backgroundColor: Colors.green));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateUser(String id, Map<String, dynamic> data, bool isFirebase) async {
    if (isFirebase && FirebaseService.initialized) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(id).update(data);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } else {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('demo_users') ?? <String>[];
      final idx = int.tryParse(id) ?? -1;
      if (idx >= 0 && idx < list.length) {
        try {
          final existing = jsonDecode(list[idx]) as Map<String, dynamic>;
          existing.addAll(data);
          list[idx] = jsonEncode(existing);
          await prefs.setStringList('demo_users', list);
        } catch (_) {}
      }
    }
  }

  void _confirmDeleteUser(Map<String, dynamic> data, String id, bool isFirebase) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white.withOpacity(0.85),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade300, width: 1.5),
        ),
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete User'),
          ],
        ),
        content: Text('Are you sure you want to delete "${data['name'] ?? 'this user'}"? This action cannot be undone.'),
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
            child: Text('Cancel'),
          ),
          OutlinedButton.icon(
            icon: Icon(Icons.delete),
            label: Text('Delete'),
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.red,
              side: BorderSide(color: Colors.red, width: 2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: () async {
              await _deleteUser(id, isFirebase);
              if (mounted) {
                Navigator.pop(context);
                setState(() {
                  // Trigger rebuild to refresh user list
                });
                _loadStats();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('User deleted'), backgroundColor: Colors.orange));
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _deleteUser(String id, bool isFirebase) async {
    if (isFirebase && FirebaseService.initialized) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(id).delete();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } else {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('demo_users') ?? <String>[];
      final idx = int.tryParse(id) ?? -1;
      if (idx >= 0 && idx < list.length) {
        list.removeAt(idx);
        await prefs.setStringList('demo_users', list);
      }
    }
  }

  // =====================================================================
  // M3: Donation History & Reminders
  // =====================================================================
  Widget _buildDonationHistoryModule() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _moduleHeader('Donation History & Reminders', Icons.history, Color(0xFF388E3C)),
          const SizedBox(height: 16),
          
          // Summary Cards
          Row(
            children: [
              Expanded(child: _miniStatCard('Total Donations', '47', Icons.favorite, Colors.red)),
              SizedBox(width: 12),
              Expanded(child: _miniStatCard('This Month', '12', Icons.calendar_month, Colors.blue)),
              SizedBox(width: 12),
              Expanded(child: _miniStatCard('Pending Reminders', '8', Icons.notifications_active, Colors.orange)),
            ],
          ),
          const SizedBox(height: 20),
          
          // Recent Donations
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Color(0xFF388E3C).withOpacity(0.1),
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.history, color: Color(0xFF388E3C)),
                      SizedBox(width: 8),
                      Text('Recent Donation Activity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF388E3C))),
                    ],
                  ),
                ),
                _donationHistoryList(),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Upcoming Reminders
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.notifications_active, color: Colors.orange),
                      SizedBox(width: 8),
                      Text('Upcoming Eligibility Reminders', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange[800])),
                    ],
                  ),
                ),
                _remindersList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _donationHistoryList() {
    final donations = [
      {'donor': 'Ahmad Khan', 'bloodGroup': 'A+', 'date': '2026-02-20', 'location': 'City Hospital'},
      {'donor': 'Sara Ali', 'bloodGroup': 'O-', 'date': '2026-02-18', 'location': 'Blood Bank Center'},
      {'donor': 'Usman Ahmed', 'bloodGroup': 'B+', 'date': '2026-02-15', 'location': 'Medical Complex'},
      {'donor': 'Fatima Noor', 'bloodGroup': 'AB+', 'date': '2026-02-12', 'location': 'Red Crescent'},
      {'donor': 'Hassan Raza', 'bloodGroup': 'O+', 'date': '2026-02-10', 'location': 'City Hospital'},
    ];
    
    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: donations.length,
      itemBuilder: (context, i) {
        final d = donations[i];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.red[50],
            child: Text(d['bloodGroup']!, style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          title: Text(d['donor']!, style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text('${d['location']} • ${d['date']}'),
          trailing: Icon(Icons.check_circle, color: Colors.green, size: 20),
        );
      },
    );
  }

  Widget _remindersList() {
    final reminders = [
      {'donor': 'Ali Hassan', 'eligibleDate': '2026-02-25', 'lastDonation': '2025-11-25'},
      {'donor': 'Maria Khan', 'eligibleDate': '2026-02-28', 'lastDonation': '2025-11-28'},
      {'donor': 'Zain Ahmed', 'eligibleDate': '2026-03-01', 'lastDonation': '2025-12-01'},
    ];
    
    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: reminders.length,
      itemBuilder: (context, i) {
        final r = reminders[i];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.orange[50],
            child: Icon(Icons.schedule, color: Colors.orange[700], size: 20),
          ),
          title: Text(r['donor']!, style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text('Eligible: ${r['eligibleDate']} • Last: ${r['lastDonation']}'),
          trailing: ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Reminder sent to ${r['donor']}')));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, padding: EdgeInsets.symmetric(horizontal: 12)),
            child: Text('Send Reminder', style: TextStyle(fontSize: 11, color: Colors.white)),
          ),
        );
      },
    );
  }

  // =====================================================================
  // M4: In-App Communication Module
  // =====================================================================
  Widget _buildCommunicationModule() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _moduleHeader('In-App Communication', Icons.chat, Color(0xFF7B1FA2)),
          const SizedBox(height: 16),
          
          // Stats Row
          Row(
            children: [
              Expanded(child: _miniStatCard('Active Chats', '23', Icons.chat_bubble, Colors.purple)),
              SizedBox(width: 12),
              Expanded(child: _miniStatCard('Messages Today', '156', Icons.message, Colors.blue)),
              SizedBox(width: 12),
              Expanded(child: _miniStatCard('Broadcasts', '5', Icons.campaign, Colors.orange)),
            ],
          ),
          const SizedBox(height: 20),
          
          // Broadcast Message Section
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.campaign, color: Color(0xFF7B1FA2)),
                      SizedBox(width: 8),
                      Text('Send Broadcast Message', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF7B1FA2))),
                    ],
                  ),
                  SizedBox(height: 16),
                  TextField(
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Type your broadcast message here...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            labelText: 'Target Audience',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          items: [
                            DropdownMenuItem(value: 'all', child: Text('All Users')),
                            DropdownMenuItem(value: 'donors', child: Text('Donors Only')),
                            DropdownMenuItem(value: 'recipients', child: Text('Recipients Only')),
                            DropdownMenuItem(value: 'hospitals', child: Text('Hospitals')),
                          ],
                          onChanged: (_) {},
                        ),
                      ),
                      SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Broadcast sent successfully!')));
                        },
                        icon: Icon(Icons.send),
                        label: Text('Send'),
                        style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF7B1FA2), foregroundColor: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Recent Messages
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Color(0xFF7B1FA2).withOpacity(0.1),
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.forum, color: Color(0xFF7B1FA2)),
                      SizedBox(width: 8),
                      Text('Recent Conversations', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF7B1FA2))),
                    ],
                  ),
                ),
                _recentConversationsList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _recentConversationsList() {
    final conversations = [
      {'from': 'Ahmad Khan', 'to': 'City Hospital', 'preview': 'I can donate tomorrow morning...', 'time': '10:30 AM'},
      {'from': 'Sara Ali', 'to': 'Blood Bank', 'preview': 'What documents are needed?', 'time': '09:45 AM'},
      {'from': 'Usman Ahmed', 'to': 'Medical Center', 'preview': 'Confirmed for 3 PM', 'time': 'Yesterday'},
    ];
    
    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: conversations.length,
      itemBuilder: (context, i) {
        final c = conversations[i];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.purple[50],
            child: Icon(Icons.person, color: Colors.purple[700], size: 20),
          ),
          title: Text('${c['from']} → ${c['to']}', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          subtitle: Text(c['preview']!, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: Text(c['time']!, style: TextStyle(fontSize: 11, color: Colors.grey)),
        );
      },
    );
  }

  // =====================================================================
  // M5: Gamification & Engagement Module
  // =====================================================================
  Widget _buildGamificationModule() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _moduleHeader('Gamification & Engagement', Icons.emoji_events, Color(0xFFD32F2F)),
          const SizedBox(height: 16),
          
          // Stats Row
          Row(
            children: [
              Expanded(child: _miniStatCard('Total Points Awarded', '15,420', Icons.stars, Colors.amber)),
              SizedBox(width: 12),
              Expanded(child: _miniStatCard('Badges Earned', '234', Icons.military_tech, Colors.blue)),
              SizedBox(width: 12),
              Expanded(child: _miniStatCard('Top Donors', '25', Icons.leaderboard, Colors.green)),
            ],
          ),
          const SizedBox(height: 20),
          
          // Leaderboard
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [Colors.amber[700]!, Colors.amber[500]!]),
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.leaderboard, color: Colors.white),
                      SizedBox(width: 8),
                      Text('Top Donors Leaderboard', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                ),
                _leaderboardList(),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Badges Section
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.military_tech, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('Available Badges', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _badgeChip('First Donation', Icons.favorite, Colors.red),
                      _badgeChip('5 Donations', Icons.star, Colors.amber),
                      _badgeChip('10 Donations', Icons.stars, Colors.orange),
                      _badgeChip('Life Saver', Icons.health_and_safety, Colors.green),
                      _badgeChip('Emergency Hero', Icons.emergency, Colors.red),
                      _badgeChip('Community Champion', Icons.groups, Colors.blue),
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

  Widget _leaderboardList() {
    final leaders = [
      {'rank': 1, 'name': 'Ahmad Khan', 'donations': 25, 'points': 2500},
      {'rank': 2, 'name': 'Sara Ali', 'donations': 22, 'points': 2200},
      {'rank': 3, 'name': 'Usman Ahmed', 'donations': 20, 'points': 2000},
      {'rank': 4, 'name': 'Fatima Noor', 'donations': 18, 'points': 1800},
      {'rank': 5, 'name': 'Hassan Raza', 'donations': 15, 'points': 1500},
    ];
    
    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: leaders.length,
      itemBuilder: (context, i) {
        final l = leaders[i];
        Color medalColor = l['rank'] == 1 ? Colors.amber : l['rank'] == 2 ? Colors.grey[400]! : l['rank'] == 3 ? Colors.brown[300]! : Colors.grey[300]!;
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: medalColor,
            child: Text('${l['rank']}', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          title: Text(l['name'] as String, style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text('${l['donations']} donations'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.stars, color: Colors.amber, size: 18),
              SizedBox(width: 4),
              Text('${l['points']} pts', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber[800])),
            ],
          ),
        );
      },
    );
  }

  Widget _badgeChip(String label, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
        ],
      ),
    );
  }

  // =====================================================================
  // M6: Donor Verification & Reputation System
  // =====================================================================
  Widget _buildVerificationModule() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _moduleHeader('Donor Verification & Reputation', Icons.verified_user, Color(0xFF1976D2)),
          const SizedBox(height: 16),
          
          // Stats Row
          Row(
            children: [
              Expanded(child: _miniStatCard('Verified Donors', '89', Icons.verified, Colors.green)),
              SizedBox(width: 12),
              Expanded(child: _miniStatCard('Pending Verification', '12', Icons.pending, Colors.orange)),
              SizedBox(width: 12),
              Expanded(child: _miniStatCard('Avg. Rating', '4.7', Icons.star, Colors.amber)),
            ],
          ),
          const SizedBox(height: 20),
          
          // Pending Verifications
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.pending_actions, color: Colors.orange),
                      SizedBox(width: 8),
                      Text('Pending Verifications', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange[800])),
                    ],
                  ),
                ),
                _pendingVerificationsList(),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Recently Verified
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.verified, color: Colors.green),
                      SizedBox(width: 8),
                      Text('Recently Verified Donors', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
                    ],
                  ),
                ),
                _verifiedDonorsList(),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // All Registered Donors
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.people, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('All Registered Donors', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue[800])),
                      Spacer(),
                      IconButton(
                        icon: Icon(Icons.refresh, color: Colors.blue),
                        onPressed: () => setState(() {}),
                      ),
                    ],
                  ),
                ),
                _allRegisteredDonorsList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _allRegisteredDonorsList() {
    if (FirebaseService.initialized) {
      return FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'donor')
            .get(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: BloodBridgeLoader()),
          );
          if (snap.hasError) return Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red),
                  SizedBox(height: 16),
                  Text('Error loading donors', style: TextStyle(fontSize: 16, color: Colors.red)),
                  SizedBox(height: 8),
                  Text('${snap.error}', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          );
          if (!snap.hasData) return Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: BloodBridgeLoader()),
          );
          final docs = snap.data!.docs;
          if (docs.isEmpty) return Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.people_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No donors registered yet', style: TextStyle(fontSize: 16, color: Colors.grey)),
                ],
              ),
            ),
          );
          return ConstrainedBox(
            constraints: BoxConstraints(maxHeight: 400),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: docs.length,
              itemBuilder: (context, i) {
                final data = docs[i].data() as Map<String, dynamic>;
                final verified = data['verified'] ?? false;
                final approved = data['approved'] ?? false;
                return ListTile(
                  leading: Stack(
                    children: [
                      CircleAvatar(
                        backgroundColor: verified ? Colors.green[50] : Colors.grey[200],
                        child: Text(
                          data['bloodGroup'] ?? 'N/A',
                          style: TextStyle(
                            color: verified ? Colors.green[800] : Colors.grey[800],
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      if (verified)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Icon(Icons.verified, color: Colors.blue, size: 14),
                        ),
                    ],
                  ),
                  title: Text(data['name'] ?? 'Unknown', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('${data['email'] ?? 'N/A'} • ${data['contact'] ?? 'No contact'}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: verified ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          verified ? 'VERIFIED' : 'PENDING',
                          style: TextStyle(
                            fontSize: 10,
                            color: verified ? Colors.green : Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      IconButton(
                        icon: Icon(Icons.visibility, color: Colors.blue, size: 20),
                        tooltip: 'View Details',
                        onPressed: () {
                          // Navigate to user profile or show details
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => UserProfileScreen(firebaseUid: docs[i].id),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      );
    } else {
      return FutureBuilder<List<Map<String, dynamic>>>(
        future: _getAllDemoDonors(),
        builder: (context, snap) {
          if (!snap.hasData) return Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: BloodBridgeLoader()),
          );
          final donors = snap.data!;
          if (donors.isEmpty) return Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.people_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No donors registered yet', style: TextStyle(fontSize: 16, color: Colors.grey)),
                ],
              ),
            ),
          );
          return ConstrainedBox(
            constraints: BoxConstraints(maxHeight: 400),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: donors.length,
              itemBuilder: (context, i) {
                final data = donors[i];
                final verified = data['verified'] ?? false;
                return ListTile(
                  leading: Stack(
                    children: [
                      CircleAvatar(
                        backgroundColor: verified ? Colors.green[50] : Colors.grey[200],
                        child: Text(
                          data['bloodGroup'] ?? 'N/A',
                          style: TextStyle(
                            color: verified ? Colors.green[800] : Colors.grey[800],
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      if (verified)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Icon(Icons.verified, color: Colors.blue, size: 14),
                        ),
                    ],
                  ),
                  title: Text(data['name'] ?? 'Unknown', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('${data['email'] ?? 'N/A'} • ${data['contact'] ?? 'No contact'}'),
                  trailing: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: verified ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      verified ? 'VERIFIED' : 'PENDING',
                      style: TextStyle(
                        fontSize: 10,
                        color: verified ? Colors.green : Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      );
    }
  }

  Future<List<Map<String, dynamic>>> _getAllDemoDonors() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('demo_users') ?? <String>[];
    List<Map<String, dynamic>> donors = [];
    
    for (final s in list) {
      try {
        final Map<String, dynamic> u = jsonDecode(s);
        if ((u['role'] ?? '') == 'donor') {
          donors.add(u);
        }
      } catch (_) {}
    }
    
    return donors;
  }

  Widget _pendingVerificationsList() {
    final pending = [
      {'name': 'Bilal Ahmed', 'bloodGroup': 'A+', 'submitted': '2026-02-22', 'documents': 'ID + Medical'},
      {'name': 'Ayesha Khan', 'bloodGroup': 'B-', 'submitted': '2026-02-21', 'documents': 'ID Only'},
      {'name': 'Imran Shah', 'bloodGroup': 'O+', 'submitted': '2026-02-20', 'documents': 'ID + Medical'},
    ];
    
    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: pending.length,
      itemBuilder: (context, i) {
        final p = pending[i];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.orange[50],
            child: Text(p['bloodGroup']!, style: TextStyle(color: Colors.orange[800], fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          title: Text(p['name']!, style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text('Submitted: ${p['submitted']} • ${p['documents']}'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(Icons.check_circle, color: Colors.green),
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${p['name']} verified!'))),
              ),
              IconButton(
                icon: Icon(Icons.cancel, color: Colors.red),
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Verification rejected'))),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _verifiedDonorsList() {
    final verified = [
      {'name': 'Ahmad Khan', 'bloodGroup': 'A+', 'rating': 4.9, 'donations': 25},
      {'name': 'Sara Ali', 'bloodGroup': 'O-', 'rating': 4.8, 'donations': 22},
      {'name': 'Usman Ahmed', 'bloodGroup': 'B+', 'rating': 4.7, 'donations': 20},
    ];
    
    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: verified.length,
      itemBuilder: (context, i) {
        final v = verified[i];
        return ListTile(
          leading: Stack(
            children: [
              CircleAvatar(
                backgroundColor: Colors.green[50],
                child: Text(v['bloodGroup'] as String, style: TextStyle(color: Colors.green[800], fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Icon(Icons.verified, color: Colors.blue, size: 14),
              ),
            ],
          ),
          title: Text(v['name'] as String, style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text('${v['donations']} donations'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.star, color: Colors.amber, size: 18),
              SizedBox(width: 4),
              Text('${v['rating']}', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        );
      },
    );
  }

  // =====================================================================
  // M7: Hospital / Blood Bank Request Management
  // =====================================================================
  Widget _buildHospitalBankModule() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _moduleHeader('Hospital/Blood Bank Management', Icons.local_hospital, Color(0xFF388E3C)),
          const SizedBox(height: 16),
          
          // Stats Row
          Row(
            children: [
              Expanded(child: _miniStatCard('Total Blood Banks', _bloodBanks.length.toString(), Icons.business, Colors.blue)),
              SizedBox(width: 12),
              Expanded(child: _miniStatCard('Total Units', _getTotalBloodUnits().toString(), Icons.bloodtype, Colors.red)),
            ],
          ),
          const SizedBox(height: 20),
          
          // Blood Banks List Card
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Color(0xFF388E3C).withOpacity(0.1),
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.local_hospital, color: Color(0xFF388E3C)),
                      SizedBox(width: 8),
                      Text('All Blood Banks & Hospitals', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF388E3C))),
                      Spacer(),
                      ElevatedButton.icon(
                        icon: Icon(Icons.add, size: 18),
                        label: Text('Add Blood Bank'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF388E3C),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onPressed: _addBloodBank,
                      ),
                      SizedBox(width: 8),
                      IconButton(
                        icon: Icon(Icons.refresh, color: Color(0xFF388E3C)),
                        onPressed: _loadBloodBanks,
                      ),
                    ],
                  ),
                ),
                if (_bloodBanks.isEmpty)
                  Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.local_hospital, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('No blood banks added yet', style: TextStyle(fontSize: 16, color: Colors.grey)),
                          SizedBox(height: 8),
                          Text('Click "Add Blood Bank" to get started', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: 500),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _bloodBanks.length,
                      itemBuilder: (context, i) => _buildBloodBankCard(_bloodBanks[i]),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _getTotalBloodUnits() {
    int total = 0;
    for (var bank in _bloodBanks) {
      final inventory = bank['inventory'] as Map<String, dynamic>? ?? {};
      for (var units in inventory.values) {
        total += (units as int? ?? 0);
      }
    }
    return total;
  }

  Widget _buildBloodBankCard(Map<String, dynamic> bank) {
    final inventory = bank['inventory'] as Map<String, dynamic>? ?? {};
    int totalUnits = 0;
    for (var units in inventory.values) {
      totalUnits += (units as int? ?? 0);
    }
    
    return Card(
      elevation: 2,
      margin: EdgeInsets.only(bottom: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: Color(0xFF388E3C).withOpacity(0.2),
          radius: 24,
          child: Icon(Icons.local_hospital, color: Color(0xFF388E3C), size: 24),
        ),
        title: Text(
          bank['name'] ?? 'Unknown',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          [
            if (bank['address'] != null && (bank['address'] as String).isNotEmpty)
              bank['address'],
            if (bank['phone'] != null && (bank['phone'] as String).isNotEmpty)
              bank['phone'],
          ].whereType<String>().join(' • '),
          style: TextStyle(fontSize: 13),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$totalUnits',
                style: TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(width: 4),
            IconButton(
              icon: Icon(Icons.edit, color: Colors.blue, size: 20),
              tooltip: 'Edit',
              padding: EdgeInsets.all(4),
              constraints: BoxConstraints(),
              onPressed: () => _editBloodBank(bank),
            ),
            IconButton(
              icon: Icon(Icons.delete, color: Colors.red, size: 20),
              tooltip: 'Delete',
              padding: EdgeInsets.all(4),
              constraints: BoxConstraints(),
              onPressed: () => _deleteBloodBank(bank),
            ),
          ],
        ),
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(top: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Contact Details
                if ((bank['supervisor'] != null && (bank['supervisor'] as String).isNotEmpty))
                  Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Icon(Icons.person, size: 16, color: Colors.grey[600]),
                        SizedBox(width: 8),
                        Text('Supervisor: ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey[800])),
                        Expanded(child: Text(bank['supervisor'] ?? '', style: TextStyle(fontSize: 13, color: Colors.grey[700]))),
                      ],
                    ),
                  ),
                
                // Inventory Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Blood Inventory', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
                    ElevatedButton.icon(
                      onPressed: () => _manageInventory(bank),
                      icon: Icon(Icons.inventory, size: 16),
                      label: Text('Manage Inventory'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF388E3C),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                
                // Inventory Grid
                GridView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    childAspectRatio: 1.3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: 8,
                  itemBuilder: (context, i) {
                    final types = ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'];
                    final type = types[i];
                    final units = inventory[type] as int? ?? 0;
                    Color statusColor = units > 20 ? Colors.green : units > 10 ? Colors.orange : Colors.red;
                    
                    return Container(
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: statusColor.withOpacity(0.4), width: 1.5),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(type, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: statusColor)),
                          SizedBox(height: 4),
                          Text('$units units', style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.w500)),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _hospitalRequestsList() {
    final requests = [
      {'hospital': 'City General Hospital', 'bloodGroup': 'O-', 'units': 5, 'urgency': 'Critical', 'posted': '2 hours ago'},
      {'hospital': 'Medical Center', 'bloodGroup': 'A+', 'units': 3, 'urgency': 'Normal', 'posted': '5 hours ago'},
      {'hospital': 'Red Crescent', 'bloodGroup': 'B+', 'units': 2, 'urgency': 'Normal', 'posted': '1 day ago'},
    ];
    
    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: requests.length,
      itemBuilder: (context, i) {
        final r = requests[i];
        bool isCritical = r['urgency'] == 'Critical';
        return Container(
          margin: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isCritical ? Colors.red[50] : Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isCritical ? Colors.red[200]! : Colors.grey[200]!),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(r['bloodGroup'] as String, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r['hospital'] as String, style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('${r['units']} units needed • ${r['posted']}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isCritical ? Colors.red : Colors.blue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(r['urgency'] as String, style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _bloodInventoryGrid() {
    final inventory = [
      {'type': 'A+', 'units': 45, 'status': 'Good'},
      {'type': 'A-', 'units': 12, 'status': 'Low'},
      {'type': 'B+', 'units': 38, 'status': 'Good'},
      {'type': 'B-', 'units': 8, 'status': 'Critical'},
      {'type': 'O+', 'units': 52, 'status': 'Good'},
      {'type': 'O-', 'units': 5, 'status': 'Critical'},
      {'type': 'AB+', 'units': 22, 'status': 'Good'},
      {'type': 'AB-', 'units': 10, 'status': 'Low'},
    ];
    
    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 1.2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: inventory.length,
      itemBuilder: (context, i) {
        final item = inventory[i];
        Color statusColor = item['status'] == 'Good' ? Colors.green : item['status'] == 'Low' ? Colors.orange : Colors.red;
        return Container(
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: statusColor.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(item['type'] as String, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: statusColor)),
              Text('${item['units']} units', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
              Text(item['status'] as String, style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.w600)),
            ],
          ),
        );
      },
    );
  }

  // =====================================================================
  // M8: Analytics & Reports Dashboard
  // =====================================================================
  Widget _buildAnalyticsModule() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _moduleHeader('Analytics & Reports', Icons.analytics, Color(0xFF7B1FA2)),
          const SizedBox(height: 16),
          
          // Summary Stats
          Row(
            children: [
              Expanded(child: _miniStatCard('Monthly Donations', '127', Icons.trending_up, Colors.green)),
              SizedBox(width: 12),
              Expanded(child: _miniStatCard('Success Rate', '94%', Icons.pie_chart, Colors.blue)),
              SizedBox(width: 12),
              Expanded(child: _miniStatCard('Avg Response', '2.3h', Icons.timer, Colors.orange)),
            ],
          ),
          const SizedBox(height: 20),
          
          // Blood Group Distribution
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.pie_chart, color: Color(0xFF7B1FA2)),
                      SizedBox(width: 8),
                      Text('Blood Group Distribution', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  SizedBox(height: 16),
                  _bloodGroupDistribution(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Monthly Trends
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.show_chart, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('Monthly Donation Trends', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  SizedBox(height: 16),
                  _monthlyTrendsChart(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Export Options
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Export Reports', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Exporting PDF...'))),
                        icon: Icon(Icons.picture_as_pdf),
                        label: Text('PDF Report'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Exporting Excel...'))),
                        icon: Icon(Icons.table_chart),
                        label: Text('Excel Export'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
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

  Widget _bloodGroupDistribution() {
    final groups = [
      {'type': 'O+', 'percent': 35, 'color': Colors.red},
      {'type': 'A+', 'percent': 25, 'color': Colors.blue},
      {'type': 'B+', 'percent': 20, 'color': Colors.green},
      {'type': 'AB+', 'percent': 8, 'color': Colors.purple},
      {'type': 'O-', 'percent': 5, 'color': Colors.orange},
      {'type': 'A-', 'percent': 4, 'color': Colors.teal},
      {'type': 'B-', 'percent': 2, 'color': Colors.pink},
      {'type': 'AB-', 'percent': 1, 'color': Colors.brown},
    ];
    
    return Column(
      children: groups.map((g) {
        return Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              SizedBox(width: 40, child: Text(g['type'] as String, style: TextStyle(fontWeight: FontWeight.bold))),
              SizedBox(width: 8),
              Expanded(
                child: LinearProgressIndicator(
                  value: (g['percent'] as int) / 100,
                  backgroundColor: (g['color'] as Color).withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation(g['color'] as Color),
                  minHeight: 16,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              SizedBox(width: 8),
              SizedBox(width: 40, child: Text('${g['percent']}%', textAlign: TextAlign.right)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _monthlyTrendsChart() {
    final months = ['Sep', 'Oct', 'Nov', 'Dec', 'Jan', 'Feb'];
    final values = [85, 92, 78, 95, 110, 127];
    int maxVal = values.reduce((a, b) => a > b ? a : b);
    
    return SizedBox(
      height: 120,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(months.length, (i) {
          double heightPercent = values[i] / maxVal;
          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('${values[i]}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Container(
                width: 32,
                height: 80 * heightPercent,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue[300]!, Colors.blue[600]!],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              SizedBox(height: 4),
              Text(months[i], style: TextStyle(fontSize: 10)),
            ],
          );
        }),
      ),
    );
  }

  // =====================================================================
  // M9: AI-Powered Matching & Prediction
  // =====================================================================
  Widget _buildAIMatchingModule() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _moduleHeader('AI Matching & Prediction', Icons.auto_awesome, Color(0xFFD32F2F)),
          const SizedBox(height: 16),
          
          // AI Stats
          Row(
            children: [
              Expanded(child: _miniStatCard('Match Accuracy', '96%', Icons.check_circle, Colors.green)),
              SizedBox(width: 12),
              Expanded(child: _miniStatCard('Predictions Made', '892', Icons.psychology, Colors.purple)),
              SizedBox(width: 12),
              Expanded(child: _miniStatCard('Avg Match Time', '4.2s', Icons.speed, Colors.blue)),
            ],
          ),
          const SizedBox(height: 20),
          
          // AI Matching Demo
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_awesome, color: Color(0xFFD32F2F)),
                      SizedBox(width: 8),
                      Text('Smart Donor Matching', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  SizedBox(height: 16),
                  Text('Enter blood group to find compatible donors:', style: TextStyle(color: Colors.grey[600])),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            labelText: 'Required Blood Group',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          items: ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-']
                              .map((bg) => DropdownMenuItem(value: bg, child: Text(bg)))
                              .toList(),
                          onChanged: (_) {},
                        ),
                      ),
                      SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Finding compatible donors...')));
                        },
                        icon: Icon(Icons.search),
                        label: Text('Find Matches'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFFD32F2F),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Demand Prediction
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.insights, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('Blood Demand Prediction', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  SizedBox(height: 16),
                  _demandPredictionList(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // AI Insights
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFD32F2F).withOpacity(0.1), Colors.white],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb, color: Colors.amber),
                      SizedBox(width: 8),
                      Text('AI Insights', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  SizedBox(height: 12),
                  _aiInsightTile(Icons.warning_amber, 'O- blood group demand expected to increase by 15% next week', Colors.orange),
                  _aiInsightTile(Icons.check_circle, '12 donors in area will become eligible within 7 days', Colors.green),
                  _aiInsightTile(Icons.trending_up, 'Emergency requests typically peak on weekends', Colors.blue),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _demandPredictionList() {
    final predictions = [
      {'type': 'O-', 'current': 5, 'predicted': 12, 'trend': 'up'},
      {'type': 'A+', 'current': 8, 'predicted': 10, 'trend': 'up'},
      {'type': 'B+', 'current': 6, 'predicted': 5, 'trend': 'down'},
      {'type': 'AB-', 'current': 3, 'predicted': 4, 'trend': 'up'},
    ];
    
    return Column(
      children: predictions.map((p) {
        bool isUp = p['trend'] == 'up';
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.red[50],
            child: Text(p['type'] as String, style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          title: Text('Current: ${p['current']} units', style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text('Predicted (7 days): ${p['predicted']} units'),
          trailing: Icon(
            isUp ? Icons.trending_up : Icons.trending_down,
            color: isUp ? Colors.red : Colors.green,
          ),
        );
      }).toList(),
    );
  }

  Widget _aiInsightTile(IconData icon, String text, Color color) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(width: 12),
          Expanded(child: Text(text, style: TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  // =====================================================================
  // Helper Widgets
  // =====================================================================
  Widget _moduleHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        IconButton(
          icon: Icon(Icons.arrow_back, color: Color(0xFFD32F2F)),
          onPressed: () => setState(() => _currentModule = 'overview'),
        ),
        Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        SizedBox(width: 12),
        Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF424242))),
      ],
    );
  }

  Widget _miniStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            SizedBox(height: 6),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            Text(title, style: TextStyle(fontSize: 10, color: Colors.grey[600]), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminProfile() {
    final nameCtl = TextEditingController();
    final contactCtl = TextEditingController();
    final emailCtl = TextEditingController();
    final currentPasswordCtl = TextEditingController();
    final newPasswordCtl = TextEditingController();
    final confirmPasswordCtl = TextEditingController();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Admin Profile', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF424242))),
              const SizedBox(height: 8),
              Text('Manage your administrator account and contact information', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
              const SizedBox(height: 24),
              
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.contact_page, color: Color(0xFFD32F2F)),
                          SizedBox(width: 12),
                          Text('Contact Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameCtl,
                    decoration: InputDecoration(
                      labelText: 'Name',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: contactCtl,
                    decoration: InputDecoration(
                      labelText: 'Contact Number',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      prefixIcon: Icon(Icons.phone),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFD32F2F),
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () async {
                        final name = nameCtl.text.trim();
                        final contact = contactCtl.text.trim();
                        
                        if (name.isEmpty || contact.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Please fill all fields'), backgroundColor: Colors.red),
                          );
                          return;
                        }
                        
                        showDialog(context: context, barrierDismissible: false, builder: (_) => Center(child: BloodBridgeLoader()));
                        
                        try {
                          if (FirebaseService.initialized) {
                            final user = FirebaseAuth.instance.currentUser;
                            if (user != null) {
                              await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
                                'name': name,
                                'contact': contact,
                              });
                            }
                          } else {
                            final prefs = await SharedPreferences.getInstance();
                            final currentEmail = prefs.getString('demo_current_email');
                            final list = prefs.getStringList('demo_users') ?? <String>[];
                            for (int i = 0; i < list.length; i++) {
                              try {
                                final Map<String, dynamic> u = jsonDecode(list[i]);
                                if ((u['email'] ?? '') == currentEmail) {
                                  u['name'] = name;
                                  u['contact'] = contact;
                                  list[i] = jsonEncode(u);
                                  await prefs.setStringList('demo_users', list);
                                  break;
                                }
                              } catch (_) {}
                            }
                          }
                          if (mounted) {
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Contact information updated successfully'), backgroundColor: Colors.green),
                            );
                            nameCtl.clear();
                            contactCtl.clear();
                          }
                        } catch (e) {
                          if (mounted) {
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
                      child: Text('Update Contact Info', style: TextStyle(fontSize: 16, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.email, color: Color(0xFFD32F2F)),
                      SizedBox(width: 12),
                      Text('Change Email', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailCtl,
                    decoration: InputDecoration(
                      labelText: 'New Email Address',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFD32F2F),
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () async {
                        final newEmail = emailCtl.text.trim();
                        if (newEmail.isEmpty || !newEmail.contains('@')) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Please enter a valid email'), backgroundColor: Colors.red),
                          );
                          return;
                        }
                        
                        showDialog(context: context, barrierDismissible: false, builder: (_) => Center(child: BloodBridgeLoader()));
                        
                        try {
                          if (FirebaseService.initialized) {
                            final user = FirebaseAuth.instance.currentUser;
                            if (user != null) {
                              await user.verifyBeforeUpdateEmail(newEmail);
                              await FirebaseFirestore.instance.collection('users').doc(user.uid).update({'email': newEmail});
                            }
                          } else {
                            final prefs = await SharedPreferences.getInstance();
                            final currentEmail = prefs.getString('demo_current_email');
                            final list = prefs.getStringList('demo_users') ?? <String>[];
                            for (int i = 0; i < list.length; i++) {
                              try {
                                final Map<String, dynamic> u = jsonDecode(list[i]);
                                if ((u['email'] ?? '') == currentEmail) {
                                  u['email'] = newEmail;
                                  list[i] = jsonEncode(u);
                                  await prefs.setStringList('demo_users', list);
                                  await prefs.setString('demo_current_email', newEmail);
                                  break;
                                }
                              } catch (_) {}
                            }
                          }
                          if (mounted) {
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Email updated successfully'), backgroundColor: Colors.green),
                            );
                            emailCtl.clear();
                          }
                        } catch (e) {
                          if (mounted) {
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
                      child: Text('Update Email', style: TextStyle(fontSize: 16, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lock, color: Color(0xFFD32F2F)),
                      SizedBox(width: 12),
                      Text('Change Password', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: currentPasswordCtl,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Current Password',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: newPasswordCtl,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      prefixIcon: Icon(Icons.lock_open),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmPasswordCtl,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Confirm New Password',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      prefixIcon: Icon(Icons.lock_open),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFD32F2F),
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () async {
                        final currentPass = currentPasswordCtl.text;
                        final newPass = newPasswordCtl.text;
                        final confirmPass = confirmPasswordCtl.text;
                        
                        if (currentPass.isEmpty || newPass.isEmpty || confirmPass.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Please fill all fields'), backgroundColor: Colors.red),
                          );
                          return;
                        }
                        
                        if (newPass != confirmPass) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('New passwords do not match'), backgroundColor: Colors.red),
                          );
                          return;
                        }
                        
                        if (newPass.length < 6) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Password must be at least 6 characters'), backgroundColor: Colors.red),
                          );
                          return;
                        }
                        
                        showDialog(context: context, barrierDismissible: false, builder: (_) => Center(child: BloodBridgeLoader()));
                        
                        try {
                          if (FirebaseService.initialized) {
                            final user = FirebaseAuth.instance.currentUser;
                            if (user != null) {
                              final cred = EmailAuthProvider.credential(email: user.email!, password: currentPass);
                              await user.reauthenticateWithCredential(cred);
                              await user.updatePassword(newPass);
                            }
                          } else {
                            final prefs = await SharedPreferences.getInstance();
                            final currentEmail = prefs.getString('demo_current_email');
                            final list = prefs.getStringList('demo_users') ?? <String>[];
                            bool found = false;
                            for (int i = 0; i < list.length; i++) {
                              try {
                                final Map<String, dynamic> u = jsonDecode(list[i]);
                                if ((u['email'] ?? '') == currentEmail) {
                                  if ((u['password'] ?? '') != currentPass) {
                                    throw Exception('Current password is incorrect');
                                  }
                                  u['password'] = newPass;
                                  list[i] = jsonEncode(u);
                                  found = true;
                                  break;
                                }
                              } catch (_) {}
                            }
                            if (found) {
                              await prefs.setStringList('demo_users', list);
                            } else {
                              throw Exception('Admin user not found');
                            }
                          }
                          if (mounted) {
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Password updated successfully'), backgroundColor: Colors.green),
                            );
                            currentPasswordCtl.clear();
                            newPasswordCtl.clear();
                            confirmPasswordCtl.clear();
                          }
                        } catch (e) {
                          if (mounted) {
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
                      child: Text('Change Password', style: TextStyle(fontSize: 16, color: Colors.white)),
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
    );
  }

  // =====================================================================
  // Blood Bank Management Functions
  // =====================================================================
  
  Future<void> _loadBloodBanks() async {
    if (FirebaseService.initialized) {
      try {
        final snap = await FirebaseFirestore.instance.collection('blood_banks').get();
        final banks = snap.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();
        if (mounted) {
          setState(() {
            _bloodBanks = banks;
          });
        }
      } catch (e) {
        print('Error loading blood banks: $e');
      }
    } else {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('demo_blood_banks') ?? <String>[];
      try {
        final banks = list.map((s) => jsonDecode(s) as Map<String, dynamic>).toList();
        if (mounted) {
          setState(() {
            _bloodBanks = banks;
          });
        }
      } catch (e) {
        print('Error loading demo blood banks: $e');
      }
    }
  }

  Future<void> _saveBloodBanks() async {
    if (FirebaseService.initialized) {
      // Firebase saves happen individually in add/edit/delete functions
      // This function is mainly for demo mode
    } else {
      final prefs = await SharedPreferences.getInstance();
      final list = _bloodBanks.map((b) => jsonEncode(b)).toList();
      await prefs.setStringList('demo_blood_banks', list);
    }
  }

  Future<void> _addBloodBank() async {
    final nameCtl = TextEditingController();
    final addressCtl = TextEditingController();
    final phoneCtl = TextEditingController();
    final supervisorCtl = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white.withOpacity(0.85),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade300, width: 1.5),
        ),
        title: Text('Add Blood Bank/Hospital'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtl,
                decoration: InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.local_hospital),
                ),
              ),
              SizedBox(height: 12),
              TextField(
                controller: addressCtl,
                decoration: InputDecoration(
                  labelText: 'Address',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                ),
              ),
              SizedBox(height: 12),
              TextField(
                controller: phoneCtl,
                decoration: InputDecoration(
                  labelText: 'Phone',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
              SizedBox(height: 12),
              TextField(
                controller: supervisorCtl,
                decoration: InputDecoration(
                  labelText: 'Supervisor Blood Bank',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
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
            child: Text('Cancel'),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.black,
              side: BorderSide(color: Colors.black, width: 2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: () async {
              final name = nameCtl.text.trim();
              final address = addressCtl.text.trim();
              final phone = phoneCtl.text.trim();
              final supervisor = supervisorCtl.text.trim();
              
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Please enter a name')),
                );
                return;
              }
              
              Navigator.pop(context);
              
              // Initialize default inventory for all blood groups
              final inventory = {
                'A+': 0, 'A-': 0, 'B+': 0, 'B-': 0,
                'O+': 0, 'O-': 0, 'AB+': 0, 'AB-': 0,
              };
              
              final newBank = {
                'name': name,
                'address': address,
                'phone': phone,
                'supervisor': supervisor,
                'inventory': inventory,
                'createdAt': DateTime.now().toIso8601String(),
              };
              
              try {
                if (FirebaseService.initialized) {
                  final doc = await FirebaseFirestore.instance.collection('blood_banks').add(newBank);
                  newBank['id'] = doc.id;
                } else {
                  newBank['id'] = DateTime.now().millisecondsSinceEpoch.toString();
                }
                
                setState(() {
                  _bloodBanks.add(newBank);
                });
                await _saveBloodBanks();
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Blood bank added successfully'), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error adding blood bank: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _editBloodBank(Map<String, dynamic> bank) async {
    final nameCtl = TextEditingController(text: bank['name']);
    final addressCtl = TextEditingController(text: bank['address'] ?? '');
    final phoneCtl = TextEditingController(text: bank['phone'] ?? '');
    final supervisorCtl = TextEditingController(text: bank['supervisor'] ?? '');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white.withOpacity(0.85),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade300, width: 1.5),
        ),
        title: Text('Edit Blood Bank/Hospital'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtl,
                decoration: InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.local_hospital),
                ),
              ),
              SizedBox(height: 12),
              TextField(
                controller: addressCtl,
                decoration: InputDecoration(
                  labelText: 'Address',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                ),
              ),
              SizedBox(height: 12),
              TextField(
                controller: phoneCtl,
                decoration: InputDecoration(
                  labelText: 'Phone',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
              SizedBox(height: 12),
              TextField(
                controller: supervisorCtl,
                decoration: InputDecoration(
                  labelText: 'Supervisor Blood Bank',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
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
            child: Text('Cancel'),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.black,
              side: BorderSide(color: Colors.black, width: 2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: () async {
              final name = nameCtl.text.trim();
              final address = addressCtl.text.trim();
              final phone = phoneCtl.text.trim();
              final supervisor = supervisorCtl.text.trim();
              
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Please enter a name')),
                );
                return;
              }
              
              Navigator.pop(context);
              
              try {
                bank['name'] = name;
                bank['address'] = address;
                bank['phone'] = phone;
                bank['supervisor'] = supervisor;
                
                if (FirebaseService.initialized) {
                  await FirebaseFirestore.instance.collection('blood_banks').doc(bank['id']).update({
                    'name': name,
                    'address': address,
                    'phone': phone,
                    'supervisor': supervisor,
                  });
                }
                
                setState(() {});
                await _saveBloodBanks();
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Blood bank updated successfully'), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error updating blood bank: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: Text('Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteBloodBank(Map<String, dynamic> bank) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white.withOpacity(0.85),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade300, width: 1.5),
        ),
        title: Text('Delete Blood Bank'),
        content: Text('Are you sure you want to delete "${bank['name']}"?'),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.black,
              side: BorderSide(color: Colors.black, width: 2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: Text('Cancel'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, true),
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.red,
              side: BorderSide(color: Colors.red, width: 2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        if (FirebaseService.initialized) {
          await FirebaseFirestore.instance.collection('blood_banks').doc(bank['id']).delete();
        }
        
        setState(() {
          _bloodBanks.remove(bank);
        });
        await _saveBloodBanks();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Blood bank deleted successfully'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting blood bank: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _manageInventory(Map<String, dynamic> bank) async {
    final inventory = Map<String, dynamic>.from(bank['inventory'] ?? {
      'A+': 0, 'A-': 0, 'B+': 0, 'B-': 0,
      'O+': 0, 'O-': 0, 'AB+': 0, 'AB-': 0,
    });
    
    final controllers = <String, TextEditingController>{};
    for (var type in inventory.keys) {
      controllers[type] = TextEditingController(text: (inventory[type] ?? 0).toString());
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white.withOpacity(0.85),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade300, width: 1.5),
        ),
        title: Text('Manage Blood Inventory'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(bank['name'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              SizedBox(height: 16),
              ...['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'].map((type) {
                return Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: TextField(
                    controller: controllers[type],
                    decoration: InputDecoration(
                      labelText: '$type (units)',
                      border: OutlineInputBorder(),
                      prefixIcon: Container(
                        width: 40,
                        alignment: Alignment.center,
                        child: Text(type, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                );
              }).toList(),
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
            child: Text('Cancel'),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.black,
              side: BorderSide(color: Colors.black, width: 2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: () async {
              Navigator.pop(context);
              
              try {
                final newInventory = <String, dynamic>{};
                for (var type in controllers.keys) {
                  newInventory[type] = int.tryParse(controllers[type]!.text) ?? 0;
                }
                
                bank['inventory'] = newInventory;
                
                if (FirebaseService.initialized) {
                  await FirebaseFirestore.instance.collection('blood_banks').doc(bank['id']).update({
                    'inventory': newInventory,
                  });
                }
                
                setState(() {});
                await _saveBloodBanks();
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Inventory updated successfully'), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error updating inventory: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: Text('Save'),
          ),
        ],
      ),
    );
  }
}
