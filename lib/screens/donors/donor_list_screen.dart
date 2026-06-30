import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/firebase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../widgets/blood_bridge_loader.dart';
import '../../widgets/top_snackbar.dart';
import 'donor_detail_screen.dart';


class DonorListScreen extends StatefulWidget {
  const DonorListScreen({super.key});

  @override
  _DonorListScreenState createState() => _DonorListScreenState();
}

class _DonorListScreenState extends State<DonorListScreen> {
  String? _currentEmail;
  String? _currentRole;
  String? _currentPhone;
  String _searchQuery = '';
  String? _filterBloodType;
  String? _filterLocation;
  bool _filterApprovedOnly = false;
  String _sortBy = 'blood'; // 'blood', 'location', 'recent'
  bool _hasApprovedDonorAccess = false;
  bool _isRequestingAccess = false;
  Set<String> _approvedDonorEmails = {}; // Per-donor approved emails
  int _reloadCounter = 0; // Increment to force FutureBuilder refresh

  @override
  void initState() {
    super.initState();
    _loadCurrentUser().then((_) => _checkApprovedAccess());
  }

  Future<void> _loadCurrentUser() async {
    if (FirebaseService.initialized) {
      final u = FirebaseAuth.instance.currentUser;
      setState(() { _currentEmail = u?.email; });
      if (u != null) {
        try {
          final snap = await FirebaseFirestore.instance.collection('users').doc(u.uid).get();
          if (snap.exists) {
            final data = snap.data();
            setState(() {
              _currentRole = data?['role']?.toString();
              _currentPhone = data?['contact']?.toString() ?? data?['phone']?.toString();
            });
          }
        } catch (_) {}
        _checkExpiredCooldowns();
      }
    } else {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _currentEmail = prefs.getString('demo_current_email');
        final users = prefs.getStringList('demo_users') ?? <String>[];
        try {
          final me = users.map((s) => jsonDecode(s) as Map<String, dynamic>).firstWhere((u) => (u['email'] ?? '') == (_currentEmail ?? ''), orElse: () => <String, dynamic>{});
          _currentRole = me['role']?.toString();
          _currentPhone = me['contact']?.toString() ?? me['phone']?.toString();
        } catch (_) { _currentRole = null; _currentPhone = null; }
      });
      _checkExpiredCooldowns();
    }
  }

  Future<void> _checkExpiredCooldowns() async {
    final now = DateTime.now();
    if (FirebaseService.initialized) {
      try {
        final donorsSnap = await FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'donor')
            .get();
        for (final doc in donorsSnap.docs) {
          final data = doc.data();
          final cooldownStr = data['cooldownUntil']?.toString();
          if (cooldownStr != null && cooldownStr.isNotEmpty) {
            try {
              final cooldownDate = DateTime.parse(cooldownStr);
              if (cooldownDate.isBefore(now)) {
                // Cooldown expired - clear it
                await doc.reference.update({'cooldownUntil': FieldValue.delete()});
                final donorEmail = data['email'] ?? '';
                final donorName = data['name'] ?? 'Donor';
                if (donorEmail.isNotEmpty && _currentRole == 'admin' || _currentRole == 'super_admin') {
                  _showSnack('$donorName cooldown expired! Can donate again.', isSuccess: true);
                }
              }
            } catch (_) {}
          }
        }
      } catch (_) {}
    } else {
      final prefs = await SharedPreferences.getInstance();
      final users = prefs.getStringList('demo_users') ?? <String>[];
      final updatedUsers = <String>[];
      bool changed = false;
      for (final s in users) {
        try {
          final u = jsonDecode(s) as Map<String, dynamic>;
          final cooldownStr = u['cooldownUntil']?.toString();
          if (cooldownStr != null && cooldownStr.isNotEmpty) {
            try {
              final cooldownDate = DateTime.parse(cooldownStr);
              if (cooldownDate.isBefore(now)) {
                u.remove('cooldownUntil');
                changed = true;
                final donorEmail = u['email'] ?? '';
                final donorName = u['name'] ?? 'Donor';
                if (donorEmail.isNotEmpty && (_currentRole == 'admin' || _currentRole == 'super_admin')) {
                  _showSnack('$donorName cooldown expired! Can donate again.', isSuccess: true);
                }
              }
            } catch (_) {}
          }
          updatedUsers.add(jsonEncode(u));
        } catch (_) { updatedUsers.add(s); }
      }
      if (changed) {
        await prefs.setStringList('demo_users', updatedUsers);
      }
    }
  }

  Future<void> _checkApprovedAccess() async {
    if (_currentEmail == null || _currentEmail!.isEmpty) return;
    final approvedEmails = <String>{};
    
    if (FirebaseService.initialized) {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('donor_requests')
            .get();
        for (final doc in snap.docs) {
          final data = doc.data();
          if (data['type'] == 'donor_access_request' &&
              data['requesterEmail'] == _currentEmail &&
              data['status'] == 'approved') {
            final de = data['donorEmail']?.toString() ?? '';
            if (de.isNotEmpty) approvedEmails.add(de);
          }
        }
      } catch (_) {}
    } else {
      final prefs = await SharedPreferences.getInstance();
      final requests = prefs.getStringList('donor_requests') ?? [];
      for (final r in requests) {
        try {
          final req = jsonDecode(r) as Map<String, dynamic>;
          if (req['type'] == 'donor_access_request' &&
              req['requesterEmail'] == _currentEmail &&
              req['status'] == 'approved') {
            final de = req['donorEmail']?.toString() ?? '';
            if (de.isNotEmpty) approvedEmails.add(de);
          }
        } catch (_) {}
      }
    }
    if (mounted) {
      setState(() {
        _approvedDonorEmails = approvedEmails;
        _hasApprovedDonorAccess = approvedEmails.isNotEmpty;
      });
    }
  }

  ImageProvider? _imageFromBase64(String? base64Str) {
    if (base64Str == null || base64Str.isEmpty) return null;
    try {
      final bytes = base64Decode(base64Str);
      return MemoryImage(Uint8List.fromList(bytes));
    } catch (_) { return null; }
  }

  void _showSnack(String msg, {bool isError = false, bool isSuccess = false}) {
    if (!mounted) return;
    final bg = isError ? Colors.red.shade700 : isSuccess ? const Color(0xFFC62828) : const Color(0xFFC62828);
    showTopSnackBar(context, message: msg, backgroundColor: bg, topOffset: 50);
  }

  Future<void> _openSms(String phone, String body) async {
    final uri = Uri.parse('sms:$phone?body=${Uri.encodeComponent(body)}');
    try {
      if (!await launchUrl(uri)) {
        _showSnack('Could not open SMS app', isError: true);
      }
    } catch (e) {
      _showSnack('Error opening SMS: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Donors',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFB71C1C), Color(0xFFD32F2F), Color(0xFFEF5350)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search',
                hintStyle: TextStyle(fontSize: 14),
                prefixIcon: Icon(Icons.search, color: Colors.black, size: 20),
                filled: false,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide(color: Colors.black, width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide(color: Colors.black, width: 2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide(color: Colors.black, width: 2),
                ),
              ),
            ),
          ),
          // Donor List
          Expanded(
            child: FirebaseService.initialized ? _buildFirebaseList() : _buildDemoList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: Colors.black87),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFDECEC) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? const Color(0xFFB71C1C) : Colors.grey,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? const Color(0xFFB71C1C) : Colors.grey,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filters'),
        content: const Text('Additional filter options coming soon'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showBloodTypeDialog() {
    final bloodTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Blood Type'),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: bloodTypes.map((type) {
            return ChoiceChip(
              label: Text(type),
              selected: _filterBloodType == type,
              onSelected: (selected) {
                setState(() => _filterBloodType = selected ? type : null);
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _filterBloodType = null);
              Navigator.pop(context);
            },
            child: const Text('Clear'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showLocationDialog() {
    final locations = ['Lahore', 'Karachi', 'Islamabad', 'Rawalpindi', 'Faisalabad', 'Multan'];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Location'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: locations.map((loc) {
            return RadioListTile<String>(
              title: Text(loc, maxLines: 2, overflow: TextOverflow.ellipsis),
              value: loc,
              groupValue: _filterLocation,
              onChanged: (value) {
                setState(() => _filterLocation = value);
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _filterLocation = null);
              Navigator.pop(context);
            },
            child: const Text('Clear'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildFirebaseList() {
    return FutureBuilder<QuerySnapshot>(
      key: ValueKey('donors_$_reloadCounter'),
      future: FirebaseFirestore.instance.collection('users').get(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: BloodBridgeLoader());
        }

        if (snap.hasError) {
          print('Error loading donors: ${snap.error}');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                const SizedBox(height: 12),
                Text('Failed to load donors', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                const SizedBox(height: 8),
                TextButton(onPressed: () => setState(() {}), child: const Text('Retry')),
              ],
            ),
          );
        }

        if (!snap.hasData) {
          return const Center(child: BloodBridgeLoader());
        }
        
        var docs = snap.data!.docs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          final r = (data['role']?.toString() ?? '');
          // Only show donors and recipients, exclude super_admin
          return r == 'donor' || r == 'recipient';
        }).toList();

        // Apply filters
        docs = docs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          final name = (data['name'] ?? '').toString().toLowerCase();
          final bloodGroup = (data['bloodGroup'] ?? '').toString().toLowerCase();
          final location = (data['location'] ?? '').toString().toLowerCase();
          final role = (data['role'] ?? 'donor').toString();
          final approved = data['approved'] == true;

          // Search filter
          if (_searchQuery.isNotEmpty) {
            if (!name.contains(_searchQuery) && 
                !bloodGroup.contains(_searchQuery) && 
                !location.contains(_searchQuery)) {
              return false;
            }
          }

          // Blood type filter
          if (_filterBloodType != null && bloodGroup != _filterBloodType!.toLowerCase()) {
            return false;
          }

          // Location filter
          if (_filterLocation != null && !location.contains(_filterLocation!.toLowerCase())) {
            return false;
          }

          // Approved filter
          if (_filterApprovedOnly && !approved) {
            return false;
          }

          return true;
        }).toList();

        // Sort donors
        docs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          
          if (_sortBy == 'blood') {
            return (aData['bloodGroup'] ?? '').toString().compareTo((bData['bloodGroup'] ?? '').toString());
          } else if (_sortBy == 'location') {
            return (aData['location'] ?? '').toString().compareTo((bData['location'] ?? '').toString());
          } else {
            // Sort by recent (you can add timestamp field later)
            return 0;
          }
        });

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  'No donors found',
                  style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final d = docs[i];
            final data = d.data() as Map<String, dynamic>;
            return _buildDonorCard(data, d.id);
          },
        );
      },
    );
  }

  Widget _buildDonorCard(Map<String, dynamic> data, String? docId) {
    final role = (data['role'] ?? 'donor').toString();
    final approved = data['approved'] == true;
    final name = data['name'] ?? 'No name';
    final bloodGroup = data['bloodGroup'] ?? '';
    final location = data['location'] ?? '';

    return InkWell(
      onTap: () {
        // Navigate to detail screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DonorDetailScreen(
              donorData: data,
              docId: docId,
              isApproved: approved,
              canViewContact: _currentRole == 'admin' || _currentRole == 'super_admin' || approved || _approvedDonorEmails.contains(data['email']),
              isAdmin: _currentRole == 'admin' || _currentRole == 'super_admin',
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.85),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar
            _buildAvatar(data),
            const SizedBox(width: 16),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (data['verified'] == true)
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(Icons.verified, color: Colors.blue, size: 18),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        bloodGroup,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFB71C1C),
                        ),
                      ),
                      const Text(' • ', style: TextStyle(color: Colors.grey)),
                      Expanded(
                        child: Text(
                          location,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF455A64),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Badges and Button - constrained to prevent overflow
            SizedBox(
              width: 115,
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Cooldown timer badge (visible to everyone if donor has active cooldown)
                Builder(builder: (_) {
                  final cooldownStr = data['cooldownUntil']?.toString();
                  if (cooldownStr != null && cooldownStr.isNotEmpty) {
                    try {
                      final cooldownDate = DateTime.parse(cooldownStr);
                      if (cooldownDate.isAfter(DateTime.now())) {
                        final daysLeft = cooldownDate.difference(DateTime.now()).inDays;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.orange, width: 1),
                            ),
                            child: Text(
                              '⏳ ${daysLeft}d left',
                              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.orange),
                            ),
                          ),
                        );
                      }
                    } catch (_) {}
                  }
                  return const SizedBox.shrink();
                }),
                if (role == 'donor')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black, width: 2),
                    ),
                    child: const Text(
                      'Donor',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                  )
                else if (role == 'recipient')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black, width: 2),
                    ),
                    child: const Text(
                      'Recipient',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                  )
                else if (role == 'super_admin')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black, width: 2),
                    ),
                    child: const Text(
                      'Super_admin',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
                OutlinedButton(
                  onPressed: () => _handleContact(data, docId),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.black,
                    side: const BorderSide(color: Colors.black, width: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text(
                    'Contact',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                // Request button for recipients - per donor check
                if ((_currentRole == 'recipient' || _currentRole == 'user' || _currentRole == 'donor')) ...[
                  const SizedBox(height: 4),
                  if (_approvedDonorEmails.contains(data['email']))
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green, width: 1.5)),
                      child: const Text('Approved ✓', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.green)),
                    )
                  else
                    OutlinedButton(
                      onPressed: () => _requestDonorDirectly(data),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: const Color(0xFFB71C1C),
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFFB71C1C), width: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: const Size(0, 28),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: const Text('Request', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                    ),
                ],
                // Approve/Reject/Delete for admin
                if (_currentRole == 'admin' || _currentRole == 'super_admin') ...[
                  const SizedBox(height: 4),
                  if (approved) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green, width: 1.5)),
                      child: const Text('Approved ✓', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.green)),
                    ),
                    const SizedBox(height: 4),
                    _buildDonateButton(data, docId),
                  ] else ...[
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      OutlinedButton(
                        onPressed: () => _approveDonorAccess(data, docId),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.green.shade50,
                          foregroundColor: Colors.green.shade700,
                          side: BorderSide(color: Colors.green, width: 1.5),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: const Size(0, 28),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        child: const Text('Approve', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 4),
                      OutlinedButton(
                        onPressed: () => _rejectDonorAccess(data, docId),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.red.shade50,
                          foregroundColor: Colors.red.shade700,
                          side: BorderSide(color: Colors.red, width: 1.5),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: const Size(0, 28),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        child: const Text('Reject', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600)),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    OutlinedButton(
                      onPressed: () => _deleteDonorRequest(data, docId),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.grey.shade200,
                        foregroundColor: Colors.black54,
                        side: const BorderSide(color: Colors.grey, width: 1),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        minimumSize: const Size(0, 22),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: const Text('Delete', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w500)),
                    ),
                  ],
                ],
              ],
            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(Map<String, dynamic> data) {
    final img = _imageFromBase64(data['photoData'] as String?);
    final name = (data['name'] ?? '').toString();
    
    if (img != null) {
      return Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          image: DecorationImage(
            image: img,
            fit: BoxFit.cover,
          ),
        ),
      );
    }
    
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: const Color(0xFFE8EEF6),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Color(0xFF355070),
          ),
        ),
      ),
    );
  }

  void _requestDonorDirectly(Map<String, dynamic> donor) {
    // Check if donor is in cooldown period
    final cooldownUntil = donor['cooldownUntil']?.toString();
    if (cooldownUntil != null && cooldownUntil.isNotEmpty) {
      try {
        final cooldownDate = DateTime.parse(cooldownUntil);
        if (cooldownDate.isAfter(DateTime.now())) {
          final daysLeft = cooldownDate.difference(DateTime.now()).inDays;
          final nextDate = '${cooldownDate.day}/${cooldownDate.month}/${cooldownDate.year}';
          _showSnack(
            'This donor recently donated blood. Available again on $nextDate (${daysLeft} days left)',
            isError: true,
          );
          return;
        }
      } catch (_) {}
    }

    _submitDonorAccessRequest(
      donorEmail: donor['email'] ?? '',
      donorName: donor['name'] ?? '',
      reason: 'Requesting donor contact access',
      phone: _currentPhone ?? 'N/A',
      hospital: '',
    );
  }

  void _showRequestDonorAccessDialog(Map<String, dynamic> donor) {
    final reasonCtl = TextEditingController();
    final phoneCtl = TextEditingController();
    final hospitalCtl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.fact_check_rounded, color: const Color(0xFFB71C1C)),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Request Donor Access',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Color(0xFFB71C1C), size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your request will be sent to admin for approval. Once approved, you can view donor contact details.',
                        style: TextStyle(fontSize: 12, color: Color(0xFFB71C1C)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonCtl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Reason for Request *',
                  hintText: 'Explain why you need donor access...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Your Phone Number *',
                  prefixIcon: const Icon(Icons.phone, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: hospitalCtl,
                decoration: InputDecoration(
                  labelText: 'Hospital (Optional)',
                  prefixIcon: const Icon(Icons.local_hospital, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              final reason = reasonCtl.text.trim();
              final phone = phoneCtl.text.trim();

              if (reason.isEmpty || phone.isEmpty) {
                _showSnack('Please fill all required fields', isError: true);
                return;
              }

              Navigator.pop(ctx);
              await _submitDonorAccessRequest(
                donorEmail: donor['email'] ?? '',
                donorName: donor['name'] ?? '',
                reason: reason,
                phone: phone,
                hospital: hospitalCtl.text.trim(),
              );
            },
            icon: const Icon(Icons.send, size: 18),
            label: const Text('Submit Request'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB71C1C),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitDonorAccessRequest({
    required String reason,
    required String phone,
    required String hospital,
    required String donorEmail,
    required String donorName,
  }) async {
    setState(() => _isRequestingAccess = true);

    final request = {
      'type': 'donor_access_request',
      'requesterEmail': _currentEmail,
      'requesterPhone': phone,
      'donorEmail': donorEmail,
      'donorName': donorName,
      'reason': reason,
      'hospital': hospital,
      'status': 'pending',
      'requestedAt': DateTime.now().toIso8601String(),
    };

    if (FirebaseService.initialized) {
      try {
        await FirebaseFirestore.instance.collection('donor_requests').add(request);
        if (mounted) {
          _showSnack('Request sent to admin for approval!', isSuccess: true);
        }
      } catch (e) {
        if (mounted) {
          _showSnack('Error: $e', isError: true);
        }
      }
    } else {
      final prefs = await SharedPreferences.getInstance();
      final requests = prefs.getStringList('donor_requests') ?? [];
      requests.add(jsonEncode(request));
      await prefs.setStringList('donor_requests', requests);
      if (mounted) {
        _showSnack('Request sent (Demo mode)!', isSuccess: true);
      }
    }

    if (mounted) {
      setState(() => _isRequestingAccess = false);
      _checkApprovedAccess(); // Refresh per-donor approved list
    }
  }

  Future<void> _approveDonorAccess(Map<String, dynamic> donor, String? docId) async {
    try {
      if (FirebaseService.initialized && docId != null) {
        await FirebaseFirestore.instance.collection('users').doc(docId).update({'approved': true, 'verified': true});
      } else {
        // Demo mode: update donor in SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        final users = prefs.getStringList('demo_users') ?? <String>[];
        final donorEmail = donor['email'] ?? '';
        final updated = users.map((s) {
          try {
            final u = jsonDecode(s) as Map<String, dynamic>;
            if ((u['email'] ?? '') == donorEmail) {
              u['approved'] = true;
              u['verified'] = true;
            }
            return jsonEncode(u);
          } catch (_) { return s; }
        }).toList();
        await prefs.setStringList('demo_users', updated);
      }
      _showSnack('Donor approved!', isSuccess: true);
      setState(() { _reloadCounter++; });
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    }
  }

  Future<void> _rejectDonorAccess(Map<String, dynamic> donor, String? docId) async {
    try {
      if (FirebaseService.initialized && docId != null) {
        await FirebaseFirestore.instance.collection('users').doc(docId).update({'approved': false});
      } else {
        // Demo mode: update donor in SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        final users = prefs.getStringList('demo_users') ?? <String>[];
        final donorEmail = donor['email'] ?? '';
        final updated = users.map((s) {
          try {
            final u = jsonDecode(s) as Map<String, dynamic>;
            if ((u['email'] ?? '') == donorEmail) {
              u['approved'] = false;
            }
            return jsonEncode(u);
          } catch (_) { return s; }
        }).toList();
        await prefs.setStringList('demo_users', updated);
      }
      _showSnack('Donor rejected!', isError: true);
      setState(() { _reloadCounter++; });
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    }
  }

  Future<void> _deleteDonorRequest(Map<String, dynamic> donor, String? docId) async {
    final donorName = donor['name'] ?? 'Unknown';
    final donorEmail = donor['email'] ?? '';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Donor Request?'),
        content: Text('This will remove $donorName\'s approval status and all pending requests. They will become available for new requests again.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      if (FirebaseService.initialized && docId != null) {
        // Reset donor to unapproved state
        await FirebaseFirestore.instance.collection('users').doc(docId).update({
          'approved': false,
          'verified': false,
        });
        // Remove cooldown if present
        try {
          await FirebaseFirestore.instance.collection('users').doc(docId).update({
            'cooldownUntil': FieldValue.delete(),
            'lastDonation': FieldValue.delete(),
          });
        } catch (_) {}
      } else {
        // Demo mode
        final prefs = await SharedPreferences.getInstance();
        final users = prefs.getStringList('demo_users') ?? <String>[];
        final updated = users.map((s) {
          try {
            final u = jsonDecode(s) as Map<String, dynamic>;
            if ((u['email'] ?? '') == donorEmail) {
              u['approved'] = false;
              u['verified'] = false;
              u.remove('cooldownUntil');
              u.remove('lastDonation');
            }
            return jsonEncode(u);
          } catch (_) { return s; }
        }).toList();
        await prefs.setStringList('demo_users', updated);
      }

      _showSnack('Donor request deleted! Available for new requests.', isSuccess: true);
      setState(() { _reloadCounter++; });
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    }
  }

  Widget _buildDonateButton(Map<String, dynamic> data, String? docId) {
    final donorEmail = data['email'] ?? '';
    final cooldownUntil = data['cooldownUntil']?.toString();

    if (cooldownUntil != null && cooldownUntil.isNotEmpty) {
      try {
        final cooldownDate = DateTime.parse(cooldownUntil);
        if (cooldownDate.isAfter(DateTime.now())) {
          final daysLeft = cooldownDate.difference(DateTime.now()).inDays;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange, width: 1),
            ),
            child: Text(
              '⏳ ${daysLeft}d left',
              style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: Colors.orange),
            ),
          );
        }
      } catch (_) {}
    }

    return OutlinedButton(
      onPressed: () => _donateToDonor(data, docId),
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.blue.shade50,
        foregroundColor: Colors.blue.shade700,
        side: const BorderSide(color: Colors.blue, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: const Size(0, 28),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      child: const Text('Donate', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600)),
    );
  }

  Future<void> _donateToDonor(Map<String, dynamic> donor, String? docId) async {
    final donorName = donor['name'] ?? 'Unknown';
    final donorEmail = donor['email'] ?? '';
    final bloodGroup = donor['bloodGroup'] ?? '';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Donation'),
        content: Text('Mark that $donorName ($bloodGroup) has donated blood?\\n\\nThis will:\\n• Add 100 points to their profile\\n• Generate e-certificate eligibility\\n• Start 3-month cooldown'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD32F2F)),
            child: const Text('Confirm Donation', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final now = DateTime.now();
    final cooldownUntil = now.add(const Duration(days: 90)); // 3 months
    final donationRecord = {
      'donorEmail': donorEmail,
      'donorName': donorName,
      'bloodGroup': bloodGroup,
      'donatedAt': now.toIso8601String(),
      'cooldownUntil': cooldownUntil.toIso8601String(),
      'adminEmail': _currentEmail,
    };

    if (FirebaseService.initialized && docId != null) {
      try {
        // Update donor with cooldown
        await FirebaseFirestore.instance.collection('users').doc(docId).update({
          'cooldownUntil': cooldownUntil.toIso8601String(),
          'lastDonation': now.toIso8601String(),
          'donationCount': FieldValue.increment(1),
          'hasDonated': true,
        });

        // Save donation record
        await FirebaseFirestore.instance.collection('donations').add(donationRecord);

        // Schedule 3-month eligibility reminder
        final reminderMessage = '🎉 *You Can Donate Blood Again!* 🎉\n\n'
            'Dear $donorName,\n\n'
            'Your 3-month waiting period is now complete. You are eligible to donate blood again!\n\n'
            'With gratitude,\n'
            '*Quaidian Society of Blood Donors / Blood Bridge* ❤️';
        await FirebaseFirestore.instance.collection('donation_reminders').add({
          'donorEmail': donorEmail,
          'donorName': donorName,
          'message': reminderMessage,
          'sendAt': Timestamp.fromDate(cooldownUntil),
          'sent': false,
          'createdAt': Timestamp.fromDate(now),
          'donationRequestId': 'direct_${docId}_${now.millisecondsSinceEpoch}',
        });

        // Send thank-you in-app message to donor
        final thankYouMsg = '🩸 *Thank You for Your Donation!* 🩸\n\n'
            'Dear $donorName,\n\n'
            'Your blood donation has been recorded. You have helped save a life today!\n\n'
            '📅 *Next Eligible:* ${cooldownUntil.day}/${cooldownUntil.month}/${cooldownUntil.year}\n'
            '⏳ 90-day cooldown activated.\n\n'
            'With gratitude,\n'
            '*Quaidian Society of Blood Donors / Blood Bridge* ❤️';
        try {
          final convId = 'conv_${donorEmail.replaceAll('.', '_').replaceAll('@', '_at_')}_admin';
          final ts = Timestamp.fromDate(now);
          await FirebaseFirestore.instance.collection('messages').add({
            'conversationId': convId,
            'from': 'Admin',
            'to': donorEmail,
            'message': thankYouMsg,
            'sentAt': ts,
            'type': 'donation_thanks',
            'read': false,
          });
          await FirebaseFirestore.instance.collection('chats').doc(convId).set({
            'conversationId': convId,
            'participants': [donorEmail, 'Admin'],
            'participantNames': [donorName, 'Admin'],
            'lastMessage': thankYouMsg,
            'lastMessageAt': ts,
            'lastMessageFrom': 'Admin',
            'status': 'active',
            'unreadCount': 0,
            'updatedAt': ts,
          }, SetOptions(merge: true));
        } catch (_) {}

        // Update gamification points
        await _addDonationPoints(donorEmail, donorName);

        // Show thank-you popup
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.favorite, color: Colors.red, size: 28),
                  SizedBox(width: 8),
                  Text('Donation Recorded! 🩸', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              content: Text(
                'Thank you, $donorName ($bloodGroup)!\n\n'
                'Your donation has been recorded.\n\n'
                '📅 Cooldown until: ${cooldownUntil.day}/${cooldownUntil.month}/${cooldownUntil.year}\n'
                '⏳ 90 days remaining\n'
                '⭐ +100 points awarded!',
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: const Text('OK', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
        }
      } catch (e) {
        _showSnack('Error: $e', isError: true);
        return;
      }
    } else {
      // Demo mode
      final prefs = await SharedPreferences.getInstance();
      final users = prefs.getStringList('demo_users') ?? <String>[];
      final updatedUsers = users.map((s) {
        try {
          final u = jsonDecode(s) as Map<String, dynamic>;
          if ((u['email'] ?? '') == donorEmail) {
            u['cooldownUntil'] = cooldownUntil.toIso8601String();
            u['lastDonation'] = now.toIso8601String();
            u['donationCount'] = (u['donationCount'] ?? 0) + 1;
          }
          return jsonEncode(u);
        } catch (_) { return s; }
      }).toList();
      await prefs.setStringList('demo_users', updatedUsers);

      // Save donation record
      final donations = prefs.getStringList('donations') ?? [];
      donations.add(jsonEncode(donationRecord));
      await prefs.setStringList('donations', donations);

      // Update points
      await _addDonationPoints(donorEmail, donorName);
    }

    _showSnack('$donorName donated! +100 points, 3-month cooldown started', isSuccess: true);
    setState(() { _reloadCounter++; });
  }

  Future<void> _addDonationPoints(String email, String name) async {
    if (FirebaseService.initialized) {
      try {
        // Update or create gamification document
        final snap = await FirebaseFirestore.instance
            .collection('gamification')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty) {
          await snap.docs.first.reference.update({
            'points': FieldValue.increment(100),
            'donations': FieldValue.increment(1),
            'certificateEligible': true,
          });
        } else {
          await FirebaseFirestore.instance.collection('gamification').add({
            'email': email,
            'name': name,
            'points': 100,
            'donations': 1,
            'certificateEligible': true,
          });
        }
      } catch (_) {}
    } else {
      final prefs = await SharedPreferences.getInstance();
      final lb = prefs.getStringList('leaderboard') ?? [];
      bool found = false;
      final updated = lb.map((s) {
        try {
          final m = jsonDecode(s) as Map<String, dynamic>;
          if ((m['email'] ?? '') == email) {
            found = true;
            m['score'] = (m['score'] ?? 0) + 100;
            return jsonEncode(m);
          }
        } catch (_) {}
        return s;
      }).toList();
      if (!found) {
        updated.add(jsonEncode({'name': name, 'email': email, 'score': 100}));
      }
      await prefs.setStringList('leaderboard', updated);
    }
  }

  void _handleContact(Map<String, dynamic> data, String? docId) {
    final approved = data['approved'] == true;
    final contact = data['contact'] ?? 'No contact';
    final name = data['name'] ?? 'No name';
    final bloodGroup = data['bloodGroup'] ?? '';
    final location = data['location'] ?? '';

    if (!approved && _currentRole != 'admin' && _currentRole != 'super_admin' && !_approvedDonorEmails.contains(data['email'])) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Access Restricted'),
          content: const Text('Contact information is only available after admin approval. Use the "Request for Donor" button to request access.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        contentPadding: EdgeInsets.zero,
        content: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.85),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.black, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),
              _buildInfoRow(Icons.bloodtype, 'Blood Group', bloodGroup),
              const SizedBox(height: 10),
              _buildInfoRow(Icons.location_on, 'Location', location),
              const SizedBox(height: 10),
              _buildInfoRow(Icons.phone, 'Contact', contact),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Close',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (contact != 'No contact') ...[
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: () {
                        final uri = Uri.parse('tel:$contact');
                        launchUrl(uri);
                      },
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.black,
                        side: const BorderSide(color: Colors.black, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: const Text(
                        'Call',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.black),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w700,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDemoList() {
    return FutureBuilder<List<String>>(
      key: ValueKey('donors_demo_$_reloadCounter'),
      future: SharedPreferences.getInstance().then((p) => p.getStringList('demo_users') ?? <String>[]),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: BloodBridgeLoader());
        
        var list = snap.data!;
        if (list.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  'No donors yet (demo)',
                  style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        }

        // Parse and filter users
        final users = list.map((s) {
          try {
            return jsonDecode(s) as Map<String, dynamic>;
          } catch (_) {
            return <String, dynamic>{};
          }
        }).where((u) {
          if (u.isEmpty) return false;
          final role = (u['role'] ?? '').toString();
          // Exclude super_admin from donor list
          return role != 'super_admin';
        }).toList();

        // Apply filters
        var filteredUsers = users.where((u) {
          final name = (u['name'] ?? '').toString().toLowerCase();
          final bloodGroup = (u['bloodGroup'] ?? '').toString().toLowerCase();
          final location = (u['location'] ?? '').toString().toLowerCase();
          final approved = u['approved'] == true;

          // Search filter
          if (_searchQuery.isNotEmpty) {
            if (!name.contains(_searchQuery) && 
                !bloodGroup.contains(_searchQuery) && 
                !location.contains(_searchQuery)) {
              return false;
            }
          }

          // Blood type filter
          if (_filterBloodType != null && bloodGroup != _filterBloodType!.toLowerCase()) {
            return false;
          }

          // Location filter
          if (_filterLocation != null && !location.contains(_filterLocation!.toLowerCase())) {
            return false;
          }

          // Approved filter
          if (_filterApprovedOnly && !approved) {
            return false;
          }

          return true;
        }).toList();

        // Sort users
        filteredUsers.sort((a, b) {
          if (_sortBy == 'blood') {
            return (a['bloodGroup'] ?? '').toString().compareTo((b['bloodGroup'] ?? '').toString());
          } else if (_sortBy == 'location') {
            return (a['location'] ?? '').toString().compareTo((b['location'] ?? '').toString());
          } else {
            return 0;
          }
        });

        if (filteredUsers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  'No donors match your filters',
                  style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: filteredUsers.length,
          itemBuilder: (context, i) {
            return _buildDonorCard(filteredUsers[i], null);
          },
        );
      },
    );
  }
}
