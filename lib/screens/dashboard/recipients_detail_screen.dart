import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../services/firebase_service.dart';
import '../../widgets/blood_bridge_loader.dart';

class RecipientsDetailScreen extends StatefulWidget {
  const RecipientsDetailScreen({super.key});

  @override
  _RecipientsDetailScreenState createState() => _RecipientsDetailScreenState();
}

class _RecipientsDetailScreenState extends State<RecipientsDetailScreen> {
  List<Map<String, dynamic>> _recipients = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedBloodGroup = 'All';

  final List<String> _bloodGroups = ['All', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

  @override
  void initState() {
    super.initState();
    _loadRecipients();
  }

  Future<void> _loadRecipients() async {
    setState(() => _isLoading = true);

    if (FirebaseService.initialized) {
      await _loadFirebaseRecipients();
    } else {
      await _loadDemoRecipients();
    }

    setState(() => _isLoading = false);
  }

  Future<void> _loadFirebaseRecipients() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'recipient')
          .get();

      _recipients = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('Error loading Firebase recipients: $e');
    }
  }

  Future<void> _loadDemoRecipients() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final users = prefs.getStringList('demo_users') ?? <String>[];

      _recipients = users.map((userStr) {
        try {
          final user = jsonDecode(userStr) as Map<String, dynamic>;
          return user['role'] == 'recipient' ? user : null;
        } catch (_) {
          return null;
        }
      }).where((user) => user != null).cast<Map<String, dynamic>>().toList();
    } catch (e) {
      print('Error loading demo recipients: $e');
    }
  }

  List<Map<String, dynamic>> get _filteredRecipients {
    var filtered = _recipients;

    // Filter by blood group
    if (_selectedBloodGroup != 'All') {
      filtered = filtered.where((recipient) {
        return (recipient['bloodGroup'] ?? '').toString() == _selectedBloodGroup;
      }).toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((recipient) {
        final name = (recipient['name'] ?? '').toString().toLowerCase();
        final email = (recipient['email'] ?? '').toString().toLowerCase();
        final bloodGroup = (recipient['bloodGroup'] ?? '').toString().toLowerCase();
        final location = (recipient['location'] ?? '').toString().toLowerCase();
        final query = _searchQuery.toLowerCase();

        return name.contains(query) || 
               email.contains(query) || 
               bloodGroup.contains(query) ||
               location.contains(query);
      }).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('All Recipients'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_filteredRecipients.length} Recipients',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: EdgeInsets.all(16),
            child: TextField(
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
              decoration: InputDecoration(
                hintText: 'Search recipients by name, location, blood group...',
                prefixIcon: Icon(Icons.search, color: Colors.black),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.black, width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.black, width: 2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.black, width: 2),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),

          // Blood Group Filter
          Container(
            height: 50,
            margin: EdgeInsets.only(bottom: 16),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 16),
              itemCount: _bloodGroups.length,
              itemBuilder: (context, index) {
                final bloodGroup = _bloodGroups[index];
                final isSelected = _selectedBloodGroup == bloodGroup;

                return Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(bloodGroup),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() => _selectedBloodGroup = bloodGroup);
                    },
                    backgroundColor: Colors.grey[200],
                    selectedColor: Colors.blue,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                );
              },
            ),
          ),

          // Recipients List
          Expanded(
            child: _isLoading
                ? Center(child: BloodBridgeLoader())
                : _filteredRecipients.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.local_hospital, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              _searchQuery.isEmpty && _selectedBloodGroup == 'All'
                                  ? 'No recipients found'
                                  : 'No recipients match your search',
                              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadRecipients,
                        color: Colors.blue,
                        child: ListView.builder(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filteredRecipients.length,
                          itemBuilder: (context, index) {
                            final recipient = _filteredRecipients[index];
                            return _buildRecipientCard(recipient);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipientCard(Map<String, dynamic> recipient) {
    final name = recipient['name'] ?? 'Unknown';
    final email = recipient['email'] ?? '';
    final bloodGroup = recipient['bloodGroup'] ?? 'N/A';
    final contact = recipient['contact'] ?? 'N/A';
    final location = recipient['location'] ?? 'N/A';
    final urgency = recipient['urgency'] ?? 'Normal';
    final reason = recipient['reason'] ?? 'Medical Emergency';

    Color urgencyColor;
    switch (urgency.toString().toLowerCase()) {
      case 'critical':
        urgencyColor = Colors.red;
        break;
      case 'urgent':
        urgencyColor = Colors.orange;
        break;
      default:
        urgencyColor = Colors.green;
    }

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      color: Colors.white.withOpacity(0.85),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.black, width: 2),
      ),
      child: InkWell(
        onTap: () {
          _showRecipientDetails(recipient);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Avatar with Blood Group
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.local_hospital, color: Colors.blue, size: 24),
                        Text(
                          bloodGroup,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 12),
                  
                  // Recipient Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                            SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                location,
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Urgency Badge
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: urgencyColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      urgency.toString().toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: urgencyColor,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              
              Divider(height: 1),
              SizedBox(height: 12),

              // Reason & Contact
              Row(
                children: [
                  Icon(Icons.medical_information, size: 14, color: Colors.grey[600]),
                  SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      reason,
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.phone, size: 14, color: Colors.grey[600]),
                        SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            contact,
                            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.email, size: 14, color: Colors.grey[600]),
                        SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            email,
                            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
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
      ),
    );
  }

  void _showRecipientDetails(Map<String, dynamic> recipient) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final name = recipient['name'] ?? 'Unknown';
        final email = recipient['email'] ?? '';
        final bloodGroup = recipient['bloodGroup'] ?? 'N/A';
        final contact = recipient['contact'] ?? 'N/A';
        final location = recipient['location'] ?? 'N/A';
        final urgency = recipient['urgency'] ?? 'Normal';
        final reason = recipient['reason'] ?? 'Medical Emergency';
        final age = recipient['age'] ?? 'N/A';
        final gender = recipient['gender'] ?? 'N/A';
        final hospital = recipient['hospital'] ?? 'N/A';
        final unitsNeeded = recipient['unitsNeeded'] ?? 1;

        Color urgencyColor;
        switch (urgency.toString().toLowerCase()) {
          case 'critical':
            urgencyColor = Colors.red;
            break;
          case 'urgent':
            urgencyColor = Colors.orange;
            break;
          default:
            urgencyColor = Colors.green;
        }

        return Container(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: 20),
              
              // Header
              Row(
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.local_hospital, color: Colors.blue, size: 32),
                        Text(
                          bloodGroup,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: urgencyColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            urgency.toString().toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: urgencyColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24),

              // Details
              _buildDetailRow(Icons.medical_information, 'Reason', reason),
              _buildDetailRow(Icons.water_drop, 'Units Needed', '$unitsNeeded units'),
              _buildDetailRow(Icons.local_hospital, 'Hospital', hospital),
              _buildDetailRow(Icons.phone, 'Contact', contact),
              _buildDetailRow(Icons.email, 'Email', email),
              _buildDetailRow(Icons.location_on, 'Location', location),
              _buildDetailRow(Icons.person, 'Age', age.toString()),
              _buildDetailRow(Icons.wc, 'Gender', gender.toString()),

              SizedBox(height: 24),

              // Action Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('You offered help to $name'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.black,
                    side: BorderSide(color: Colors.black, width: 2),
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    'Offer Help',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: Colors.blue),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
