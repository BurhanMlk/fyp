import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/firebase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../widgets/blood_bridge_loader.dart';
import 'donor_detail_screen.dart';


class DonorListScreen extends StatefulWidget {
  const DonorListScreen({super.key});

  @override
  _DonorListScreenState createState() => _DonorListScreenState();
}

class _DonorListScreenState extends State<DonorListScreen> {
  String? _currentEmail;
  String? _currentRole;
  String _searchQuery = '';
  String? _filterBloodType;
  String? _filterLocation;
  bool _filterApprovedOnly = false;
  String _sortBy = 'blood'; // 'blood', 'location', 'recent'

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    if (FirebaseService.initialized) {
      final u = FirebaseAuth.instance.currentUser;
      setState(() { _currentEmail = u?.email; });
      if (u != null) {
        try {
          final snap = await FirebaseFirestore.instance.collection('users').doc(u.uid).get();
          if (snap.exists) setState(() { _currentRole = snap.data()?['role']?.toString(); });
        } catch (_) {}
      }
    } else {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _currentEmail = prefs.getString('demo_current_email');
        final users = prefs.getStringList('demo_users') ?? <String>[];
        try {
          final me = users.map((s) => jsonDecode(s) as Map<String, dynamic>).firstWhere((u) => (u['email'] ?? '') == (_currentEmail ?? ''), orElse: () => <String, dynamic>{});
          _currentRole = me['role']?.toString();
        } catch (_) { _currentRole = null; }
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

  Future<void> _openSms(String phone, String body) async {
    final uri = Uri.parse('sms:$phone?body=${Uri.encodeComponent(body)}');
    try {
      if (!await launchUrl(uri)) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open SMS app')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error opening SMS: $e')));
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
              title: Text(loc),
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
      future: FirebaseFirestore.instance.collection('users').get(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: BloodBridgeLoader());
        
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
              canViewContact: _currentRole == 'admin' || _currentRole == 'super_admin' || approved,
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
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
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

            const SizedBox(width: 12),

            // Badges and Button
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
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
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => _handleContact(data, docId),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.black,
                    side: BorderSide(color: Colors.black, width: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text(
                    'Contact',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
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

  void _handleContact(Map<String, dynamic> data, String? docId) {
    final approved = data['approved'] == true;
    final contact = data['contact'] ?? 'No contact';
    final name = data['name'] ?? 'No name';
    final bloodGroup = data['bloodGroup'] ?? '';
    final location = data['location'] ?? '';

    if (!approved && _currentRole != 'admin' && _currentRole != 'super_admin') {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Not Approved'),
          content: const Text('This donor is not yet approved. Contact information is only available for approved donors.'),
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
