import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../services/firebase_service.dart';
import '../../widgets/blood_bridge_loader.dart';

class DonorsDetailScreen extends StatefulWidget {
  const DonorsDetailScreen({super.key});

  @override
  _DonorsDetailScreenState createState() => _DonorsDetailScreenState();
}

class _DonorsDetailScreenState extends State<DonorsDetailScreen> {
  List<Map<String, dynamic>> _donors = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedBloodGroup = '';
  String _selectedLocation = '';
  bool _showApprovedOnly = true;

  final List<String> _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

  @override
  void initState() {
    super.initState();
    _loadDonors();
  }

  Future<void> _loadDonors() async {
    setState(() => _isLoading = true);

    if (FirebaseService.initialized) {
      await _loadFirebaseDonors();
    } else {
      await _loadDemoDonors();
    }

    setState(() => _isLoading = false);
  }

  Future<void> _loadFirebaseDonors() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'donor')
          .get();

      _donors = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('Error loading Firebase donors: $e');
    }
  }

  Future<void> _loadDemoDonors() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final users = prefs.getStringList('demo_users') ?? <String>[];

      _donors = users.map((userStr) {
        try {
          final user = jsonDecode(userStr) as Map<String, dynamic>;
          return user['role'] == 'donor' ? user : null;
        } catch (_) {
          return null;
        }
      }).where((user) => user != null).cast<Map<String, dynamic>>().toList();
    } catch (e) {
      print('Error loading demo donors: $e');
    }
  }

  List<Map<String, dynamic>> get _filteredDonors {
    var filtered = _donors;

    // Filter by approved status
    if (_showApprovedOnly) {
      filtered = filtered.where((donor) {
        return donor['approved'] == true;
      }).toList();
    }

    // Filter by blood group
    if (_selectedBloodGroup.isNotEmpty) {
      filtered = filtered.where((donor) {
        return (donor['bloodGroup'] ?? '').toString() == _selectedBloodGroup;
      }).toList();
    }

    // Filter by location
    if (_selectedLocation.isNotEmpty) {
      filtered = filtered.where((donor) {
        return (donor['location'] ?? '').toString().toLowerCase().contains(_selectedLocation.toLowerCase());
      }).toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((donor) {
        final name = (donor['name'] ?? '').toString().toLowerCase();
        final email = (donor['email'] ?? '').toString().toLowerCase();
        final bloodGroup = (donor['bloodGroup'] ?? '').toString().toLowerCase();
        final location = (donor['location'] ?? '').toString().toLowerCase();
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
      backgroundColor: Color(0xFFF5F0FF),
      appBar: AppBar(
        title: Text('All Donors'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            color: Colors.white,
            padding: EdgeInsets.all(16),
            child: TextField(
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
              decoration: InputDecoration(
                hintText: 'Search by name, blood type, city...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: Icon(Icons.search, color: Colors.grey),
                suffixIcon: Icon(Icons.mic, color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
            ),
          ),

          // Filter Chips
          Container(
            color: Colors.white,
            padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
            height: 60,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                // Filter button
                _buildFilterChip(
                  icon: Icons.filter_list,
                  label: 'Filter',
                  color: Color(0xFFFFE8D6),
                  textColor: Color(0xFFFF9F5A),
                  onTap: () {
                    _showAllFilters();
                  },
                ),
                SizedBox(width: 8),
                // Blood Type filter
                _buildFilterChip(
                  icon: Icons.bloodtype,
                  label: _selectedBloodGroup.isEmpty ? 'Blood Type' : _selectedBloodGroup,
                  color: Color(0xFFFFE4E9),
                  textColor: Color(0xFFE91E63),
                  selected: _selectedBloodGroup.isNotEmpty,
                  onTap: () {
                    _showBloodTypeFilter();
                  },
                ),
                SizedBox(width: 8),
                // Location filter
                _buildFilterChip(
                  icon: Icons.location_on,
                  label: _selectedLocation.isEmpty ? 'Location' : _selectedLocation,
                  color: Color(0xFFE3E8FF),
                  textColor: Color(0xFF5C6BC0),
                  selected: _selectedLocation.isNotEmpty,
                  onTap: () {
                    _showLocationFilter();
                  },
                ),
                SizedBox(width: 8),
                // Approved filter
                _buildFilterChip(
                  icon: Icons.check_circle,
                  label: 'Approved',
                  color: Color(0xFFD4F4E7),
                  textColor: Color(0xFF26A69A),
                  selected: _showApprovedOnly,
                  onTap: () {
                    setState(() => _showApprovedOnly = !_showApprovedOnly);
                  },
                ),
              ],
            ),
          ),

          // Donors List
          Expanded(
            child: _isLoading
                ? Center(child: BloodBridgeLoader())
                : _filteredDonors.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.bloodtype, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'No donors found',
                              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.all(16),
                        itemCount: _filteredDonors.length,
                        itemBuilder: (context, index) {
                          final donor = _filteredDonors[index];
                          return _buildDonorCard(donor);
                        },
                      ),
          ),


        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Add donor action
        },
        backgroundColor: Colors.red,
        icon: Icon(Icons.bloodtype, color: Colors.white),
        label: Text('Add Donor', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildFilterChip({
    required IconData icon,
    required String label,
    required Color color,
    required Color textColor,
    bool selected = false,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : color.withOpacity(0.3),
          borderRadius: BorderRadius.circular(20),
          border: selected ? Border.all(color: textColor, width: 2) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: textColor),
            SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAllFilters() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Filter Options',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedBloodGroup = '';
                            _selectedLocation = '';
                            _showApprovedOnly = true;
                          });
                          Navigator.pop(context);
                        },
                        child: Text('Clear All', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  
                  // Approved Only Toggle
                  SwitchListTile(
                    title: Text('Show Approved Only'),
                    value: _showApprovedOnly,
                    activeColor: Colors.green,
                    onChanged: (value) {
                      setModalState(() => _showApprovedOnly = value);
                      setState(() => _showApprovedOnly = value);
                    },
                  ),
                  
                  Divider(),
                  SizedBox(height: 8),
                  
                  Text('Blood Type', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildQuickBloodTypeChip('All', setModalState),
                      ..._bloodGroups.map((bg) => _buildQuickBloodTypeChip(bg, setModalState)),
                    ],
                  ),
                  
                  SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text('Apply Filters', style: TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildQuickBloodTypeChip(String bloodType, StateSetter setModalState) {
    final isSelected = bloodType == 'All' 
        ? _selectedBloodGroup.isEmpty 
        : _selectedBloodGroup == bloodType;
    
    return InkWell(
      onTap: () {
        setModalState(() {
          _selectedBloodGroup = bloodType == 'All' ? '' : bloodType;
        });
        setState(() {
          _selectedBloodGroup = bloodType == 'All' ? '' : bloodType;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.red : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          bloodType,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _showBloodTypeFilter() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Blood Type',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildBloodTypeOption('All'),
                  ..._bloodGroups.map((bg) => _buildBloodTypeOption(bg)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBloodTypeOption(String bloodType) {
    final isSelected = bloodType == 'All' 
        ? _selectedBloodGroup.isEmpty 
        : _selectedBloodGroup == bloodType;
    
    return InkWell(
      onTap: () {
        setState(() {
          _selectedBloodGroup = bloodType == 'All' ? '' : bloodType;
        });
        Navigator.pop(context);
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.red : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          bloodType,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _showLocationFilter() {
    final TextEditingController controller = TextEditingController(text: _selectedLocation);
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Filter by Location'),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: 'e.g., Lahore, Karachi, Islamabad',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              prefixIcon: Icon(Icons.location_on, color: Colors.blue),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() => _selectedLocation = '');
                Navigator.pop(context);
              },
              child: Text('Clear', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() => _selectedLocation = controller.text.trim());
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: Text('Apply', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDonorCard(Map<String, dynamic> donor) {
    final name = donor['name'] ?? 'Unknown';
    final email = donor['email'] ?? '';
    final bloodGroup = donor['bloodGroup'] ?? 'N/A';
    final contact = donor['contact'] ?? 'N/A';
    final location = donor['location'] ?? 'N/A';
    final approved = donor['approved'] == true;
    final photoData = donor['photoData'];

    // Get initials for avatar
    String getInitials(String name) {
      if (name.isEmpty) return 'U';
      final parts = name.trim().split(' ');
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      }
      return name[0].toUpperCase();
    }

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            // Avatar Circle
            CircleAvatar(
              radius: 30,
              backgroundColor: Color(0xFFE3E8FF),
              backgroundImage: photoData != null ? MemoryImage(base64Decode(photoData)) : null,
              child: photoData == null 
                ? Text(
                    getInitials(name),
                    style: TextStyle(
                      color: Color(0xFF5C6BC0),
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
            ),
            SizedBox(width: 16),
            
            // Donor Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        bloodGroup,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.red,
                        ),
                      ),
                      Text(
                        ' • ',
                        style: TextStyle(color: Colors.grey),
                      ),
                      Expanded(
                        child: Text(
                          location,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        ' • ',
                        style: TextStyle(color: Colors.grey),
                      ),
                      Text(
                        approved ? 'Approved' : 'Pending',
                        style: TextStyle(
                          fontSize: 14,
                          color: approved ? Colors.green : Colors.orange,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Approved',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 12),
            
            // Badges and Button Column
            Column(
              children: [
                // Donor Badge
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Color(0xFFFFE4E9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Donor',
                    style: TextStyle(
                      color: Color(0xFFE91E63),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(height: 8),
                // Contact Button
                ElevatedButton(
                  onPressed: () {
                    _showDonorDetails(donor);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFFF7043),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    elevation: 2,
                  ),
                  child: Text(
                    'Contact',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
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

  void _showDonorDetails(Map<String, dynamic> donor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final name = donor['name'] ?? 'Unknown';
        final email = donor['email'] ?? '';
        final bloodGroup = donor['bloodGroup'] ?? 'N/A';
        final contact = donor['contact'] ?? 'N/A';
        final location = donor['location'] ?? 'N/A';
        final lastDonation = donor['lastDonation'] ?? 'Never';
        final totalDonations = donor['totalDonations'] ?? 0;
        final availability = donor['availability'] ?? true;
        final age = donor['age'] ?? 'N/A';
        final gender = donor['gender'] ?? 'N/A';

        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              child: Container(
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
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.bloodtype, color: Colors.red, size: 32),
                              Text(
                                bloodGroup,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
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
                                  color: availability ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  availability ? 'Available' : 'Not Available',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: availability ? Colors.green : Colors.grey,
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
                    _buildDetailRow(Icons.favorite, 'Total Donations', '$totalDonations donations'),
                    _buildDetailRow(Icons.calendar_today, 'Last Donation', lastDonation.toString()),
                    _buildDetailRow(Icons.phone, 'Contact', contact),
                    _buildDetailRow(Icons.email, 'Email', email),
                    _buildDetailRow(Icons.location_on, 'Location', location),
                    _buildDetailRow(Icons.person, 'Age', age.toString()),
                    _buildDetailRow(Icons.wc, 'Gender', gender.toString()),

                    SizedBox(height: 24),

                    // Action Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Request sent to $name'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Send Request',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
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
            child: Icon(icon, size: 20, color: Colors.red),
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
