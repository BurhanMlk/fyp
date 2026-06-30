import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/animated_blood_bg.dart';
import '../../widgets/blood_bridge_loader.dart';
import '../../widgets/top_snackbar.dart';
import 'register_screen.dart';
import '../home/home_screen.dart';
import '../admin/admin_dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const String _superAdminEmail = 'superadmin@bloodbridge.app';
  static const String _superAdminPassword = 'SuperAdmin@123';

  final _emailCtl = TextEditingController();
  final _passCtl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    _ensureFirebaseSuperAdmin();
  }

  Future<void> _ensureFirebaseSuperAdmin() async {
    try {
      User? authUser;
      try {
        final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _superAdminEmail,
          password: _superAdminPassword,
        );
        authUser = credential.user;
      } on FirebaseAuthException catch (authError) {
        if (authError.code == 'user-not-found' ||
            authError.code == 'wrong-password' ||
            authError.code == 'invalid-credential') {
          final created = await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: _superAdminEmail,
            password: _superAdminPassword,
          );
          authUser = created.user;
        } else {
          rethrow;
        }
      }

      if (authUser == null) return;

      final docRef = FirebaseFirestore.instance.collection('users').doc(authUser.uid);
      final doc = await docRef.get();
      if (!doc.exists) {
        await docRef.set({
          'name': 'Super Admin',
          'email': _superAdminEmail,
          'contact': '+92-300-1234567',
          'bloodGroup': 'O+',
          'role': 'super_admin',
          'location': 'Islamabad, Pakistan',
          'createdAt': FieldValue.serverTimestamp(),
          'approved': true,
          'isDonor': false,
        });
      } else {
        final data = doc.data() ?? {};
        if ((data['role'] ?? '') != 'super_admin') {
          await docRef.update({'role': 'super_admin', 'approved': true});
        }
      }

      await FirebaseAuth.instance.signOut();
    } catch (e) {
      print('⚠️ Error ensuring Firebase superadmin: $e');
    }
  }

  @override
  void dispose() {
    _emailCtl.dispose();
    _passCtl.dispose();
    super.dispose();
  }

  void _showTopSnackBar(String message, {bool isError = true}) {
    showTopSnackBar(
      context,
      message: message,
      backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
    );
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final email = _emailCtl.text.trim();
    final pass = _passCtl.text;

    setState(() => _isLoading = true);
    try {
      if (email == _superAdminEmail) {
        await _ensureFirebaseSuperAdmin();
      }

      final credential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: pass);
      final user = credential.user;
      if (user == null) {
        _showTopSnackBar('Login failed. Please try again.');
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!mounted) return;

      if (email == _superAdminEmail) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => AdminDashboard()),
        );
      } else {
        final role = userDoc.data()?['role'] ?? '';
        if (role == 'super_admin' || role == 'admin') {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => AdminDashboard()),
          );
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => HomeScreen()),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'user-not-found':
          msg = 'No account found with this email.';
          break;
        case 'wrong-password':
        case 'invalid-credential':
          msg = 'Incorrect email or password.';
          break;
        case 'invalid-email':
          msg = 'Invalid email address format.';
          break;
        case 'user-disabled':
          msg = 'This account has been disabled.';
          break;
        case 'too-many-requests':
          msg = 'Too many attempts. Please try again later.';
          break;
        default:
          msg = 'Sign in failed: ${e.message ?? e.toString()}';
      }
      _showTopSnackBar(msg);
    } catch (e) {
      _showTopSnackBar('Sign in failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _forgotPassword() async {
    final email = _emailCtl.text.trim();
    if (email.isEmpty) {
      final eCtl = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: Colors.transparent,
          contentPadding: EdgeInsets.zero,
          content: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.black, width: 1.5),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: Offset(0, 4)),
              ],
            ),
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Forgot Password',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
                SizedBox(height: 16),
                TextField(
                  controller: eCtl,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(color: Colors.black),
                  onSubmitted: (_) {}, // Disable Enter key
                  decoration: InputDecoration(
                    labelText: 'Enter your email',
                    labelStyle: TextStyle(color: Colors.black),
                    filled: false,
                    enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.black.withOpacity(0.3))),
                    focusedBorder:
                        UnderlineInputBorder(borderSide: BorderSide(color: Colors.black)),
                  ),
                ),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: Text('Cancel',
                            style: TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.w600))),
                    SizedBox(width: 8),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.black, width: 1.5),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => Navigator.of(context).pop(true),
                      child: Text('Send',
                          style: TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      if (ok != true) return;
      _emailCtl.text = eCtl.text.trim();
    }

    final usedEmail = _emailCtl.text.trim();
    if (usedEmail.isEmpty) {
      _showTopSnackBar('Email is required');
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: usedEmail);
      _showTopSnackBar(
          'Password reset email sent! Check your inbox (and spam folder).',
          isError: false);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        _showTopSnackBar('No account found with this email address.');
      } else if (e.code == 'invalid-email') {
        _showTopSnackBar('Invalid email address format.');
      } else {
        _showTopSnackBar('Reset failed: ${e.message ?? e.toString()}');
      }
    } catch (e) {
      _showTopSnackBar('Reset failed: ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: [
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
                        border: Border.all(color: Colors.black, width: 1.5),
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
                            Text('Welcome back',
                                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black)),
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
                                    onFieldSubmitted: (_) {}, // Disable Enter key
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
                                    onFieldSubmitted: (_) {}, // Disable Enter key
                                    decoration: InputDecoration(
                                      prefixIcon: Icon(Icons.lock, color: Colors.black),
                                      labelText: 'Password',
                                      labelStyle: TextStyle(color: Colors.black),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                            _showPassword ? Icons.visibility_off : Icons.visibility,
                                            color: Colors.black),
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
                                    child: OutlinedButton(
                                      onPressed: _isLoading ? null : _login,
                                      style: OutlinedButton.styleFrom(
                                        backgroundColor: Colors.white.withOpacity(0.9),
                                        foregroundColor: Colors.black,
                                        side: BorderSide(color: Colors.black, width: 2),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        disabledForegroundColor: Colors.grey.shade400,
                                      ),
                                      child: _isLoading
                                          ? BloodBridgeLoader(size: 24, duration: Duration(milliseconds: 600))
                                          : Text('Login',
                                              style: TextStyle(fontSize: 16, color: Colors.black, fontWeight: FontWeight.w600)),
                                    ),
                                  ),
                                  SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 48,
                                    child: OutlinedButton(
                                      onPressed: () => Navigator.of(context)
                                          .push(MaterialPageRoute(builder: (_) => RegisterScreen())),
                                      style: OutlinedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        foregroundColor: Colors.black,
                                        side: BorderSide(color: Colors.black, width: 2),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                      child: Text('Register',
                                          style: TextStyle(fontSize: 16, color: Colors.black, fontWeight: FontWeight.w600)),
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Center(
                                    child: OutlinedButton(
                                      onPressed: _forgotPassword,
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.black,
                                        side: BorderSide(color: Colors.black, width: 1.5),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      ),
                                      child: Text('Forgot password?',
                                          style: TextStyle(color: Colors.black, fontSize: 13)),
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
