import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/firebase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../widgets/blood_bridge_loader.dart';

class RecipientListScreen extends StatefulWidget {
  const RecipientListScreen({super.key});

  @override
  _RecipientListScreenState createState() => _RecipientListScreenState();
}

class _RecipientListScreenState extends State<RecipientListScreen> {
  String? _currentEmail;
  String? _currentRole;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Recipients',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1E4E79), Color(0xFF2F6B9A), Color(0xFF5C8DB6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: FirebaseService.initialized ? _buildFirebaseList() : _buildDemoList(),
      ),
    );
  }

  Widget _buildFirebaseList() {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'recipient').get(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: BloodBridgeLoader());
        final docs = snap.data!.docs;
        if (docs.isEmpty) return const Center(child: Text('No recipients yet'));
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final d = docs[i];
            final data = d.data() as Map<String, dynamic>;

            Widget avatar() {
              final img = _imageFromBase64(data['photoData'] as String?);
              final n = (data['name'] ?? '') as String? ?? '';
              if (img != null) {
                return Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Color(0xFFB6C8DB), width: 2),
                    image: DecorationImage(image: img, fit: BoxFit.cover),
                  ),
                );
              }
              return Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Color(0xFFE8EEF6),
                  shape: BoxShape.circle,
                  border: Border.all(color: Color(0xFFB6C8DB), width: 2),
                ),
                child: Center(
                  child: Text(
                    n.isNotEmpty ? n[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E4E79),
                    ),
                  ),
                ),
              );
            }

            final urgency = data['urgency']?.toString().toLowerCase() ?? 'normal';
            final urgencyColor = urgency == 'critical' ? Colors.red : urgency == 'high' ? Colors.orange : Colors.green;

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.white, Color(0xFFF6F9FC)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF1E4E79).withOpacity(0.08),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    avatar(),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['name'] ?? 'No name',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Colors.red.shade400, Colors.red.shade600],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.water_drop, size: 14, color: Colors.white),
                                    SizedBox(width: 4),
                                    Text(
                                      '${data['bloodGroup'] ?? 'Unknown'}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: urgencyColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: urgencyColor, width: 1.5),
                                ),
                                child: Text(
                                  urgency.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: urgencyColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (data['contact'] != null && data['contact'].toString().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.phone, size: 16, color: Colors.blue.shade600),
                                SizedBox(width: 6),
                                Text(
                                  '${data['contact']}',
                                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                                ),
                              ],
                            ),
                          ],
                          if (data['designation'] != null && data['designation'].toString().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.work, size: 16, color: Colors.grey.shade600),
                                SizedBox(width: 6),
                                Text(
                                  '${data['designation']}',
                                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
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

  Widget _buildDemoList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _loadDemoRecipients(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: BloodBridgeLoader());
        final recipients = snap.data!;
        if (recipients.isEmpty) return const Center(child: Text('No recipients yet'));
        return ListView.builder(
          itemCount: recipients.length,
          itemBuilder: (context, i) {
            final data = recipients[i];

            Widget avatar() {
              final img = _imageFromBase64(data['photoData'] as String?);
              final n = (data['name'] ?? '') as String? ?? '';
              if (img != null) {
                return Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Color(0xFFB6C8DB), width: 2),
                    image: DecorationImage(image: img, fit: BoxFit.cover),
                  ),
                );
              }
              return Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Color(0xFFE8EEF6),
                  shape: BoxShape.circle,
                  border: Border.all(color: Color(0xFFB6C8DB), width: 2),
                ),
                child: Center(
                  child: Text(
                    n.isNotEmpty ? n[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E4E79),
                    ),
                  ),
                ),
              );
            }

            final urgency = data['urgency']?.toString().toLowerCase() ?? 'normal';
            final urgencyColor = urgency == 'critical' ? Colors.red : urgency == 'high' ? Colors.orange : Colors.green;

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.white, Color(0xFFF6F9FC)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF1E4E79).withOpacity(0.08),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    avatar(),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['name'] ?? 'No name',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Colors.red.shade400, Colors.red.shade600],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.water_drop, size: 14, color: Colors.white),
                                    SizedBox(width: 4),
                                    Text(
                                      '${data['bloodGroup'] ?? 'Unknown'}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: urgencyColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: urgencyColor, width: 1.5),
                                ),
                                child: Text(
                                  urgency.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: urgencyColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (data['contact'] != null && data['contact'].toString().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.phone, size: 16, color: Colors.blue.shade600),
                                SizedBox(width: 6),
                                Text(
                                  '${data['contact']}',
                                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                                ),
                              ],
                            ),
                          ],
                          if (data['designation'] != null && data['designation'].toString().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.work, size: 16, color: Colors.grey.shade600),
                                SizedBox(width: 6),
                                Text(
                                  '${data['designation']}',
                                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
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

  Future<List<Map<String, dynamic>>> _loadDemoRecipients() async {
    final prefs = await SharedPreferences.getInstance();
    final users = prefs.getStringList('demo_users') ?? <String>[];
    final recipients = <Map<String, dynamic>>[];
    for (final s in users) {
      try {
        final Map<String, dynamic> u = jsonDecode(s);
        if ((u['role'] ?? '') == 'recipient') {
          recipients.add(u);
        }
      } catch (_) {}
    }
    return recipients;
  }
}
