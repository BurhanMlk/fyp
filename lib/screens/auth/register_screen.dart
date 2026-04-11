import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/firebase_service.dart';
import '../../widgets/animated_blood_bg.dart';
import '../../widgets/app_card.dart';
import '../../widgets/blood_bridge_loader.dart';
import '../../theme.dart';
// home_screen not needed here because we now redirect to LoginScreen after register
// profile screen not needed directly here (navigating to HomeScreen after register)
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
  final ImagePicker _picker = ImagePicker();
  Uint8List? _pickedBytes;

  final List<String> _bloodTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
  final List<String> _genders = ['Male', 'Female', 'Other'];

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

  void _register() {
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
  // availability and medical history removed per request

    // Validate all required fields with specific messages
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter your name'), backgroundColor: Colors.red, duration: Duration(seconds: 3))
      );
      return;
    }
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter your email address'), backgroundColor: Colors.red, duration: Duration(seconds: 3))
      );
      return;
    }
    if (!email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a valid email address'), backgroundColor: Colors.red, duration: Duration(seconds: 3))
      );
      return;
    }
    if (pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a password'), backgroundColor: Colors.red, duration: Duration(seconds: 3))
      );
      return;
    }
    if (pass.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password must be at least 6 characters'), backgroundColor: Colors.red, duration: Duration(seconds: 3))
      );
      return;
    }
    if (contact.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter your contact number'), backgroundColor: Colors.red, duration: Duration(seconds: 3))
      );
      return;
    }
    if (cnic.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter your CNIC'), backgroundColor: Colors.red, duration: Duration(seconds: 3))
      );
      return;
    }
    if (!RegExp(r'^\d{5}-\d{7}-\d$|^\d{13}$').hasMatch(cnic)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CNIC must be in 12345-1234567-1 or 13-digit format'), backgroundColor: Colors.red, duration: Duration(seconds: 3))
      );
      return;
    }
    if (designation.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter your designation'), backgroundColor: Colors.red, duration: Duration(seconds: 3))
      );
      return;
    }
    if (age.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter your age'), backgroundColor: Colors.red, duration: Duration(seconds: 3))
      );
      return;
    }
    if (int.tryParse(age) == null || int.parse(age) < 18 || int.parse(age) > 65) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Age must be between 18 and 65'), backgroundColor: Colors.red, duration: Duration(seconds: 3))
      );
      return;
    }
    if (location.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter your location'), backgroundColor: Colors.red, duration: Duration(seconds: 3))
      );
      return;
    }
    if (_pickedBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please upload your photo'), backgroundColor: Colors.red, duration: Duration(seconds: 3))
      );
      return;
    }

    showDialog(context: context, barrierDismissible: false, builder: (_) => Center(child: BloodBridgeLoader()));

  // photo is required for registration (validated above)
  final String photoData = base64Encode(_pickedBytes!);

    // If Firebase is available use it, otherwise save demo user locally so the UI demo works.
    print('🔍 Firebase initialized: ${FirebaseService.initialized}');
    if (FirebaseService.initialized) {
      print('📝 Creating Firebase account for: $email');
      FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: pass).then((cred) async {
        // Save profile to Firestore (build map conditionally)
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
        data['photoData'] = photoData;
        
        try {
          await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set(data);
          print('✅ User profile saved to Firestore: ${cred.user!.uid}');
        } catch (e) {
          print('❌ Profile save failed: $e');
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Account created but profile save failed: $e'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 5),
            ),
          );
          return;
        }

        // Sign out so user will need to login to see their profile
        await FirebaseAuth.instance.signOut();

        Navigator.of(context).pop();
        // Show a top banner informing the user the account was created, then navigate to Login
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Account created successfully! Please login to continue.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        Future.delayed(Duration(seconds: 3), () {
          Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => LoginScreen()));
        });
      }).catchError((e) {
        Navigator.of(context).pop();
        print('❌ Firebase Auth Error: $e');
        String errorMessage = 'Sign up failed: ';
        if (e.toString().contains('email-already-in-use')) {
          errorMessage = 'This email is already registered. Please login instead.';
        } else if (e.toString().contains('weak-password')) {
          errorMessage = 'Password is too weak. Please use at least 6 characters.';
        } else if (e.toString().contains('invalid-email')) {
          errorMessage = 'Invalid email format.';
        } else {
          errorMessage += e.toString();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      });
    } else {
      // Demo local save (including password for local login demo only)
      SharedPreferences.getInstance().then((prefs) async {
        final demo = {
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'name': name,
          'email': email,
          'password': pass,
          'contact': contact,
          'cnic': cnic,
          'bloodGroup': blood,
          'role': _role,
          'designation': designation,
          'age': int.tryParse(age) ?? 0,
          'gender': gender,
          'location': location,
          'photoData': photoData,
          'createdAt': DateTime.now().toIso8601String(),
          // donors require admin approval before recipients can access contact
          'approved': (_role == 'donor') ? false : true,
        };

        // Append to demo_users list (keeps registration sequence)
        final list = prefs.getStringList('demo_users') ?? <String>[];
        list.add(jsonEncode(demo));
        await prefs.setStringList('demo_users', list);

        // Do NOT auto-login in demo mode. Ask user to login to view their profile.
        Navigator.of(context).pop();
        // Show success message in demo flow
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Account created successfully! Please login to continue.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        Future.delayed(Duration(seconds: 2), () {
          Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => LoginScreen()));
        });
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      // Show dialog to choose between camera and gallery
      final ImageSource? source = await showDialog<ImageSource>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.black, width: 2),
          ),
          title: Text('Choose Photo Source'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.camera_alt, color: AppTheme.actionRed),
                title: Text('Camera'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: Icon(Icons.photo_library, color: AppTheme.actionRed),
                title: Text('Gallery'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );
      
      if (source == null) return;
      
      final xfile = await _picker.pickImage(source: source, maxWidth: 1200, maxHeight: 1200, imageQuality: 80);
      if (xfile == null) return;
      
      final bytes = await xfile.readAsBytes();
      
      // Accept any photo - face detection is optional
      setState(() {
        _pickedBytes = bytes;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ Photo uploaded successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog if open
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Image pick failed: ${e.toString()}')));
      }
    }
  }

  Future<bool> _validateHumanPhotoFromBytes(Uint8List bytes) async {
    try {
      // On web, ML Kit face detection may not work properly
      // For web, we'll skip ML Kit and just check if image is valid
      // In production, you should use a server-side face detection API
      print('⚠️ Web platform detected - Face detection limited on web');
      print('✅ Photo accepted (Web mode - server-side validation recommended)');
      return true; // Accept on web, but recommend server-side validation
      
    } catch (e) {
      print('❌ Face detection error: $e');
      return false;
    }
  }

  Future<bool> _validateHumanPhoto(String imagePath) async {
    try {
      // Create InputImage from file path
      final inputImage = InputImage.fromFilePath(imagePath);
      
      // Initialize face detector with flexible settings to accept faces from any angle
      final options = FaceDetectorOptions(
        enableClassification: false, // Disable classification for better flexibility
        enableTracking: false,
        minFaceSize: 0.05, // Lower minimum face size (5% of image) to accept faces from different distances/angles
        performanceMode: FaceDetectorMode.accurate, // Use accurate mode for better detection
      );
      final faceDetector = FaceDetector(options: options);
      
      // Detect faces
      final List<Face> faces = await faceDetector.processImage(inputImage);
      
      // Close the detector
      await faceDetector.close();
      
      // Validation: At least one face must be detected
      if (faces.isEmpty) {
        print('⚠️ No human face detected in the uploaded photo');
        return false; // No human face detected
      }
      
      print('✅ Human face detected successfully! Found ${faces.length} face(s)');
      return true; // Human face detected - any photo with human face is accepted!
      
    } catch (e) {
      print('❌ Face detection error: $e');
      // On error, reject the image for safety
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // static gradient background underneath the animated blood cells
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.transparent,
              ),
            ),
          ),
          // animated blood cells on top so their colors/effects remain visible
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
                        border: Border.all(color: Colors.grey.shade300, width: 1.5),
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
                      // Photo upload & preview
                      Text('Profile Photo *', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black)),
                      SizedBox(height: 8),
                      if (_pickedBytes != null)
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(shape: BoxShape.circle, image: DecorationImage(image: MemoryImage(_pickedBytes!), fit: BoxFit.cover)),
                        )
                      else
                        CircleAvatar(radius: 64, child: Icon(Icons.person, size: 64)),
                      SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _pickImage,
                            icon: Icon(Icons.upload_file),
                            label: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
                              child: Text('Upload Photo', style: TextStyle(fontSize: 16)),
                            ),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.black,
                              side: BorderSide(color: Colors.black, width: 2),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                          SizedBox(width: 8),
                          if (_pickedBytes != null)
                            TextButton(onPressed: () => setState(() { _pickedBytes = null; }), child: Text('Remove')),
                        ],
                      ),
                      SizedBox(height: 12),
                      Text('Create Account', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
                      SizedBox(height: 12),
                      // Name
                      TextField(
                        controller: _nameCtl,
                        style: TextStyle(color: Colors.black),
                        decoration: InputDecoration(
                          hintText: 'Full name',
                          hintStyle: TextStyle(color: Colors.black54),
                          filled: false,
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black.withOpacity(0.3))),
                          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black)),
                        ),
                      ),
                      SizedBox(height: 12),
                      // Designation
                      TextField(
                        controller: _designationCtl,
                        style: TextStyle(color: Colors.black),
                        decoration: InputDecoration(
                          hintText: 'Designation (e.g., Dr., Nurse, Student)',
                          hintStyle: TextStyle(color: Colors.black54),
                          filled: false,
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black.withOpacity(0.3))),
                          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black)),
                        ),
                      ),
                      SizedBox(height: 12),
                      // Age and Gender in one row
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _ageCtl,
                              style: TextStyle(color: Colors.black),
                              decoration: InputDecoration(
                                hintText: 'Age',
                                hintStyle: TextStyle(color: Colors.black54),
                                filled: false,
                                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black.withOpacity(0.3))),
                                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black)),
                              ),
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
                      // Email
                      TextField(
                        controller: _emailCtl,
                        style: TextStyle(color: Colors.black),
                        decoration: InputDecoration(
                          hintText: 'Email',
                          hintStyle: TextStyle(color: Colors.black54),
                          filled: false,
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black.withOpacity(0.3))),
                          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black)),
                        ),
                      ),
                      SizedBox(height: 12),
                      // Password
                      TextField(
                        controller: _passCtl,
                        style: TextStyle(color: Colors.black),
                        decoration: InputDecoration(
                          hintText: 'Password',
                          hintStyle: TextStyle(color: Colors.black54),
                          filled: false,
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black.withOpacity(0.3))),
                          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black)),
                        ),
                        obscureText: true,
                      ),
                      SizedBox(height: 12),
                      // Contact
                      TextField(
                        controller: _contactCtl,
                        style: TextStyle(color: Colors.black),
                        decoration: InputDecoration(
                          hintText: 'Contact number',
                          hintStyle: TextStyle(color: Colors.black54),
                          filled: false,
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black.withOpacity(0.3))),
                          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black)),
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      SizedBox(height: 12),
                      // CNIC
                      TextField(
                        controller: _cnicCtl,
                        style: TextStyle(color: Colors.black),
                        decoration: InputDecoration(
                          hintText: 'CNIC (12345-1234567-1)',
                          hintStyle: TextStyle(color: Colors.black54),
                          filled: false,
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black.withOpacity(0.3))),
                          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black)),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      SizedBox(height: 12),
                      // Location
                      TextField(
                        controller: _locationCtl,
                        style: TextStyle(color: Colors.black),
                        decoration: InputDecoration(
                          hintText: 'Location/Address',
                          hintStyle: TextStyle(color: Colors.black54),
                          filled: false,
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black.withOpacity(0.3))),
                          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black)),
                        ),
                      ),
                      SizedBox(height: 12),
                      // Blood group and Role in one row
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
                          SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
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
                              items: [
                                DropdownMenuItem(value: 'donor', child: Text('Donor', style: TextStyle(color: Colors.black))),
                                DropdownMenuItem(value: 'recipient', child: Text('Recipient', style: TextStyle(color: Colors.black))),
                              ],
                              onChanged: (v) => setState(() => _role = v ?? 'donor'),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                        
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _pickedBytes == null ? null : _register,
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.black,
                              side: BorderSide(color: Colors.black, width: 2),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text('Create Account', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w600)),
                          ),
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
