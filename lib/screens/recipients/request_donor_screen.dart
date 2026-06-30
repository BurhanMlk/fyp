import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../services/firebase_service.dart';
import '../../widgets/blood_bridge_loader.dart';
import '../../widgets/top_snackbar.dart';

class RequestDonorScreen extends StatefulWidget {
  const RequestDonorScreen({super.key});

  @override
  _RequestDonorScreenState createState() => _RequestDonorScreenState();
}

class _RequestDonorScreenState extends State<RequestDonorScreen> {
  String _selectedBloodGroup = 'All';
  String _searchLocation = '';
  List<Map<String, dynamic>> _donors = [];
  bool _isLoading = true;
  String _recipientName = '';
  String _recipientEmail = '';

  final List<String> _bloodTypes = ['All', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

  @override
  void initState() {
    super.initState();
    _loadRecipientInfo();
    _loadDonors();
  }

  Future<void> _loadRecipientInfo() async {
    if (FirebaseService.initialized) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists) {
          setState(() {
            _recipientName = doc.data()?['name'] ?? '';
            _recipientEmail = doc.data()?['email'] ?? user.email ?? '';
          });
        }
      }
    } else {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('demo_current_email') ?? '';
      final users = prefs.getStringList('demo_users') ?? [];
      for (final userStr in users) {
        try {
          final user = jsonDecode(userStr) as Map<String, dynamic>;
          if (user['email'] == email) {
            setState(() {
              _recipientName = user['name'] ?? '';
              _recipientEmail = email;
            });
            break;
          }
        } catch (_) {}
      }
    }
  }

  Future<void> _loadDonors() async {
    setState(() => _isLoading = true);
    List<Map<String, dynamic>> donors = [];

    if (FirebaseService.initialized) {
      try {
        Query query = FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'donor');
        
        // Filter by blood group if not "All"
        if (_selectedBloodGroup != 'All') {
          query = query.where('bloodGroup', isEqualTo: _selectedBloodGroup);
        }

        final snapshot = await query.get();
        
        for (final doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          
          // Filter by location if search text is provided
          if (_searchLocation.isNotEmpty) {
            final location = (data['location'] ?? '').toString().toLowerCase();
            if (!location.contains(_searchLocation.toLowerCase())) {
              continue;
            }
          }

          // Only show approved/verified donors
          if (data['approved'] == true || data['verified'] == true) {
            donors.add({
              'id': doc.id,
              'name': data['name'] ?? 'Unknown',
              'email': data['email'] ?? '',
              'bloodGroup': data['bloodGroup'] ?? 'N/A',
              'location': data['location'] ?? 'Not specified',
              'contact': data['contact'] ?? '',
              'lastDonation': data['lastDonation'],
              'verified': data['verified'] ?? false,
            });
          }
        }
      } catch (e) {
        print('Error loading donors: $e');
      }
    } else {
      // Demo mode
      final prefs = await SharedPreferences.getInstance();
      final users = prefs.getStringList('demo_users') ?? [];
      
      for (final userStr in users) {
        try {
          final user = jsonDecode(userStr) as Map<String, dynamic>;
          if (user['role'] == 'donor') {
            // Filter by blood group
            if (_selectedBloodGroup != 'All' && user['bloodGroup'] != _selectedBloodGroup) {
              continue;
            }
            
            // Filter by location
            if (_searchLocation.isNotEmpty) {
              final location = (user['location'] ?? '').toString().toLowerCase();
              if (!location.contains(_searchLocation.toLowerCase())) {
                continue;
              }
            }

            donors.add({
              'name': user['name'] ?? 'Unknown',
              'email': user['email'] ?? '',
              'bloodGroup': user['bloodGroup'] ?? 'N/A',
              'location': user['location'] ?? 'Not specified',
              'contact': user['contact'] ?? '',
              'lastDonation': user['lastDonation'],
              'verified': user['verified'] ?? false,
            });
          }
        } catch (_) {}
      }
    }

    setState(() {
      _donors = donors;
      _isLoading = false;
    });
  }

  void _sendRequest(Map<String, dynamic> donor) {
    final messageCtl = TextEditingController();
    final hospitalCtl = TextEditingController();
    final phoneCtl = TextEditingController();
    String urgency = 'Medium';
    DateTime? requiredDate;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.send, color: Colors.red[700]),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Request to ${donor['name']}',
                  style: TextStyle(fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Donor Info Card
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.red[100],
                          radius: 24,
                          child: Text(
                            donor['bloodGroup'],
                            style: TextStyle(
                              color: Colors.red[700],
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                donor['name'],
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              Text(
                                donor['location'],
                                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),
                  
                  // Hospital/Location
                  TextField(
                    controller: hospitalCtl,
                    decoration: InputDecoration(
                      labelText: 'Hospital/Location *',
                      prefixIcon: Icon(Icons.local_hospital, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  SizedBox(height: 12),
                  
                  // Contact Phone
                  TextField(
                    controller: phoneCtl,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Your Contact Phone *',
                      prefixIcon: Icon(Icons.phone, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  SizedBox(height: 12),
                  
                  // Urgency
                  DropdownButtonFormField<String>(
                    value: urgency,
                    decoration: InputDecoration(
                      labelText: 'Urgency Level',
                      prefixIcon: Icon(Icons.priority_high, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: ['Low', 'Medium', 'High', 'Critical'].map((u) => 
                      DropdownMenuItem(value: u, child: Text(u))
                    ).toList(),
                    onChanged: (v) => setDialogState(() => urgency = v!),
                  ),
                  SizedBox(height: 12),
                  
                  // Required Date
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: requiredDate ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(Duration(days: 90)),
                      );
                      if (picked != null) {
                        setDialogState(() => requiredDate = picked);
                      }
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[400]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, size: 20, color: Colors.grey[700]),
                          SizedBox(width: 12),
                          Text(
                            requiredDate == null
                                ? 'Select Required Date *'
                                : '${requiredDate!.day}/${requiredDate!.month}/${requiredDate!.year}',
                            style: TextStyle(
                              fontSize: 14,
                              color: requiredDate == null ? Colors.grey[600] : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  
                  // Message
                  TextField(
                    controller: messageCtl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Message *',
                      hintText: 'Describe your need...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: EdgeInsets.all(12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                final hospital = hospitalCtl.text.trim();
                final phone = phoneCtl.text.trim();
                final message = messageCtl.text.trim();

                if (hospital.isEmpty || phone.isEmpty || message.isEmpty || requiredDate == null) {
                  showTopSnackBar(context, message: 'Please fill all required fields', backgroundColor: Colors.red.shade700);
                  return;
                }

                await _submitRequest(donor, hospital, phone, message, urgency, requiredDate!);
                Navigator.pop(context);
              },
              icon: Icon(Icons.send, size: 18),
              label: Text('Send Request'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[700],
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitRequest(
    Map<String, dynamic> donor,
    String hospital,
    String phone,
    String message,
    String urgency,
    DateTime requiredDate,
  ) async {
    final request = {
      'donorEmail': donor['email'],
      'donorName': donor['name'],
      'recipientEmail': _recipientEmail,
      'recipientName': _recipientName,
      'bloodGroup': donor['bloodGroup'],
      'hospital': hospital,
      'recipientPhone': phone,
      'message': message,
      'urgency': urgency,
      'requiredDate': requiredDate.toIso8601String(),
      'status': 'pending',
      'requestedAt': DateTime.now().toIso8601String(),
    };

    if (FirebaseService.initialized) {
      try {
        await FirebaseFirestore.instance.collection('donor_requests').add(request);
        
        // Send notification message to donor
        final conversationId = 'conv_${donor['email'].toString().replaceAll('.', '_').replaceAll('@', '_at_')}_${_recipientEmail.replaceAll('.', '_').replaceAll('@', '_at_')}';
        await FirebaseFirestore.instance.collection('messages').add({
          'conversationId': conversationId,
          'from': _recipientEmail,
          'to': donor['email'],
          'message': 'Blood Donation Request: $message\nHospital: $hospital\nUrgency: $urgency\nRequired Date: ${requiredDate.day}/${requiredDate.month}/${requiredDate.year}',
          'sentAt': Timestamp.now(),
          'type': 'request',
          'read': false,
          'userRole': 'recipient',
        });

        showTopSnackBar(context, message: 'Request sent to ${donor['name']}!', backgroundColor: Colors.red.shade700);
      } catch (e) {
        showTopSnackBar(context, message: 'Error: $e', backgroundColor: Colors.red);
      }
    } else {
      // Demo mode
      final prefs = await SharedPreferences.getInstance();
      final requests = prefs.getStringList('donor_requests') ?? [];
      requests.add(jsonEncode(request));
      await prefs.setStringList('donor_requests', requests);

      showTopSnackBar(context, message: 'Request sent (Demo mode)!', backgroundColor: Colors.red.shade700);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Request for Donor',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.red.shade700, Colors.red.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFF5F5), Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            // Search Filters
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Blood Group Filter
                  Row(
                    children: [
                      Icon(Icons.bloodtype, color: Colors.red[700], size: 20),
                      SizedBox(width: 8),
                      Text('Blood Group:', style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedBloodGroup,
                          isExpanded: true,
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          items: _bloodTypes.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                          onChanged: (v) {
                            setState(() => _selectedBloodGroup = v!);
                            _loadDonors();
                          },
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  
                  // Location Search
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search by location...',
                      prefixIcon: Icon(Icons.location_on, color: Colors.red[700]),
                      suffixIcon: IconButton(
                        icon: Icon(Icons.search),
                        onPressed: _loadDonors,
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onChanged: (v) => _searchLocation = v,
                    onSubmitted: (v) => _loadDonors(),
                  ),
                ],
              ),
            ),
            
            // Donors List
            Expanded(
              child: _isLoading
                  ? Center(child: BloodBridgeLoader())
                  : _donors.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person_off, size: 64, color: Colors.grey[300]),
                              SizedBox(height: 16),
                              Text(
                                'No donors found',
                                style: TextStyle(color: Colors.grey[600], fontSize: 16),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Try changing filters',
                                style: TextStyle(color: Colors.grey[400], fontSize: 14),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadDonors,
                          child: ListView.builder(
                            padding: EdgeInsets.all(16),
                            itemCount: _donors.length,
                            itemBuilder: (context, i) {
                              final donor = _donors[i];
                              return Card(
                                elevation: 2,
                                margin: EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          // Blood Group Badge
                                          Container(
                                            width: 50,
                                            height: 50,
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [Colors.red[400]!, Colors.red[600]!],
                                              ),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Center(
                                              child: Text(
                                                donor['bloodGroup'],
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 16),
                                          
                                          // Donor Info
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        donor['name'],
                                                        style: TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 16,
                                                        ),
                                                      ),
                                                    ),
                                                    if (donor['verified'])
                                                      Icon(Icons.verified, color: Colors.blue, size: 18),
                                                  ],
                                                ),
                                                SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                                                    SizedBox(width: 4),
                                                    Expanded(
                                                      child: Text(
                                                        donor['location'],
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          color: Colors.grey[700],
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 12),
                                      
                                      // Request Button
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          onPressed: () => _sendRequest(donor),
                                          icon: Icon(Icons.send, size: 18),
                                          label: Text('Send Request'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red[700],
                                            foregroundColor: Colors.white,
                                            padding: EdgeInsets.symmetric(vertical: 12),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
