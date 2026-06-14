import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/animated_blood_bg.dart';
import '../../widgets/blood_bridge_loader.dart';
import '../../theme.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtl = TextEditingController();
  final _emailCtl = TextEditingController();
  final _passCtl = TextEditingController();
  final _contactCtl = TextEditingController();
  final _cnicCtl = TextEditingController();
  final _designationCtl = TextEditingController();
  final _ageCtl = TextEditingController();
  final _locationCtl = TextEditingController();
  String _bloodGroup = 'A+';
  String _role = 'donor'; // 'donor' or 'recipient'
  String _gender = 'Male';
  int _currentStep = 0;
  bool _isSubmitting = false;

  final List<String> _bloodTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
  final List<String> _genders = ['Male', 'Female', 'Other'];

  String _formatCNIC(String input) {
    // Remove all non-digit characters
    final digits = input.replaceAll(RegExp(r'\D'), '');
    
    // Limit to 13 digits
    if (digits.length > 13) {
      return _formatCNIC(digits.substring(0, 13));
    }
    
    // Format: XXXXX-XXXXXXX-X
    if (digits.length <= 5) {
      return digits;
    } else if (digits.length <= 12) {
      return '${digits.substring(0, 5)}-${digits.substring(5)}';
    } else {
      return '${digits.substring(0, 5)}-${digits.substring(5, 12)}-${digits.substring(12)}';
    }
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _emailCtl.dispose();
    _passCtl.dispose();
    _contactCtl.dispose();
    _cnicCtl.dispose();
    _designationCtl.dispose();
    _ageCtl.dispose();
    _locationCtl.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.red.shade700,
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          top: 16,
          right: 16,
          left: MediaQuery.of(context).size.width * 0.5,
          bottom: MediaQuery.of(context).size.height - 130,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.green.shade700,
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          top: 16,
          right: 16,
          left: MediaQuery.of(context).size.width * 0.5,
          bottom: MediaQuery.of(context).size.height - 130,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  bool _isValidEmail(String email) => email.contains('@');

  bool _isValidCnic(String cnic) {
    return RegExp(r'^\d{5}-\d{7}-\d$|^\d{13}$').hasMatch(cnic);
  }

  bool _validateCurrentStep() {
    final name = _nameCtl.text.trim();
    final designation = _designationCtl.text.trim();
    final email = _emailCtl.text.trim();
    final pass = _passCtl.text;
    final contact = _contactCtl.text.trim();
    final cnic = _cnicCtl.text.trim();
    final age = _ageCtl.text.trim();
    final location = _locationCtl.text.trim();

    if (_currentStep == 0) {
      if (name.isEmpty) {
        _showError('Please enter your name');
        return false;
      }
      if (designation.isEmpty) {
        _showError('Please enter your designation');
        return false;
      }
      if (age.isEmpty) {
        _showError('Please enter your age');
        return false;
      }
      final parsedAge = int.tryParse(age);
      if (parsedAge == null || parsedAge < 18 || parsedAge > 65) {
        _showError('Age must be between 18 and 65');
        return false;
      }
      return true;
    }

    if (_currentStep == 1) {
      if (email.isEmpty) {
        _showError('Please enter your email address');
        return false;
      }
      if (!_isValidEmail(email)) {
        _showError('Please enter a valid email address');
        return false;
      }
      if (pass.isEmpty) {
        _showError('Please enter a password');
        return false;
      }
      if (pass.length < 6) {
        _showError('Password must be at least 6 characters');
        return false;
      }
      if (contact.isEmpty) {
        _showError('Please enter your contact number');
        return false;
      }
      if (cnic.isEmpty) {
        _showError('Please enter your CNIC');
        return false;
      }
      if (!_isValidCnic(cnic)) {
        _showError('CNIC must be in 12345-1234567-1 or 13-digit format');
        return false;
      }
      return true;
    }

    if (_currentStep == 2) {
      if (location.isEmpty) {
        _showError('Please enter your location');
        return false;
      }
      return true;
    }

    return false;
  }

  void _goNext() async {
    if (!_validateCurrentStep()) return;
    if (_currentStep < 2) {
      setState(() => _currentStep += 1);
    }
  }

  void _goBack() {
    if (_currentStep > 0) {
      setState(() => _currentStep -= 1);
    }
  }

  Future<void> _register() async {
    if (_isSubmitting) return;

    final name = _nameCtl.text.trim();
    final designation = _designationCtl.text.trim();
    final email = _emailCtl.text.trim();
    final pass = _passCtl.text;
    final contact = _contactCtl.text.trim();
    final cnic = _cnicCtl.text.trim();
    final blood = _bloodGroup;
    final age = _ageCtl.text.trim();
    final gender = _gender;
    final location = _locationCtl.text.trim();

    if (!_validateCurrentStep()) return;

    setState(() => _isSubmitting = true);
    showDialog(context: context, barrierDismissible: false, builder: (_) => Center(child: BloodBridgeLoader()));

    try {
      print('📝 Creating Firebase account for: $email');
      final cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: pass);

      final data = {
        'name': name,
        'email': email,
        'contact': contact,
        'cnic': cnic,
        'bloodGroup': blood,
        'role': _role,
        'designation': designation,
        'age': int.tryParse(age) ?? 0,
        'gender': gender,
        'location': location,
        'approved': (_role == 'donor') ? false : true,
        'createdAt': FieldValue.serverTimestamp(),
      };

      print('📊 User data being saved:');
      print('   Name: $name');
      print('   Email: $email');
      print('   Role: ${_role}');
      print('   Blood Group: $blood');

      await FirebaseFirestore.instance
          .collection('users')
          .doc(cred.user!.uid)
          .set(data);
      print('✅ User profile saved to Firestore: ${cred.user!.uid}');

      // Verify the role was saved correctly by reading it back
      final savedDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(cred.user!.uid)
          .get();
      final savedData = savedDoc.data();
      print('🔍 Verification - Role actually saved: ${savedData?['role']}');
      print('🔍 Verification - Expected role: ${_role}');
      
      if (savedData?['role'] != _role) {
        print('❌ ERROR: Role mismatch detected!');
        print('   Expected: ${_role}');
        print('   Actually saved: ${savedData?['role']}');
      } else {
        print('✅ Role saved correctly!');
      }

      await FirebaseAuth.instance.signOut();

      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        
        // Show success message at top right
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Account created successfully! Please login.', style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.green.shade700,
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(
              top: 16,
              right: 16,
              left: MediaQuery.of(context).size.width * 0.5,
              bottom: MediaQuery.of(context).size.height - 130,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        
        // Navigate to login screen
        await Future.delayed(Duration(milliseconds: 500));
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => LoginScreen()),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
      }
      print('❌ Registration Error: $e');
      if (mounted) {
        String errorMsg = 'Sign up failed: ${e.toString()}';
        if (e is FirebaseAuthException) {
          if (e.code == 'email-already-in-use') {
            errorMsg = 'This email is already registered. Please login instead.';
          } else if (e.code == 'invalid-email') {
            errorMsg = 'Invalid email address format.';
          } else if (e.code == 'weak-password') {
            errorMsg = 'Password is too weak. Use at least 6 characters.';
          }
        }
        _showError(errorMsg);
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    int maxLines = 1,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      style: TextStyle(color: Colors.black),
      keyboardType: keyboardType,
      obscureText: obscureText,
      maxLines: maxLines,
      onChanged: onChanged,
      onSubmitted: (_) {}, // Disable Enter key
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.black54),
        filled: false,
        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black.withOpacity(0.3))),
        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black)),
      ),
    );
  }

  Widget _buildStepIndicator() {
    final items = [
      ('1', 'Basic'),
      ('2', 'Contact'),
      ('3', 'Finish'),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: List.generate(items.length, (index) {
        final active = _currentStep >= index;
        final current = _currentStep == index;
        return Expanded(
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Left line
                  if (index != 0)
                    Expanded(
                      child: Container(
                        height: 2,
                        color: _currentStep >= index ? AppTheme.actionRed : Colors.black26,
                      ),
                    ),
                  // Circle
                  AnimatedContainer(
                    duration: Duration(milliseconds: 200),
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: active ? AppTheme.actionRed : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.actionRed, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        items[index].$1,
                        style: TextStyle(
                          color: active ? Colors.white : Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  // Right line
                  if (index != items.length - 1)
                    Expanded(
                      child: Container(
                        height: 2,
                        color: _currentStep > index ? AppTheme.actionRed : Colors.black26,
                      ),
                    ),
                ],
              ),
              SizedBox(height: 6),
              Text(
                items[index].$2,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: current ? FontWeight.w700 : FontWeight.w500,
                  color: current ? AppTheme.actionRed : Colors.black87,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildStepContent() {
    if (_currentStep == 0) {
      return Column(
        children: [
          _buildTextField(controller: _nameCtl, hintText: 'Full name'),
          SizedBox(height: 12),
          _buildTextField(controller: _designationCtl, hintText: 'Designation (e.g., Dr., Nurse, Student)'),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _ageCtl,
                  hintText: 'Age',
                  keyboardType: TextInputType.number,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _gender,
                  style: TextStyle(color: Colors.black),
                  dropdownColor: Colors.white,
                  decoration: InputDecoration(
                    hintText: 'Gender',
                    hintStyle: TextStyle(color: Colors.black54),
                    filled: false,
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black.withOpacity(0.3))),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black)),
                  ),
                  items: _genders.map((g) => DropdownMenuItem(value: g, child: Text(g, style: TextStyle(color: Colors.black)))).toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _gender = v);
                  },
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _role,
            style: TextStyle(color: Colors.black),
            dropdownColor: Colors.white,
            decoration: InputDecoration(
              hintText: 'Role',
              hintStyle: TextStyle(color: Colors.black54),
              filled: false,
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black.withOpacity(0.3))),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black)),
            ),
            items: const [
              DropdownMenuItem(value: 'donor', child: Text('Donor', style: TextStyle(color: Colors.black))),
              DropdownMenuItem(value: 'recipient', child: Text('Recipient', style: TextStyle(color: Colors.black))),
            ],
            onChanged: (v) => setState(() => _role = v ?? 'donor'),
          ),
        ],
      );
    }

    if (_currentStep == 1) {
      return Column(
        children: [
          _buildTextField(controller: _emailCtl, hintText: 'Email'),
          SizedBox(height: 12),
          _buildTextField(controller: _passCtl, hintText: 'Password', obscureText: true),
          SizedBox(height: 12),
          _buildTextField(controller: _contactCtl, hintText: 'Contact number', keyboardType: TextInputType.phone),
          SizedBox(height: 12),
          _buildTextField(
            controller: _cnicCtl,
            hintText: 'CNIC (12345-1234567-1)',
            keyboardType: TextInputType.number,
            onChanged: (value) {
              final formatted = _formatCNIC(value);
              if (formatted != value) {
                _cnicCtl.text = formatted;
                _cnicCtl.selection = TextSelection.fromPosition(TextPosition(offset: formatted.length));
              }
            },
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(controller: _locationCtl, hintText: 'Location/Address'),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _bloodGroup,
                style: TextStyle(color: Colors.black),
                dropdownColor: Colors.white,
                decoration: InputDecoration(
                  hintText: 'Blood group',
                  hintStyle: TextStyle(color: Colors.black54),
                  filled: false,
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black.withOpacity(0.3))),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black)),
                ),
                items: _bloodTypes.map((b) => DropdownMenuItem(value: b, child: Text(b, style: TextStyle(color: Colors.black)))).toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _bloodGroup = v);
                },
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Review', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black)),
              SizedBox(height: 8),
              Text('Name: ${_nameCtl.text.trim().isEmpty ? '-' : _nameCtl.text.trim()}'),
              Text('Email: ${_emailCtl.text.trim().isEmpty ? '-' : _emailCtl.text.trim()}'),
              Text('Role: ${_role == 'donor' ? 'Donor' : 'Recipient'}'),
              Text('Blood Group: $_bloodGroup'),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(color: Colors.transparent),
            ),
          ),
          Positioned.fill(child: AnimatedBloodBackground(cellCount: 10)),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 720),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.black, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Create Account', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
                      SizedBox(height: 8),
                      Text('Step ${_currentStep + 1} of 3', style: TextStyle(color: Colors.black87)),
                      SizedBox(height: 12),
                      _buildStepIndicator(),
                      SizedBox(height: 20),
                      _buildStepContent(),
                      SizedBox(height: 20),
                      Row(
                        children: [
                          if (_currentStep > 0)
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _isSubmitting ? null : _goBack,
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  foregroundColor: Colors.black,
                                  side: BorderSide(color: Colors.black, width: 2),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: Text('Back', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w600)),
                              ),
                            ),
                          if (_currentStep > 0) SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isSubmitting ? null : (_currentStep < 2 ? _goNext : _register),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: Colors.black,
                                side: BorderSide(color: Colors.black, width: 2),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: Text(
                                _currentStep < 2 ? 'Save & Next' : 'Create Account',
                                style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
