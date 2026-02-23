import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/firebase_service.dart';
import '../../widgets/blood_bridge_loader.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> currentData;
  
  const EditProfileScreen({super.key, required this.currentData});

  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtl;
  late TextEditingController _contactCtl;
  late TextEditingController _designationCtl;
  late TextEditingController _ageCtl;
  late TextEditingController _locationCtl;
  late String _gender;

  final List<String> _genders = ['Male', 'Female', 'Other'];

  @override
  void initState() {
    super.initState();
    _nameCtl = TextEditingController(text: widget.currentData['name'] ?? '');
    _contactCtl = TextEditingController(text: widget.currentData['contact'] ?? '');
    _designationCtl = TextEditingController(text: widget.currentData['designation'] ?? '');
    _ageCtl = TextEditingController(text: widget.currentData['age']?.toString() ?? '');
    _locationCtl = TextEditingController(text: widget.currentData['location'] ?? '');
    _gender = widget.currentData['gender'] ?? 'Male';
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _contactCtl.dispose();
    _designationCtl.dispose();
    _ageCtl.dispose();
    _locationCtl.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameCtl.text.trim();
    final contact = _contactCtl.text.trim();
    final designation = _designationCtl.text.trim();
    final age = int.tryParse(_ageCtl.text.trim()) ?? 0;
    final location = _locationCtl.text.trim();

    if (name.isEmpty || contact.isEmpty || designation.isEmpty || age == 0 || location.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill all fields'), backgroundColor: Colors.red),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(child: BloodBridgeLoader()),
    );

    try {
      final updateData = {
        'name': name,
        'contact': contact,
        'designation': designation,
        'age': age,
        'gender': _gender,
        'location': location,
        // Include email and other essential fields if missing from document
        if (widget.currentData['email'] != null) 'email': widget.currentData['email'],
        if (widget.currentData['bloodGroup'] != null) 'bloodGroup': widget.currentData['bloodGroup'],
        if (widget.currentData['role'] != null) 'role': widget.currentData['role'],
      };

      if (FirebaseService.initialized) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          // Add email from auth if not in current data
          if (user.email != null && widget.currentData['email'] == null) {
            updateData['email'] = user.email!;
          }
          
          // Use set with merge to create document if it doesn't exist
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set(updateData, SetOptions(merge: true));
          print('✅ Profile updated in Firestore');
        }
      } else {
        // Update demo user in SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        final currentEmail = prefs.getString('demo_current_email');
        final list = prefs.getStringList('demo_users') ?? <String>[];
        
        if (currentEmail != null) {
          final updatedList = <String>[];
          for (final s in list) {
            final Map<String, dynamic> u = jsonDecode(s);
            if ((u['email'] ?? '') == currentEmail) {
              u.addAll(updateData);
            }
            updatedList.add(jsonEncode(u));
          }
          await prefs.setStringList('demo_users', updatedList);
        }
      }

      Navigator.of(context).pop(); // Close loading dialog
      Navigator.of(context).pop(true); // Return to profile with success
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Profile updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update profile: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Profile'),
        backgroundColor: Colors.red[700],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.red[50]!, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTextField(
                  controller: _nameCtl,
                  label: 'Full Name',
                  icon: Icons.person_outline,
                  validator: (v) => v!.isEmpty ? 'Name is required' : null,
                ),
                SizedBox(height: 16),
                
                _buildTextField(
                  controller: _contactCtl,
                  label: 'Phone Number',
                  icon: Icons.phone_android,
                  keyboardType: TextInputType.phone,
                  validator: (v) => v!.isEmpty ? 'Phone number is required' : null,
                ),
                SizedBox(height: 16),
                
                _buildTextField(
                  controller: _designationCtl,
                  label: 'Designation/Occupation',
                  icon: Icons.work_outline,
                  validator: (v) => v!.isEmpty ? 'Designation is required' : null,
                ),
                SizedBox(height: 16),
                
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _ageCtl,
                        label: 'Age',
                        icon: Icons.cake_outlined,
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v!.isEmpty) return 'Age is required';
                          final age = int.tryParse(v);
                          if (age == null || age < 1 || age > 120) {
                            return 'Enter valid age';
                          }
                          return null;
                        },
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: _buildDropdown(
                        value: _gender,
                        label: 'Gender',
                        icon: Icons.wc,
                        items: _genders,
                        onChanged: (v) => setState(() => _gender = v!),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                
                _buildTextField(
                  controller: _locationCtl,
                  label: 'Location',
                  icon: Icons.location_on,
                  validator: (v) => v!.isEmpty ? 'Location is required' : null,
                ),
                SizedBox(height: 30),
                
                ElevatedButton(
                  onPressed: _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[700],
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 3,
                  ),
                  child: Text(
                    'Save Changes',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.red[700]),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.red[700]!, width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required String label,
    required IconData icon,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.red[700]),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.red[700]!, width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        items: items.map((item) {
          return DropdownMenuItem(value: item, child: Text(item));
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }
}
