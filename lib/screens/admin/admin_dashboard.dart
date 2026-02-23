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
      default:
        return 'Admin Dashboard';
    }
  }

  Drawer _buildDrawer() {
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
                    // M7: Hospital / Blood Bank Request Management
                    ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      leading: Icon(Icons.local_hospital, size: 20, color: _currentModule == 'hospital_bank' ? Color(0xFFD32F2F) : Colors.grey),
                      title: Text('Hospital/Blood Bank Requests', style: TextStyle(fontSize: 14, fontWeight: _currentModule == 'hospital_bank' ? FontWeight.bold : FontWeight.normal)),
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
                    // M9: AI-Powered Matching & Prediction (Future Module)
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
                    // New Module
                    ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      leading: Icon(Icons.new_releases, size: 20, color: _currentModule == 'new_module' ? Color(0xFFD32F2F) : Colors.grey),
                      title: Text('New Module', style: TextStyle(fontSize: 14, fontWeight: _currentModule == 'new_module' ? FontWeight.bold : FontWeight.normal)),
                      selected: _currentModule == 'new_module',
                      onTap: () {
                        setState(() => _currentModule = 'new_module');
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
        return _buildModulePage('User Registration & Profile', Center(child: Text('User Registration & Profile Management (M1)\n\nImplementation coming soon.', textAlign: TextAlign.center)));
      case 'donation_history':
        return _buildModulePage('Donation History & Reminders', Center(child: Text('Donation History & Reminders (M3)\n\nImplementation coming soon.', textAlign: TextAlign.center)));
      case 'communication':
        return _buildModulePage('In-App Communication', Center(child: Text('In-App Communication Module (M4)\n\nImplementation coming soon.', textAlign: TextAlign.center)));
      case 'gamification':
        return _buildModulePage('Gamification & Engagement', Center(child: Text('Gamification & Engagement Module (M5)\n\nImplementation coming soon.', textAlign: TextAlign.center)));
      case 'verification':
        return _buildModulePage('Donor Verification & Reputation', Center(child: Text('Donor Verification & Reputation System (M6)\n\nImplementation coming soon.', textAlign: TextAlign.center)));
      case 'hospital_bank':
        return _buildModulePage('Hospital/Blood Bank Requests', Center(child: Text('Hospital / Blood Bank Request Management (M7)\n\nImplementation coming soon.', textAlign: TextAlign.center)));
      case 'analytics':
        return _buildModulePage('Analytics & Reports', Center(child: Text('Analytics & Reports Dashboard (M8)\n\nImplementation coming soon.', textAlign: TextAlign.center)));
      case 'ai_matching':
        return _buildModulePage('AI Matching & Prediction', Center(child: Text('AI-Powered Matching & Prediction (M9)\n\nImplementation coming soon.', textAlign: TextAlign.center)));
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
          
          Text('Quick Access', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF424242))),
          const SizedBox(height: 10),
          
          GridView.count(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.8,
            children: [
              _quickAccessCard('User Registration & Profile', Icons.person_add, Color(0xFF1976D2), () {
                setState(() => _currentModule = 'user_profile');
              }),
              _quickAccessCard('Emergency Requests', Icons.emergency, Color(0xFFFF6F00), () {
                setState(() => _currentModule = 'emergency');
              }),
              _quickAccessCard('Donation History', Icons.history, Color(0xFF388E3C), () {
                setState(() => _currentModule = 'donation_history');
              }),
              _quickAccessCard('In-App Communication', Icons.chat, Color(0xFF7B1FA2), () {
                setState(() => _currentModule = 'communication');
              }),
              _quickAccessCard('Gamification', Icons.emoji_events, Color(0xFFD32F2F), () {
                setState(() => _currentModule = 'gamification');
              }),
              _quickAccessCard('Verification', Icons.verified_user, Color(0xFF1976D2), () {
                setState(() => _currentModule = 'verification');
              }),
              _quickAccessCard('Hospital/Blood Bank', Icons.local_hospital, Color(0xFF388E3C), () {
                setState(() => _currentModule = 'hospital_bank');
              }),
              _quickAccessCard('Analytics', Icons.analytics, Color(0xFF7B1FA2), () {
                setState(() => _currentModule = 'analytics');
              }),
              _quickAccessCard('AI Matching', Icons.auto_awesome, Color(0xFFD32F2F), () {
                setState(() => _currentModule = 'ai_matching');
              }),
            ],
          ),
          const SizedBox(height: 24),
          Text('Modules', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF424242))),
          const SizedBox(height: 10),
          Card(
            color: Colors.white.withOpacity(0.95),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _moduleTile('M1: User Registration & Profile Management', 'Handles donor and recipient registration, profile updates, and verification.'),
                  _moduleTile('M2: Emergency Alert & Request Module', 'Enables urgent blood requests and instant notifications to nearby donors.'),
                  _moduleTile('M3: Donation History & Reminders', 'Maintains donor activity records and sends eligibility reminders.'),
                  _moduleTile('M4: In-App Communication Module', 'Supports secure messaging and optional calling between users.'),
                  _moduleTile('M5: Gamification & Engagement Module', 'Encourages regular donations through rewards, badges, and points.'),
                  _moduleTile('M6: Donor Verification & Reputation System', 'Ensures trust through verification badges and donor ratings.'),
                  _moduleTile('M7: Hospital / Blood Bank Request Management', 'Allows hospitals to post requests and manage blood availability.'),
                  _moduleTile('M8: Analytics & Reports Dashboard', 'Provides insights into donation trends and system performance.'),
                  _moduleTile('M9: AI-Powered Matching & Prediction (Future Module)', 'Enhances donor matching and predicts blood demand patterns.'),
                ],
              ),
            ),
          ),
        ],
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

  Widget _quickAccessCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          print('Quick access card tapped: $title');
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withOpacity(0.8), color],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                        ),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 32),
                SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(title, style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Superadmin manager -----------------------------------------------
  void _openSuperadminManager() {
    showDialog(context: context, builder: (_) {
      return AlertDialog(
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
        title: Text(index == null ? 'Add contact' : 'Edit contact'),
        content: TextField(controller: controller, decoration: InputDecoration(labelText: 'Phone number')),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text('Cancel')), TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text('Save'))],
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
        title: Text(index == null ? 'Add contact' : 'Edit contact'),
        content: TextField(controller: controller, decoration: InputDecoration(labelText: 'Phone number')),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text('Cancel')), TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text('Save'))],
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
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red[200]!, width: 1),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.bloodtype, color: Colors.red[700], size: 24),
                                SizedBox(width: 8),
                                Text('Blood Group: ${rd['bloodGroup'] ?? 'N/A'}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.red[800])),
                              ],
                            ),
                          ),
                          SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.phone, size: 16, color: Colors.blue[700]),
                              SizedBox(width: 6),
                              Expanded(child: Text('${rd['requesterPhone'] ?? 'N/A'}', style: TextStyle(fontSize: 14, color: Colors.blue[800]))),
                            ],
                          ),
                          if (rd['location'] != null && rd['location'].toString().isNotEmpty) ...[
                            SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.location_on, size: 16, color: Colors.green[700]),
                                SizedBox(width: 6),
                                Expanded(child: Text('${rd['location'] ?? 'N/A'}', style: TextStyle(color: Colors.green[800], fontSize: 13))),
                              ],
                            ),
                          ],
                          SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.info_outline, size: 16, color: (rd['status'] ?? 'new') == 'handled' ? Colors.green[700] : Colors.blue[700]),
                              SizedBox(width: 6),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (rd['status'] ?? 'new') == 'handled' ? Colors.green[100] : Colors.blue[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text('Status: ${rd['status'] ?? 'new'}', style: TextStyle(fontSize: 12, color: (rd['status'] ?? 'new') == 'handled' ? Colors.green[800] : Colors.blue[800], fontWeight: FontWeight.w600)),
                              ),
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
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red[200]!, width: 1),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.bloodtype, color: Colors.red[700], size: 24),
                                SizedBox(width: 8),
                                Text('Blood Group: ${r['bloodGroup'] ?? 'N/A'}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.red[800])),
                              ],
                            ),
                          ),
                          SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.phone, size: 16, color: Colors.blue[700]),
                              SizedBox(width: 6),
                              Expanded(child: Text('${r['requesterPhone'] ?? 'N/A'}', style: TextStyle(fontSize: 14, color: Colors.blue[800]))),
                            ],
                          ),
                          if (r['location'] != null && r['location'].toString().isNotEmpty) ...[
                            SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.location_on, size: 16, color: Colors.green[700]),
                                SizedBox(width: 6),
                                Expanded(child: Text('${r['location'] ?? 'N/A'}', style: TextStyle(color: Colors.green[800], fontSize: 13))),
                              ],
                            ),
                          ],
                          SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.info_outline, size: 16, color: (r['status'] ?? 'new') == 'handled' ? Colors.green[700] : Colors.blue[700]),
                              SizedBox(width: 6),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (r['status'] ?? 'new') == 'handled' ? Colors.green[100] : Colors.blue[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text('Status: ${r['status'] ?? 'new'}', style: TextStyle(fontSize: 12, color: (r['status'] ?? 'new') == 'handled' ? Colors.green[800] : Colors.blue[800], fontWeight: FontWeight.w600)),
                              ),
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

  Widget _buildAdminProfile() {
    final _nameCtl = TextEditingController();
    final _contactCtl = TextEditingController();
    final _emailCtl = TextEditingController();
    final _currentPasswordCtl = TextEditingController();
    final _newPasswordCtl = TextEditingController();
    final _confirmPasswordCtl = TextEditingController();

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
                    controller: _nameCtl,
                    decoration: InputDecoration(
                      labelText: 'Name',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _contactCtl,
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
                        final name = _nameCtl.text.trim();
                        final contact = _contactCtl.text.trim();
                        
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
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Contact information updated successfully'), backgroundColor: Colors.green),
                          );
                          _nameCtl.clear();
                          _contactCtl.clear();
                        } catch (e) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                          );
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
                    controller: _emailCtl,
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
                        final newEmail = _emailCtl.text.trim();
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
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Email updated successfully'), backgroundColor: Colors.green),
                          );
                          _emailCtl.clear();
                        } catch (e) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                          );
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
                    controller: _currentPasswordCtl,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Current Password',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _newPasswordCtl,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      prefixIcon: Icon(Icons.lock_open),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _confirmPasswordCtl,
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
                        final currentPass = _currentPasswordCtl.text;
                        final newPass = _newPasswordCtl.text;
                        final confirmPass = _confirmPasswordCtl.text;
                        
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
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Password updated successfully'), backgroundColor: Colors.green),
                          );
                          _currentPasswordCtl.clear();
                          _newPasswordCtl.clear();
                          _confirmPasswordCtl.clear();
                        } catch (e) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                          );
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

  Widget _moduleTile(String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black)),
          SizedBox(height: 2),
          Text(description, style: TextStyle(fontSize: 13, color: Colors.black87)),
        ],
      ),
    );
  }
}
