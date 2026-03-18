import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/animated_blood_bg.dart';
import '../../widgets/blood_bridge_loader.dart';
import '../../theme.dart';
import '../../services/firebase_service.dart';
import 'register_screen.dart';
import '../home/home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtl = TextEditingController();
  final _passCtl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    // Ensure demo super-admin exists and if demo session is active, auto-navigate to Home
    if (!FirebaseService.initialized) {
      _ensureDemoSuperAdmin().then((_) {
        SharedPreferences.getInstance().then((prefs) {
          final logged = prefs.getBool('demo_logged_in') ?? false;
          if (logged) {
            Future.microtask(() => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => HomeScreen())));
          }
        });
      });
    } else {
      // Firebase mode: ensure superadmin exists in Firebase
      _ensureFirebaseSuperAdmin();
    }
  }

  Future<void> _ensureFirebaseSuperAdmin() async {
    try {
      // Check if superadmin user exists in Firestore
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: 'superadmin@bloodbridge.app')
          .limit(1)
          .get();
      
      if (usersSnapshot.docs.isEmpty) {
        // Create superadmin in Firebase Authentication
        UserCredential userCredential;
        try {
          userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: 'superadmin@bloodbridge.app',
            password: 'SuperAdmin@123',
          );
        } catch (authError) {
          // User might already exist in auth but not in Firestore
          print('Auth creation error (might already exist): $authError');
          // Try to sign in to get the UID
          userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: 'superadmin@bloodbridge.app',
            password: 'SuperAdmin@123',
          );
        }
        
        // Create user document in Firestore
        await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
          'name': 'Super Admin',
          'email': 'superadmin@bloodbridge.app',
          'contact': '+92-300-1234567',
          'bloodGroup': 'O+',
          'role': 'super_admin',
          'location': 'Islamabad, Pakistan',
          'photoUrl': '',
          'createdAt': FieldValue.serverTimestamp(),
          'approved': true,
          'isDonor': false,
        });
        
        // Sign out after creating
        await FirebaseAuth.instance.signOut();
        print('✅ Superadmin created in Firebase');
      } else {
        print('✅ Superadmin already exists in Firebase');
      }
    } catch (e) {
      print('⚠️ Error ensuring Firebase superadmin: $e');
    }
  }

  Future<void> _ensureDemoSuperAdmin() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('demo_users') ?? <String>[];
    final found = list.any((s) {
      try {
        final Map<String, dynamic> u = jsonDecode(s);
        return (u['email'] ?? '') == 'superadmin@bloodbridge.app';
      } catch (_) {
        return false;
      }
    });
    if (!found) {
      final superAdmin = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'name': 'Super Admin',
        'email': 'superadmin@bloodbridge.app',
        'password': 'superadmin',
        'contact': '',
        'bloodGroup': '',
        'role': 'super_admin',
        'location': '',
        'photoData': '',
        'createdAt': DateTime.now().toIso8601String(),
        'approved': true,
      };
      list.insert(0, jsonEncode(superAdmin));
      await prefs.setStringList('demo_users', list);
    }
    // ensure recovery contact exists
    final recovery = prefs.getString('recovery_admin_email') ?? '';
    if (recovery.isEmpty) {
      await prefs.setString('recovery_admin_email', 'burhanmalik672@gmail.com');
    }
  }

  @override
  void dispose() {
    _emailCtl.dispose();
    _passCtl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final email = _emailCtl.text.trim();
    final pass = _passCtl.text;

    setState(() => _isLoading = true);
    try {
      if (FirebaseService.initialized) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: pass);
        if (!mounted) return;
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => HomeScreen()));
      } else {
        final prefs = await SharedPreferences.getInstance();
        final list = prefs.getStringList('demo_users') ?? <String>[];
        if (list.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No demo users found. Please register.')));
          return;
        }
        Map<String, dynamic>? found;
        for (final s in list) {
          final Map<String, dynamic> u = jsonDecode(s);
          if ((u['email'] ?? '') == email && (u['password'] ?? '') == pass) {
            found = u;
            break;
          }
        }
        if (found != null) {
          await prefs.setBool('demo_logged_in', true);
          await prefs.setString('demo_current_email', email);
          if (!mounted) return;
          Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => HomeScreen()));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Wrong credentials')));
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sign in failed: ${e.toString()}')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _forgotPassword() async {
    final email = _emailCtl.text.trim();
    if (email.isEmpty) {
      // ask for email if not filled
      final eCtl = TextEditingController();
      final ok = await showDialog<bool>(context: context, builder: (_) {
        return AlertDialog(
          backgroundColor: Colors.transparent,
          contentPadding: EdgeInsets.zero,
          content: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Forgot password', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
                SizedBox(height: 16),
                TextField(
                  controller: eCtl,
                  style: TextStyle(color: Colors.black),
                  decoration: InputDecoration(
                    labelText: 'Enter your email',
                    labelStyle: TextStyle(color: Colors.black),
                    filled: false,
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black.withOpacity(0.3))),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black)),
                  ),
                ),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text('Cancel', style: TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.w600))),
                    SizedBox(width: 8),
                    TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text('Next', style: TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.w600))),
                  ],
                ),
              ],
            ),
          ),
        );
      });
      if (ok != true) return;
      _emailCtl.text = eCtl.text.trim();
    }
    final usedEmail = _emailCtl.text.trim();
    if (usedEmail.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Email is required')));
      return;
    }

    if (FirebaseService.initialized) {
      try {
        await FirebaseAuth.instance.sendPasswordResetEmail(email: usedEmail);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Password reset email sent')));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Reset failed: ${e.toString()}')));
      }
      return;
    }

    // Demo flow: give user choice to self-reset password or request admin help to change email/password
    final choice = await showDialog<String>(context: context, builder: (_) {
      return SimpleDialog(
        backgroundColor: Colors.white.withOpacity(0.95),
        title: Text('Forgot password', style: TextStyle(color: Colors.black)),
        children: [
          SimpleDialogOption(child: Text('Reset password myself (demo)', style: TextStyle(color: Colors.black)), onPressed: () => Navigator.of(context).pop('self')),
          SimpleDialogOption(child: Text('Request admin help (change email/password)', style: TextStyle(color: Colors.black)), onPressed: () => Navigator.of(context).pop('admin')),
          SimpleDialogOption(child: Text('Cancel', style: TextStyle(color: Colors.red)), onPressed: () => Navigator.of(context).pop('cancel')),
        ],
      );
    });
    if (choice == null || choice == 'cancel') return;

    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('demo_users') ?? <String>[];
    int foundIndex = -1;
    Map<String, dynamic>? found;
    for (int i = 0; i < list.length; i++) {
      try {
        final Map<String, dynamic> u = jsonDecode(list[i]);
        if ((u['email'] ?? '') == usedEmail) {
          foundIndex = i;
          found = u;
          break;
        }
      } catch (_) {}
    }
    if (found == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No demo account with that email')));
      return;
    }

    if (choice == 'self') {
      final pwCtl = TextEditingController();
      final pwCtl2 = TextEditingController();
      final changed = await showDialog<bool>(context: context, builder: (_) {
        return AlertDialog(
          title: Text('Set new demo password'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: pwCtl, decoration: InputDecoration(labelText: 'New password'), obscureText: true),
            TextField(controller: pwCtl2, decoration: InputDecoration(labelText: 'Confirm'), obscureText: true),
          ]),
          actions: [TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text('Cancel')), TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text('Save'))],
        );
      });
      if (changed != true) return;
      final newPw = pwCtl.text;
      final newPw2 = pwCtl2.text;
      if (newPw.isEmpty || newPw != newPw2) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Passwords do not match or empty')));
        return;
      }
      try {
        found['password'] = newPw;
        list[foundIndex] = jsonEncode(found);
        await prefs.setStringList('demo_users', list);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Demo password updated — you can now login')));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update demo password')));
      }
      return;
    }

    // choice == 'admin' -> create a forgot request so super admin can handle email/password change
    final reqs = prefs.getStringList('forgot_requests') ?? <String>[];
    final recovery = prefs.getString('recovery_admin_email') ?? 'burhanmalik672@gmail.com';
    final req = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'email': usedEmail,
      'requestedAt': DateTime.now().toIso8601String(),
      'status': 'pending',
      'handledBy': null,
      'note': 'Requested admin help via app',
    };
    reqs.add(jsonEncode(req));
    await prefs.setStringList('forgot_requests', reqs);
    // In a real app we'd send an email to recovery contact; here we store the request and admin will see it in Admin Dashboard
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Request submitted — super admin will handle (recovery: $recovery)')));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
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
            Positioned.fill(child: AnimatedBloodBackground(cellCount: 9)),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 520),
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
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.asset(
                                  'assets/images/blood_bridge.png',
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stack) => CircleAvatar(
                                    radius: 36,
                                    backgroundColor: Theme.of(context).primaryColor,
                                    child: Icon(Icons.bloodtype, size: 36, color: Colors.white),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: 12),
                            Text('Welcome back', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black)),
                            SizedBox(height: 6),
                            Text('Serve Humanity!', style: TextStyle(color: Colors.black)),
                            SizedBox(height: 18),
                            Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  TextFormField(
                                    controller: _emailCtl,
                                    keyboardType: TextInputType.emailAddress,
                                    style: TextStyle(color: Colors.black),
                                    decoration: InputDecoration(
                                      prefixIcon: Icon(Icons.email, color: Colors.black),
                                      labelText: 'Email',
                                      labelStyle: TextStyle(color: Colors.black),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) return 'Email required';
                                      if (!v.contains('@')) return 'Enter a valid email';
                                      return null;
                                    },
                                  ),
                                  SizedBox(height: 12),
                                  TextFormField(
                                    controller: _passCtl,
                                    obscureText: !_showPassword,
                                    style: TextStyle(color: Colors.black),
                                    decoration: InputDecoration(
                                      prefixIcon: Icon(Icons.lock, color: Colors.black),
                                      labelText: 'Password',
                                      labelStyle: TextStyle(color: Colors.black),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      suffixIcon: IconButton(
                                        icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility, color: Colors.black),
                                        onPressed: () => setState(() => _showPassword = !_showPassword),
                                      ),
                                    ),
                                    validator: (v) {
                                      if (v == null || v.isEmpty) return 'Password required';
                                      if (v.length < 4) return 'Password too short';
                                      return null;
                                    },
                                  ),
                                  SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 50,
                                    child: ElevatedButton(
                                      onPressed: _isLoading ? null : _login,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red.shade600,
                                        foregroundColor: Colors.white,
                                        elevation: 2,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        disabledBackgroundColor: Colors.grey.shade400,
                                      ),
                                      child: _isLoading 
                                        ? BloodBridgeLoader(size: 24, duration: Duration(milliseconds: 600)) 
                                        : Text('Login', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600)),
                                    ),
                                  ),
                                  SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 48,
                                    child: OutlinedButton(
                                      onPressed: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(builder: (_) => RegisterScreen()),
                                        );
                                      },
                                      style: OutlinedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        foregroundColor: Colors.black,
                                        side: BorderSide(color: Colors.black, width: 2),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                      child: Text('Register', style: TextStyle(fontSize: 16, color: Colors.black, fontWeight: FontWeight.w600)),
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Center(
                                    child: TextButton(
                                      onPressed: _forgotPassword, 
                                      child: Text('Forgot password!', style: TextStyle(color: Colors.black, fontSize: 13)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        ],
      ),
    ),
  );
  }
}
