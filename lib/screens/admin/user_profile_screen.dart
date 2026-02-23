import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/firebase_service.dart';
import '../../widgets/blood_bridge_loader.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

class UserProfileScreen extends StatefulWidget {
  final Map<String, dynamic>? demoData;
  final String? firebaseUid;

  const UserProfileScreen({super.key, this.demoData, this.firebaseUid});

  @override
  _UserProfileScreenState createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  Future<Map<String, dynamic>?> _load() async {
    if (widget.demoData != null) return widget.demoData;
    if (widget.firebaseUid != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(widget.firebaseUid).get();
        final data = doc.data();
        if (data == null) return null;
        if (data['createdAt'] is Timestamp) {
          data['createdAt'] = (data['createdAt'] as Timestamp).toDate().toIso8601String();
        }
        return data;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _load(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return Scaffold(body: Center(child: BloodBridgeLoader()));
        final data = snap.data;
        if (data == null) return Scaffold(appBar: AppBar(title: Text('Profile')), body: Center(child: Text('Profile not found')));

        Widget avatar;
        try {
          final pd = data['photoData'] ?? '';
          if (pd is String && pd.isNotEmpty) {
            final bytes = base64Decode(pd);
            avatar = Container(
              width: 120,
              height: 120,
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
              child: CircleAvatar(radius: 56, backgroundImage: MemoryImage(bytes)),
            );
          } else {
            avatar = Container(
              width: 120,
              height: 120,
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
                radius: 56,
                backgroundColor: Colors.red[100],
                child: Icon(Icons.person, size: 60, color: Colors.red[700]),
              ),
            );
          }
        } catch (e) {
          avatar = Container(
            width: 120,
            height: 120,
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
              radius: 56,
              backgroundColor: Colors.red[100],
              child: Icon(Icons.person, size: 60, color: Colors.red[700]),
            ),
          );
        }

        final role = data['role'] ?? '';
        final blood = data['bloodGroup'] ?? '';
        final approved = data['approved'] == true;

        return Scaffold(
          backgroundColor: Colors.grey[50],
          appBar: AppBar(
            title: Text('Profile Details'),
            backgroundColor: Colors.red[400],
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          body: SingleChildScrollView(
            child: Column(
              children: [
                // Top Section with Gradient Background
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.red[400]!, Colors.red[300]!],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Column(
                    children: [
                      SizedBox(height: 20),
                      avatar,
                      SizedBox(height: 20),
                      Text(
                        data['name'] ?? 'No name',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 12),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: Text(
                          blood.isNotEmpty ? '$blood • ${role[0].toUpperCase()}${role.substring(1)}' : (data['email'] ?? ''),
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.red[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (role == 'donor') SizedBox(height: 12),
                      if (role == 'donor')
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: approved ? Colors.green : Colors.orange,
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: Text(
                            approved ? '✓ Approved' : '⏳ Pending approval',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      SizedBox(height: 30),
                    ],
                  ),
                ),
                
                // Content Cards
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // Contact Card
                      _buildCard(
                        title: 'Contact Information',
                        icon: Icons.contact_page,
                        children: [
                          _buildInfoTile(
                            icon: Icons.email_rounded,
                            title: 'Email',
                            value: data['email'] ?? '',
                          ),
                          Divider(height: 20),
                          _buildInfoTile(
                            icon: Icons.phone_rounded,
                            title: 'Phone',
                            value: data['contact'] ?? '',
                          ),
                        ],
                      ),
                      
                      SizedBox(height: 16),
                      
                      // Member Since Card
                      _buildCard(
                        title: 'Member Since',
                        icon: Icons.calendar_today,
                        children: [
                          Text(
                            data['createdAt'] != null ? _formatDate(data['createdAt'].toString()) : 'N/A',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                      
                      SizedBox(height: 16),
                      
                      // Superadmin Contacts Card
                      _buildCard(
                        title: 'Superadmin Contacts',
                        icon: Icons.admin_panel_settings,
                        children: [
                          FutureBuilder<List<String>>(
                            future: _loadSuperadminContacts(),
                            builder: (context, csnap) {
                              if (!csnap.hasData) return BloodBridgeLoader(size: 30);
                              final contacts = csnap.data!;
                              if (contacts.isEmpty)
                                return Text(
                                  'No contacts configured',
                                  style: TextStyle(color: Colors.grey[600]),
                                );
                              return Column(
                                children: contacts
                                    .map((c) => Padding(
                                          padding: const EdgeInsets.only(bottom: 12.0),
                                          child: Row(
                                            children: [
                                              Icon(Icons.phone, color: Colors.red[400], size: 20),
                                              SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  c,
                                                  style: TextStyle(fontSize: 16),
                                                ),
                                              ),
                                              IconButton(
                                                icon: Icon(Icons.copy, size: 20),
                                                onPressed: () {
                                                  Clipboard.setData(ClipboardData(text: c));
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(content: Text('Copied $c')),
                                                  );
                                                },
                                              ),
                                              IconButton(
                                                icon: Icon(Icons.call, color: Colors.green, size: 20),
                                                onPressed: () async {
                                                  final uri = Uri.parse('tel:$c');
                                                  try {
                                                    await launchUrl(uri);
                                                  } catch (_) {}
                                                },
                                              ),
                                            ],
                                          ),
                                        ))
                                    .toList(),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
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
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.red[400], size: 24),
              ),
              SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoTile({required IconData icon, required String title, required String value}) {
    return Row(
      children: [
        Icon(icon, color: Colors.red[400], size: 20),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
        ),
      ],
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
      } catch (_) { return <String>[]; }
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('superadmin_contacts') ?? <String>[];
  }
}
