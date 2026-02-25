import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/firebase_service.dart';
import 'package:flutter/services.dart';
import '../../widgets/app_card.dart';
import '../../widgets/blood_bridge_loader.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<Map<String, dynamic>?> _loadProfile() async {
    // If Firebase is not initialized, try loading demo user from SharedPreferences.
    if (!FirebaseService.initialized) {
      final prefs = await SharedPreferences.getInstance();
      final currentEmail = prefs.getString('demo_current_email');
      final list = prefs.getStringList('demo_users') ?? <String>[];
      print('📧 Loading profile for demo user: $currentEmail');
      if (currentEmail == null) return null;
      try {
        for (final s in list) {
          final Map<String, dynamic> u = jsonDecode(s);
          if ((u['email'] ?? '') == currentEmail) {
            print('✅ Profile data loaded: $u');
            return u;
          }
        }
      } catch (e) {
        print('❌ Error loading demo profile: $e');
        return null;
      }
      return null;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    try {
      print('📥 Loading Firebase profile for UID: ${user.uid}');
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      
      if (!doc.exists) {
        print('⚠️ User document does not exist in Firestore!');
        return {'name': 'Unknown', 'email': user.email ?? '', 'error': 'Document not found'};
      }
      
      final data = doc.data();
      if (data == null || data.isEmpty) {
        print('⚠️ User document exists but is empty!');
        return {'name': 'Unknown', 'email': user.email ?? '', 'error': 'Empty document'};
      }
      
      print('✅ Firebase profile data loaded: $data');
      if (data['createdAt'] is Timestamp) {
        final ts = data['createdAt'] as Timestamp;
        data['createdAt'] = ts.toDate().toIso8601String();
      }
      return data;
    } catch (e) {
      print('❌ Error loading Firebase profile: $e');
      return {'name': 'Unknown', 'email': user.email ?? ''};
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _loadProfile(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return Center(child: BloodBridgeLoader());
        final data = snap.data;
        if (data == null) return Center(child: Text('Not signed in'));

        // Check if profile is incomplete (missing essential fields)
        final bool isIncomplete = data.containsKey('error') || 
            data['name'] == null || 
            data['name'] == 'Unknown' ||
            data['contact'] == null || 
            data['designation'] == null || 
            data['age'] == null || 
            data['gender'] == null || 
            data['location'] == null;

        // Build avatar from photoData if present (base64), otherwise default icon
        Widget avatar;
        try {
          final pd = data['photoData'] ?? '';
          if (pd is String && pd.isNotEmpty) {
            final bytes = base64Decode(pd);
            avatar = Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.red[300]!, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: CircleAvatar(radius: 46, backgroundImage: MemoryImage(bytes)),
            );
          } else {
            avatar = Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.red[300]!, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 46,
                backgroundColor: Colors.red[100],
                child: Icon(Icons.person, size: 50, color: Colors.red[700]),
              ),
            );
          }
        } catch (e) {
          avatar = Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.red[300]!, width: 4),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 46,
              backgroundColor: Colors.red[100],
              child: Icon(Icons.person, size: 50, color: Colors.red[700]),
            ),
          );
        }

        final role = data['role'] ?? '';
        final blood = data['bloodGroup'] ?? '';
        final approved = data['approved'] == true;
        final name = data['name'] ?? 'No name';
        final age = data['age']?.toString() ?? 'N/A';
        final gender = data['gender'] ?? 'N/A';
        final designation = data['designation'] ?? 'N/A';

        return Scaffold(
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.red[50]!, Colors.white],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Show incomplete profile banner if needed
                  if (isIncomplete)
                    Container(
                      width: double.infinity,
                      margin: EdgeInsets.all(16),
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange[300]!, width: 2),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.orange[700], size: 32),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Profile Incomplete',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange[900],
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Please complete your profile to use all features',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.orange[800],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => EditProfileScreen(currentData: data),
                                ),
                              );
                              if (result == true) {
                                setState(() {});
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange[700],
                              foregroundColor: Colors.white,
                            ),
                            child: Text('Complete'),
                          ),
                        ],
                      ),
                    ),
                  // Top Section with Avatar and Name
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.only(top: 40, bottom: 20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.red[700]!, Colors.red[500]!, Colors.pink[400]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.3),
                          blurRadius: 20,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        avatar,
                        SizedBox(height: 12),
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            decoration: TextDecoration.none,
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(height: 6),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.bloodtype, color: Colors.white, size: 20),
                              SizedBox(width: 6),
                              Text(
                                blood.isNotEmpty ? blood : 'N/A',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                              SizedBox(width: 12),
                              Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.5),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              SizedBox(width: 12),
                              Text(
                                role.isNotEmpty ? '${role[0].toUpperCase()}${role.substring(1)}' : 'N/A',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Content Cards - All Information Below
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        // Personal Details Card
                        _buildCard(
                          title: 'Personal Details',
                          icon: Icons.person_outline,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildInfoTile(
                                    icon: Icons.cake_outlined,
                                    title: 'Age',
                                    value: '$age years',
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: _buildInfoTile(
                                    icon: Icons.wc,
                                    title: 'Gender',
                                    value: gender,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            _buildInfoTile(
                              icon: Icons.work_outline,
                              title: 'Designation',
                              value: designation,
                            ),
                            if (role == 'donor') ...[
                              SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildInfoTile(
                                      icon: approved ? Icons.verified : Icons.pending,
                                      title: 'Approval Status',
                                      value: approved ? 'Approved' : 'Pending Approval',
                                      valueColor: approved ? Colors.green[700] : Colors.orange[700],
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: _buildInfoTile(
                                      icon: data['hasDonated'] == true ? Icons.check_circle : Icons.schedule,
                                      title: 'Donation Status',
                                      value: data['hasDonated'] == true ? 'Donated' : 'Not Donated',
                                      valueColor: data['hasDonated'] == true ? Colors.green[700] : Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                        
                        SizedBox(height: 16),
                        
                        // Contact Information Card
                        _buildCard(
                          title: 'Contact Information',
                          icon: Icons.contact_phone,
                          children: [
                            _buildInfoTile(
                              icon: Icons.email_outlined,
                              title: 'Email Address',
                              value: data['email'] ?? 'Not provided',
                            ),
                            SizedBox(height: 12),
                            _buildInfoTile(
                              icon: Icons.phone_android,
                              title: 'Phone Number',
                              value: data['contact'] ?? 'Not provided',
                            ),
                            SizedBox(height: 12),
                            _buildInfoTile(
                              icon: Icons.location_on,
                              title: 'Location',
                              value: data['location'] ?? 'Not provided',
                            ),
                          ],
                        ),
                        
                        SizedBox(height: 16),
                        
                        // Membership Information Card
                        _buildCard(
                          title: 'Membership',
                          icon: Icons.card_membership,
                          children: [
                            _buildInfoTile(
                              icon: Icons.calendar_month,
                              title: 'Member Since',
                              value: data['createdAt'] != null ? _formatDate(data['createdAt'].toString()) : 'N/A',
                            ),
                          ],
                        ),
                        
                        SizedBox(height: 30),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCard({required String title, required IconData icon, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 15,
            offset: Offset(0, 5),
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.red[600]!, Colors.red[400]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.3),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              SizedBox(width: 14),
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                  decoration: TextDecoration.none,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon, 
    required String title, 
    required String value,
    Color? valueColor,
  }) {
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.red[50]!, Colors.pink[50]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.red[700], size: 22),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.none,
                    letterSpacing: 0.3,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    color: valueColor ?? Colors.grey[900],
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return dateStr;
    }
  }

  Future<List<String>> _loadSuperadminContacts() async {
    if (FirebaseService.initialized) {
      try {
        final doc = await FirebaseFirestore.instance.collection('meta').doc('app_config').get();
        final data = doc.data() ?? {};
        final List contacts = data['superadmin_contacts'] ?? [];
        return contacts.map((e) => e.toString()).toList();
      } catch (_) {
        return <String>[];
      }
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('superadmin_contacts') ?? <String>[];
  }
}
