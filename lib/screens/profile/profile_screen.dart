import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/firebase_service.dart';
import 'package:flutter/services.dart';
import '../../widgets/app_card.dart';
import '../../widgets/blood_bridge_loader.dart';
import '../../widgets/top_snackbar.dart';
import 'edit_profile_screen.dart';
import 'document_upload_screen.dart';

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

        final role = data['role'] ?? '';
        final blood = data['bloodGroup'] ?? '';
        final approved = data['approved'] == true;
        final verificationStatus = (data['verificationStatus'] ?? '').toString().toLowerCase();
        final verified = data['verified'] == true || verificationStatus == 'approved';
        final bool showDonorBlueTick = role == 'donor' && verified;

        // Always show default avatar since photos are removed from registration
        Widget avatar = Container(
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

        if (showDonorBlueTick) {
          avatar = Stack(
            clipBehavior: Clip.none,
            children: [
              avatar,
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.blue, width: 1.2),
                  ),
                  child: Icon(Icons.verified, color: Colors.blue, size: 18),
                ),
              ),
            ],
          );
        }

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
                            // Blood Group (moved from header)
                            _buildInfoTile(
                              icon: Icons.bloodtype,
                              title: 'Blood Group',
                              value: blood.isNotEmpty ? blood : 'Not specified',
                              isVerified: verified,
                            ),
                            SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildInfoTile(
                                    icon: Icons.cake_outlined,
                                    title: 'Age',
                                    value: '$age years',
                                    isVerified: verified,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: _buildInfoTile(
                                    icon: Icons.wc,
                                    title: 'Gender',
                                    value: gender,
                                    isVerified: verified,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            _buildInfoTile(
                              icon: Icons.work_outline,
                              title: 'Designation',
                              value: designation,
                              isVerified: verified,
                            ),
                            if (role == 'donor') ...[
                              SizedBox(height: 12),
                              _buildInfoTile(
                                icon: data['hasDonated'] == true ? Icons.check_circle : Icons.schedule,
                                title: 'Donation Status',
                                value: data['hasDonated'] == true ? 'Donated' : 'Not Donated',
                                valueColor: data['hasDonated'] == true ? Colors.green[700] : Colors.grey[700],
                              ),
                            ],
                            if (role == 'recipient') ...[
                              SizedBox(height: 12),
                              _buildInfoTile(
                                icon: verified ? Icons.verified : Icons.pending_actions,
                                title: 'Verification Status',
                                value: verified ? 'Verified' : 'Pending Verification',
                                valueColor: verified ? Colors.blue[700] : Colors.orange[700],
                                isVerified: verified,
                              ),
                            ],
                          ],
                        ),
                        
                        SizedBox(height: 16),
                        
                        // Donation Cooldown Timer Card (for donors with active cooldown)
                        if (role == 'donor') ...[
                          Builder(builder: (ctx) {
                            final cooldownStr = data['cooldownUntil']?.toString();
                            final lastDonationStr = data['lastDonation']?.toString();
                            final donationCount = data['donationCount'] ?? 0;
                            final hasActiveCooldown = cooldownStr != null && cooldownStr.isNotEmpty;
                            
                            if (hasActiveCooldown) {
                              DateTime? cooldownDate;
                              int daysLeft = 0;
                              try {
                                cooldownDate = DateTime.parse(cooldownStr);
                                daysLeft = cooldownDate.difference(DateTime.now()).inDays;
                              } catch (_) {}
                              
                              final isExpired = cooldownDate != null && cooldownDate.isBefore(DateTime.now());
                              
                              if (isExpired) {
                                return _buildCard(
                                  title: '🎉 You Can Donate Again!',
                                  icon: Icons.celebration,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.green.shade300),
                                      ),
                                      child: Column(
                                        children: [
                                          const Icon(Icons.check_circle, color: Colors.green, size: 48),
                                          const SizedBox(height: 8),
                                          const Text(
                                            'Your 3-month waiting period is complete!',
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.green),
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'You are now eligible to donate blood again. ❤️',
                                            style: TextStyle(color: Colors.green.shade700, fontSize: 13),
                                            textAlign: TextAlign.center,
                                          ),
                                          if (lastDonationStr != null) ...[
                                            const SizedBox(height: 8),
                                            Text(
                                              'Last donation: $_formatDateShort(lastDonationStr)',
                                              style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                            ),
                                          ],
                                          Text(
                                            'Total donations: $donationCount',
                                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              } else {
                                return _buildCard(
                                  title: '⏳ Donation Cooldown',
                                  icon: Icons.timer,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.orange.shade300),
                                      ),
                                      child: Column(
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.timer, color: Colors.orange.shade700, size: 32),
                                              const SizedBox(width: 8),
                                              Text(
                                                '$daysLeft Days',
                                                style: TextStyle(
                                                  fontSize: 32,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.orange.shade800,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'remaining until you can donate again',
                                            style: TextStyle(color: Colors.orange.shade700, fontSize: 13),
                                          ),
                                          const SizedBox(height: 12),
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: LinearProgressIndicator(
                                              value: 1.0 - (daysLeft / 90),
                                              minHeight: 8,
                                              backgroundColor: Colors.orange.shade100,
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.orange.shade700),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          if (cooldownDate != null)
                                            Text(
                                              'Eligible after: ${cooldownDate.day}/${cooldownDate.month}/${cooldownDate.year}',
                                              style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                            ),
                                          if (lastDonationStr != null)
                                            Text(
                                              'Donated: $_formatDateShort(lastDonationStr)',
                                              style: TextStyle(color: Colors.grey[500], fontSize: 11),
                                            ),
                                          Text(
                                            'Total donations: $donationCount',
                                            style: TextStyle(color: Colors.grey[500], fontSize: 11),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }
                            }
                            return const SizedBox.shrink();
                          }),
                        ],
                        
                        SizedBox(height: 16),
                        
                        // Document Verification Card (only for recipients)
                        if (role == 'recipient') ...[
                          _buildRecipientDocumentCard(context, data, role),
                          SizedBox(height: 16),
                        ],
                        
                        // Contact Information Card
                        _buildCard(
                          title: 'Contact Information',
                          icon: Icons.contact_phone,
                          children: [
                            _buildInfoTile(
                              icon: Icons.email_outlined,
                              title: 'Email Address',
                              value: data['email'] ?? 'Not provided',
                              isVerified: verified,
                            ),
                            SizedBox(height: 12),
                            _buildInfoTile(
                              icon: Icons.phone_android,
                              title: 'Phone Number',
                              value: data['contact'] ?? 'Not provided',
                              isVerified: verified,
                            ),
                            SizedBox(height: 12),
                            _buildInfoTile(
                              icon: Icons.location_on,
                              title: 'Location',
                              value: data['location'] ?? 'Not provided',
                              isVerified: verified,
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
    bool isVerified = false,
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
                Row(
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
                    if (isVerified) ...[
                      SizedBox(width: 6),
                      Container(
                        padding: EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.blue, width: 1),
                        ),
                        child: Icon(Icons.verified, color: Colors.blue, size: 14),
                      ),
                      SizedBox(width: 2),
                      Text(
                        'Verified',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
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

  String _formatDateShort(String dateStr) {
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

  Widget _buildRecipientDocumentCard(BuildContext context, Map<String, dynamic> data, String role) {
    return _buildCard(
      title: 'Document Verification',
      icon: Icons.verified_user,
      children: [
        // Overall status
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: data['documentsVerified'] == true ? Colors.green[50] : Colors.orange[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: data['documentsVerified'] == true ? Colors.green[300]! : Colors.orange[300]!,
            ),
          ),
          child: Row(
            children: [
              Icon(
                data['documentsVerified'] == true ? Icons.verified : Icons.pending_actions,
                color: data['documentsVerified'] == true ? Colors.green[700] : Colors.orange[700],
                size: 24,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['documentsVerified'] == true ? 'Documents Verified ✓' : 'Documents Pending Review',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: data['documentsVerified'] == true ? Colors.green[900] : Colors.orange[900],
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      data['documentsVerified'] == true
                          ? 'All your documents have been verified by the admin'
                          : 'Upload all 3 required documents below for verification',
                      style: TextStyle(
                        fontSize: 12,
                        color: data['documentsVerified'] == true ? Colors.green[800] : Colors.orange[800],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 16),

        // Individual document statuses with upload buttons
        _buildDocStatusItem(
          context: context,
          emoji: '🪪',
          title: 'CNIC / ID Card - Front',
          docType: 'id_front',
          userData: data,
        ),
        SizedBox(height: 10),
        _buildDocStatusItem(
          context: context,
          emoji: '🆔',
          title: 'CNIC / ID Card - Back',
          docType: 'id_back',
          userData: data,
        ),
        SizedBox(height: 10),
        _buildDocStatusItem(
          context: context,
          emoji: '🩸',
          title: 'Blood Test Report',
          docType: 'blood_test',
          userData: data,
        ),

        SizedBox(height: 16),
        // Open full document upload screen
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DocumentUploadScreen(
                    userRole: role,
                    userData: data,
                  ),
                ),
              );
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: BorderSide(color: Colors.red[300]!),
              padding: EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: Icon(Icons.manage_search, size: 20),
            label: Text('📋 Manage All Documents'),
          ),
        ),
      ],
    );
  }

  Widget _buildDocStatusItem({
    required BuildContext context,
    required String emoji,
    required String title,
    required String docType,
    required Map<String, dynamic> userData,
  }) {
    // Fetch doc status directly from Firestore or SharedPreferences
    return FutureBuilder<Map<String, dynamic>?>(
      future: _fetchSingleDocStatus(userData, docType),
      builder: (context, snap) {
        final doc = snap.data;
        final status = doc?['status'] as String?;
        final isVerified = status == 'verified';
        final isPending = status == 'pending';
        final isUploaded = doc != null;

        return Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isVerified
                ? Colors.green[50]
                : isPending
                    ? Colors.orange[50]
                    : Colors.grey[50],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isVerified
                  ? Colors.green[200]!
                  : isPending
                      ? Colors.orange[200]!
                      : Colors.grey[200]!,
            ),
          ),
          child: Row(
            children: [
              // Status icon
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isVerified
                      ? Colors.green[100]
                      : isPending
                          ? Colors.orange[100]
                          : Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: isVerified
                      ? Icon(Icons.check_circle, color: Colors.green[700], size: 20)
                      : isPending
                          ? Icon(Icons.schedule, color: Colors.orange[700], size: 20)
                          : Text(emoji, style: TextStyle(fontSize: 18)),
                ),
              ),
              SizedBox(width: 12),
              // Title and status
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      isVerified
                          ? 'Verified ✓'
                          : isPending
                              ? 'Pending review...'
                              : 'Not uploaded yet',
                      style: TextStyle(
                        fontSize: 11,
                        color: isVerified
                            ? Colors.green[700]
                            : isPending
                                ? Colors.orange[700]
                                : Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // Upload button
              SizedBox(
                height: 32,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await _quickUpload(context, userData, docType);
                    setState(() {}); // refresh entire profile
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isUploaded ? Colors.blue : Colors.red,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: Icon(
                    isUploaded ? Icons.refresh : Icons.upload,
                    size: 14,
                  ),
                  label: Text(
                    isUploaded ? 'Re-upload' : 'Upload',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<Map<String, dynamic>?> _fetchSingleDocStatus(
      Map<String, dynamic> userData, String docType) async {
    try {
      final userId = FirebaseService.initialized
          ? FirebaseAuth.instance.currentUser?.uid
          : userData['uid'];
      if (FirebaseService.initialized && userId != null) {
        try {
          final snap = await FirebaseFirestore.instance
              .collection('verificationDocuments')
              .where('userId', isEqualTo: userId)
              .where('documentType', isEqualTo: docType)
              .orderBy('uploadedAt', descending: true)
              .limit(1)
              .get();
          if (snap.docs.isNotEmpty) {
            return {...snap.docs.first.data(), 'docId': snap.docs.first.id};
          }
        } catch (e) {
          // Try without orderBy (missing index)
          try {
            final snap2 = await FirebaseFirestore.instance
                .collection('verificationDocuments')
                .where('userId', isEqualTo: userId)
                .where('documentType', isEqualTo: docType)
                .get();
            if (snap2.docs.isNotEmpty) {
              final docs = snap2.docs.toList()
                ..sort((a, b) => (b.data()['uploadedAt'] ?? '').compareTo(a.data()['uploadedAt'] ?? ''));
              return {...docs.first.data(), 'docId': docs.first.id};
            }
          } catch (_) {}
        }
        // Backward compat: old id_verification → id_front
        if (docType == 'id_front') {
          try {
            final oldSnap = await FirebaseFirestore.instance
                .collection('verificationDocuments')
                .where('userId', isEqualTo: userId)
                .where('documentType', isEqualTo: 'id_verification')
                .get();
            if (oldSnap.docs.isNotEmpty) {
              final docs = oldSnap.docs.toList()
                ..sort((a, b) => (b.data()['uploadedAt'] ?? '').compareTo(a.data()['uploadedAt'] ?? ''));
              return {...docs.first.data(), 'docId': docs.first.id};
            }
          } catch (_) {}
        }
      } else {
        final prefs = await SharedPreferences.getInstance();
        final docsJson = prefs.getStringList('demo_verification_documents') ?? [];
        final allDocs = docsJson
            .map((s) => jsonDecode(s) as Map<String, dynamic>)
            .where((d) => d['userId'] == userData['uid'] && d['documentType'] == docType)
            .toList();
        if (allDocs.isNotEmpty) return allDocs.first;
        // Backward compat for demo: id_verification → id_front
        if (docType == 'id_front') {
          final oldDocs = docsJson
              .map((s) => jsonDecode(s) as Map<String, dynamic>)
              .where((d) => d['userId'] == userData['uid'] && d['documentType'] == 'id_verification')
              .toList();
          if (oldDocs.isNotEmpty) return oldDocs.first;
        }
      }
    } catch (e) {
      print('Error fetching doc status for $docType: $e');
    }
    return null;
  }

  Future<void> _quickUpload(
      BuildContext context, Map<String, dynamic> userData, String docType) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );
      if (result == null) return;

      final file = result.files.first;
      late Uint8List bytes;
      if (file.bytes != null) {
        bytes = file.bytes!;
      } else {
        throw 'Could not read file';
      }

      final base64File = base64Encode(bytes);
      final userId = FirebaseService.initialized
          ? FirebaseAuth.instance.currentUser?.uid
          : userData['uid'];

      final documentData = {
        'userId': userId,
        'userName': userData['name'] ?? 'Unknown',
        'userEmail': userData['email'] ?? 'N/A',
        'documentType': docType,
        'fileName': file.name,
        'fileSize': file.size,
        'fileData': base64File,
        'status': 'pending',
        'uploadedAt': DateTime.now().toIso8601String(),
        'verifiedAt': null,
        'verifiedBy': null,
        'verificationNotes': '',
      };

      if (FirebaseService.initialized && userId != null) {
        await FirebaseFirestore.instance
            .collection('verificationDocuments')
            .add(documentData);
      } else {
        final prefs = await SharedPreferences.getInstance();
        final docsJson = prefs.getStringList('demo_verification_documents') ?? [];
        documentData['docId'] = 'doc_${DateTime.now().millisecondsSinceEpoch}';
        docsJson.add(jsonEncode(documentData));
        await prefs.setStringList('demo_verification_documents', docsJson);
      }

      if (context.mounted) {
        showTopSnackBar(context, message: 'Document uploaded! Status: Pending admin verification', backgroundColor: Colors.green);
      }
    } catch (e) {
      print('Error uploading: $e');
      if (context.mounted) {
        showTopSnackBar(context, message: 'Error: $e', backgroundColor: Colors.red);
      }
    }
  }
}
