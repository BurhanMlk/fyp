import 'package:flutter/material.dart';
import '../dashboard/dashboard_screen.dart';
import '../dashboard/overview_screen.dart';
import '../dashboard/pending_requests_screen.dart';
import '../profile/profile_screen.dart';
import '../admin/admin_dashboard.dart';
import '../admin/blood_bank_admin_dashboard.dart';
import '../admin/university_admin_dashboard.dart';
import '../admin/society_admin_dashboard.dart';
import '../donors/donor_list_screen.dart';
import '../recipients/recipient_list_screen.dart';
import '../auth/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/firebase_service.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;
  bool _isSuperAdmin = false;
  String? _currentRole;
  String? _currentEmail;
  bool _pendingBadge = false;
  bool _badgeCheckScheduled = false;

  List<Widget> get _tabs {
    if (_currentRole == 'donor') {
      // Donors can only see Dashboard, Donors, and Profile (no Recipients)
      return [DashboardScreen(), DonorListScreen(), ProfileScreen()];
    }
    // Recipients and others see all tabs
    return [DashboardScreen(), DonorListScreen(), RecipientListScreen(), ProfileScreen()];
  }

  @override
  void initState() {
    super.initState();
    _ensureDemoSuperAdmin();
    _determineRole();
  }

  Future<void> _checkPendingBadge() async {
    final prefs = await SharedPreferences.getInstance();
    final email = _currentEmail;
    if (email == null) return;
    
    bool hasUpdates = false;
    
    if (FirebaseService.initialized) {
      try {
        final snap = await FirebaseFirestore.instance.collection('donor_requests').get();
        final lastSeen = prefs.getString('last_seen_requests_$email') ?? '';
        for (final doc in snap.docs) {
          final data = doc.data();
          if ((data['recipientEmail'] == email || data['requesterEmail'] == email || data['donorEmail'] == email) &&
              data['status'] != 'pending') {
            final updatedAt = (data['updatedAt'] ?? data['requestedAt'] ?? '').toString();
            if (updatedAt.compareTo(lastSeen) > 0) {
              hasUpdates = true;
              break;
            }
          }
        }
      } catch (_) {}
    } else {
      final raw = prefs.getStringList('donor_requests') ?? [];
      final lastSeen = prefs.getString('last_seen_requests_$email') ?? '';
      for (final s in raw) {
        try {
          final r = jsonDecode(s) as Map<String, dynamic>;
          if ((r['recipientEmail'] == email || r['requesterEmail'] == email || r['donorEmail'] == email) &&
              r['status'] != 'pending') {
            final updatedAt = (r['updatedAt'] ?? r['requestedAt'] ?? '').toString();
            if (updatedAt.compareTo(lastSeen) > 0) {
              hasUpdates = true;
              break;
            }
          }
        } catch (_) {}
      }
    }
    if (_pendingBadge != hasUpdates) {
      setState(() => _pendingBadge = hasUpdates);
    }
  }
  // Re-check when returning to the app (e.g. after closing PendingRequests)
  void _refreshBadge() {
    _badgeCheckScheduled = false;
    _checkPendingBadge();
  }

  // Navigate to appropriate admin dashboard based on role
  void _checkAndNavigateToAdmin() {
    final role = _currentRole;
    Widget? target;
    if (role == 'super_admin' || role == 'admin') {
      target = const AdminDashboard();
    } else if (role == 'blood_bank_admin') {
      target = const BloodBankAdminDashboard();
    } else if (role == 'university_admin') {
      target = const UniversityAdminDashboard();
    } else if (role == 'society_admin') {
      target = const SocietyAdminDashboard();
    }

    if (target != null) {
      Future.microtask(() {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => target!),
        );
      });
    }
  }

  Future<void> _ensureDemoSuperAdmin() async {
    // Seed a demo super-admin account if not already present (demo only)
    if (FirebaseService.initialized) return;
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('demo_users') ?? <String>[];
    var found = false;
    for (var i = 0; i < list.length; i++) {
      try {
        final Map<String, dynamic> u = jsonDecode(list[i]);
        if ((u['email'] ?? '') == 'superadmin@bloodbridge.app') {
          u['password'] = 'SuperAdmin@123';
          list[i] = jsonEncode(u);
          found = true;
          break;
        }
      } catch (_) {
      }
    }
    if (!found) {
      final superAdmin = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'name': 'Super Admin',
        'email': 'superadmin@bloodbridge.app',
        'password': 'SuperAdmin@123',
        'contact': '',
        'bloodGroup': '',
        'role': 'super_admin',
        'location': '',
        'photoData': '',
        'createdAt': DateTime.now().toIso8601String(),
        'approved': true,
      };
      list.insert(0, jsonEncode(superAdmin));
      await prefs.setStringList('demo_users', list);
    }
  }

  Future<void> _determineRole() async {
    if (FirebaseService.initialized) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return setState(() => _isSuperAdmin = false);
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        var role = doc.data()?['role'] ?? '';
        // If the signed-in user email matches the hardcoded superadmin, force the role.
        if ((user.email ?? '') == 'superadmin@bloodbridge.app') {
          role = 'super_admin';
          try {
            if (doc.exists) {
              await FirebaseFirestore.instance.collection('users').doc(user.uid).update({'role': 'super_admin', 'approved': true});
            } else {
              await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
                'name': 'Super Admin',
                'email': user.email,
                'contact': '+92-300-1234567',
                'bloodGroup': 'O+',
                'role': 'super_admin',
                'location': 'Islamabad, Pakistan',
                'createdAt': FieldValue.serverTimestamp(),
                'approved': true,
                'isDonor': false,
              });
            }
          } catch (_) {}
        }

        setState(() {
          _currentRole = role;
          _currentEmail = user.email;
          _isSuperAdmin = (role == 'super_admin' || role == 'admin');
        });
        // Redirect any admin role to their dashboard
        if (role == 'super_admin' || role == 'admin' || role == 'blood_bank_admin' ||
            role == 'university_admin' || role == 'society_admin') {
          _checkAndNavigateToAdmin();
        }
        _checkPendingBadge();
      } catch (_) {
        setState(() {
          _currentRole = null;
          _isSuperAdmin = false;
        });
      }
    } else {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('demo_current_email');
      if (email == null) return setState(() => _isSuperAdmin = false);
      final list = prefs.getStringList('demo_users') ?? <String>[];
      for (final s in list) {
        try {
          final Map<String, dynamic> u = jsonDecode(s);
          if ((u['email'] ?? '') == email) {
            final role = (u['role'] ?? '').toString();
            final isSuperAdmin = role == 'super_admin';
            setState(() {
              _currentRole = role;
              _currentEmail = email;
              _isSuperAdmin = isSuperAdmin;
            });
            if (isSuperAdmin) _checkAndNavigateToAdmin();
            _checkPendingBadge();
            return;
          }
        } catch (_) {}
      }
      setState(() => _isSuperAdmin = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check badge once per drawer open via post-frame callback (debounced)
    if (!_badgeCheckScheduled) {
      _badgeCheckScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _badgeCheckScheduled = false;
        if (mounted) _checkPendingBadge();
      });
    }
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.menu, color: Colors.white),
                if (_pendingBadge)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () {
              _checkPendingBadge();
              Scaffold.of(ctx).openDrawer();
            },
          ),
        ),
        title: Text(
          'Blood Bridge',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFD84343), Color(0xFFEF5350), Color(0xFFFF8A80)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      drawer: Drawer(
        backgroundColor: Colors.white.withOpacity(0.95),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFD84343).withOpacity(0.9), Color(0xFFEF5350).withOpacity(0.9), Color(0xFFFF8A80).withOpacity(0.9)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        'assets/images/blood_bridge_logo.png',
                        width: 48,
                        height: 48,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stack) => Icon(Icons.bloodtype, size: 48, color: Theme.of(context).primaryColor),
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text('Blood Bridge', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            ListTile(
              leading: Icon(Icons.dashboard),
              title: Text('Dashboard'),
              onTap: () {
                Navigator.of(context).pop();
                setState(() => _index = 0);
              },
            ),
            ListTile(
              leading: Icon(Icons.pending_actions, color: Color(0xFFFFB74D)),
              title: Text('Pending Requests'),
              trailing: _pendingBadge
                  ? Container(
                      width: 10, height: 10,
                      decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
                    )
                  : null,
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => PendingRequestsScreen()),
                ).then((_) => _refreshBadge());
                setState(() => _pendingBadge = false);
              },
            ),
            ListTile(
              leading: Icon(Icons.people),
              title: Text('Donors'),
              onTap: () {
                Navigator.of(context).pop();
                setState(() => _index = 1);
              },
            ),
            ListTile(
              leading: Icon(Icons.person),
              title: Text('Profile'),
              onTap: () {
                Navigator.of(context).pop();
                // For donors: index 2, for others: index 3
                setState(() => _index = _currentRole == 'donor' ? 2 : 3);
              },
            ),
            Divider(),
            ListTile(
              leading: Icon(Icons.support_agent, color: Color(0xFFD32F2F)),
              title: Text('Contact Admin', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.of(context).pop();
                _showAdminContact();
              },
            ),
            Divider(),
            ListTile(
              leading: Icon(Icons.exit_to_app),
              title: Text('Logout'),
              onTap: () async {
                Navigator.of(context).pop();
                if (FirebaseService.initialized) {
                  await FirebaseAuth.instance.signOut();
                }
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('demo_logged_in', false);
                await prefs.remove('demo_current_email');
                Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => LoginScreen()));
              },
            ),
          ],
        ),
      ),
      body: _tabs[_index],
      ),
    );
  }

  void _showAdminContact() async {
    String adminName = 'Super Admin';
    String adminEmail = 'superadmin@bloodbridge.app';
    String adminContact = '+92-300-1234567';

    try {
      if (FirebaseService.initialized) {
        final snapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'super_admin')
            .limit(1)
            .get();
        
        if (snapshot.docs.isNotEmpty) {
          final data = snapshot.docs.first.data();
          adminName = data['name'] ?? adminName;
          adminEmail = data['email'] ?? adminEmail;
          adminContact = data['contact'] ?? adminContact;
        }
      } else {
        final prefs = await SharedPreferences.getInstance();
        final list = prefs.getStringList('demo_users') ?? <String>[];
        for (final s in list) {
          try {
            final Map<String, dynamic> u = jsonDecode(s);
            if ((u['role'] ?? '') == 'super_admin') {
              adminName = u['name'] ?? adminName;
              adminEmail = u['email'] ?? adminEmail;
              adminContact = u['contact'] ?? adminContact;
              break;
            }
          } catch (_) {}
        }
      }
    } catch (e) {
      print('Error fetching admin contact: $e');
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.85),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Color(0xFFD32F2F),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)],
                ),
                child: Icon(Icons.admin_panel_settings, color: Colors.white, size: 32),
              ),
              SizedBox(height: 16),
              Text('Admin Contact', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black)),
              SizedBox(height: 24),
              // Name Field
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.person, color: Color(0xFFD32F2F), size: 24),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Name', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                          SizedBox(height: 2),
                          Text(adminName, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 16)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12),
              // Email Field
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.email, color: Color(0xFFD32F2F), size: 24),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Email', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                          SizedBox(height: 2),
                          Text(adminEmail, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 16)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12),
              // Contact Field
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.phone, color: Color(0xFFD32F2F), size: 24),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Contact', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                          SizedBox(height: 2),
                          Text(adminContact, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 16)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.black,
                    side: BorderSide(color: Colors.black, width: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text('Close', style: TextStyle(fontSize: 16, color: Colors.black, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
