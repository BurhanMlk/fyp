import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../core/service_locator.dart';
import '../../widgets/animated_blood_bg.dart';
import '../../widgets/blood_bridge_loader.dart';
import '../../widgets/top_snackbar.dart';
import 'register_screen.dart';
import '../home/home_screen.dart';
import '../admin/admin_dashboard.dart';
import '../admin/blood_bank_admin_dashboard.dart';
import '../admin/university_admin_dashboard.dart';
import '../admin/society_admin_dashboard.dart';

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
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: pass);
      final user = credential.user;
      if (user == null) { _showTopSnackBar('Login failed.'); return; }

      // Fetch user role to decide whether email verification is required.
      final isOrgAdmin = await _isOrganizationAdmin(user.uid);

      // Check email verification. Organization admins are verified by the
      // Super Admin approval flow, so they are allowed to login without
      // email verification once their organization is approved.
      if (!user.emailVerified && email != _superAdminEmail && !isOrgAdmin) {
        await FirebaseAuth.instance.signOut();
        _showTopSnackBar('Please verify your email first. Check your inbox.', isError: true);
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      await _navigateAfterLogin(user);
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'user-not-found': msg = 'No account found with this email.'; break;
        case 'wrong-password': case 'invalid-credential': msg = 'Incorrect email or password.'; break;
        case 'invalid-email': msg = 'Invalid email address.'; break;
        case 'user-disabled': msg = 'Account has been disabled.'; break;
        case 'too-many-requests': msg = 'Too many attempts. Try again later.'; break;
        default: msg = 'Sign in failed: ${e.message ?? e.toString()}';
      }
      _showTopSnackBar(msg);
    } catch (e) {
      _showTopSnackBar('Sign in failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Returns true if the Firestore user record has an organization-admin role.
  Future<bool> _isOrganizationAdmin(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final role = (doc.data()?['role'] ?? '').toString();
      return role == 'blood_bank_admin' ||
          role == 'university_admin' ||
          role == 'society_admin';
    } catch (_) {
      return false;
    }
  }

  /// Shared navigation logic after successful login
  /// Routes to the appropriate dashboard based on user role.
  Future<void> _navigateAfterLogin(User user) async {
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (!mounted) return;

    final data = userDoc.data() ?? {};
    final email = user.email ?? '';
    final role = (data['role'] ?? '').toString();
    final hasLocation = (data['location'] ?? '').toString().isNotEmpty;

    // ── Gate: organization admins must be approved by Super Admin ──
    final isOrgAdmin = role == 'blood_bank_admin' ||
        role == 'university_admin' ||
        role == 'society_admin';
    final approved = data['approved'] == true;

    if (isOrgAdmin && !approved) {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        _showTopSnackBar(
          'Your organization is still awaiting approval by the Super Admin.',
          isError: true,
        );
        setState(() => _isLoading = false);
      }
      return;
    }

    if (isOrgAdmin) {
      // Block suspended / rejected organizations even if previously approved.
      try {
        final org = await sl.organization.getOrganizationByAdminId(user.uid);
        if (org != null &&
            (org.status == 'suspended' || org.status == 'rejected')) {
          await FirebaseAuth.instance.signOut();
          if (mounted) {
            _showTopSnackBar(
              'Your organization account is ${org.status}. Contact the Super Admin.',
              isError: true,
            );
            setState(() => _isLoading = false);
          }
          return;
        }
      } catch (_) {}
    }

    // ── Multi-tenant role-based routing ──
    Widget targetScreen;

    if (email == _superAdminEmail || role == 'super_admin') {
      targetScreen = const AdminDashboard();
    } else if (role == 'blood_bank_admin') {
      targetScreen = const BloodBankAdminDashboard();
    } else if (role == 'university_admin') {
      targetScreen = const UniversityAdminDashboard();
    } else if (role == 'society_admin') {
      targetScreen = const SocietyAdminDashboard();
    } else if (role == 'admin') {
      // Legacy admin → route to super admin for backward compatibility
      targetScreen = const AdminDashboard();
    } else {
      // Donor, Recipient, Volunteer → HomeScreen
      targetScreen = const HomeScreen();
    }

    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => targetScreen));
  }

  /// Google Sign-In for login
  Future<void> _loginWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final UserCredential userCred;
      String? googleEmail;
      String? googleDisplayName;

      if (kIsWeb) {
        // Web: use Firebase signInWithPopup (google_sign_in is deprecated on web)
        userCred = await FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());
      } else {
        // Mobile: use GoogleSignIn plugin
        final googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
        final googleUser = await googleSignIn.signIn();
        if (googleUser == null) {
          if (mounted) setState(() => _isLoading = false);
          return;
        }
        googleEmail = googleUser.email;
        googleDisplayName = googleUser.displayName;
        final googleAuth = await googleUser.authentication;
        if (googleAuth.idToken == null || googleAuth.idToken!.isEmpty) {
          _showTopSnackBar('Google Sign-In failed: No ID token. Add SHA-1 in Firebase Console → Project Settings.');
          if (mounted) setState(() => _isLoading = false);
          return;
        }
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken!,
        );
        userCred = await FirebaseAuth.instance.signInWithCredential(credential);
      }

      final user = userCred.user;
      if (user == null) {
        _showTopSnackBar('Google Sign-In failed.');
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // Check if user exists in Firestore, if not create a record
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        final email = user.email ?? googleEmail ?? '';
        final name = user.displayName ?? googleDisplayName ?? (email.split('@').first);
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'name': name,
          'email': email,
          'contact': '',
          'bloodGroup': '',
          'role': 'donor',
          'location': '',
          'approved': false,
          'isDonor': true,
          'verificationStatus': 'not_uploaded',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await _navigateAfterLogin(user);
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'account-exists-with-different-credential':
          msg = 'An account already exists with the same email. Please use email/password login.';
          break;
        case 'user-disabled':
          msg = 'This account has been disabled.';
          break;
        default:
          msg = 'Google Sign-In error: ${e.message ?? e.toString()}';
      }
      _showTopSnackBar(msg);
    } catch (e) {
      final errStr = e.toString();
      if (errStr.contains('ApiException: 10')) {
        _showTopSnackBar('Google Sign-In failed: SHA-1 fingerprint not registered in Firebase Console.');
      } else if (errStr.contains('ApiException: 12500')) {
        _showTopSnackBar('Google Sign-In failed: OAuth consent screen not configured.');
      } else {
        _showTopSnackBar('Google Sign-In failed: ${errStr.length > 100 ? errStr.substring(0, 100) : errStr}');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Shows a popup asking the user to add their location after first login
  Future<bool?> _showLocationPopup(String uid, String email) async {
    final locationCtl = TextEditingController();
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.black, width: 2),
        ),
        title: Row(children: [
          Icon(Icons.location_on, color: Colors.black, size: 28),
          SizedBox(width: 8),
          Text('Set Your Location', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Please add your location so donors/recipients near you can find you.',
            style: TextStyle(color: Colors.black87, fontSize: 14)),
          SizedBox(height: 16),
          TextField(
            controller: locationCtl,
            autofocus: true,
            style: TextStyle(color: Colors.black),
            decoration: InputDecoration(
              hintText: 'e.g. Islamabad, Pakistan',
              hintStyle: TextStyle(color: Colors.black54),
              prefixIcon: Icon(Icons.location_on_outlined, color: Colors.black),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.black),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.black),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.black, width: 2),
              ),
            ),
          ),
        ]),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              side: BorderSide(color: Colors.black, width: 2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Skip'),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              side: BorderSide(color: Colors.black, width: 2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final loc = locationCtl.text.trim();
              if (loc.isNotEmpty) {
                try {
                  await FirebaseFirestore.instance.collection('users').doc(uid).update({'location': loc});
                  try { await sl.user.updateUser(uid, {'location': loc}); } catch (_) {}
                } catch (e) { print('Error saving location: $e'); }
              }
              if (ctx.mounted) Navigator.of(ctx).pop(true);
            },
            child: Text('Save Location'),
          ),
        ],
      ),
    );
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
                  onSubmitted: (_) => {},
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
                                  SizedBox(height: 16),
                                  // OR divider
                                  Row(children: [
                                    Expanded(child: Divider(color: Colors.black26)),
                                    Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 12),
                                      child: Text('OR', style: TextStyle(color: Colors.black45, fontWeight: FontWeight.w600)),
                                    ),
                                    Expanded(child: Divider(color: Colors.black26)),
                                  ]),
                                  SizedBox(height: 16),
                                  // Google Sign-In
                                  SizedBox(
                                    width: double.infinity,
                                    height: 48,
                                    child: OutlinedButton.icon(
                                      onPressed: _isLoading ? null : _loginWithGoogle,
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.black87,
                                        side: BorderSide(color: Colors.black26, width: 1.5),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        backgroundColor: Colors.white,
                                      ),
                                      icon: Icon(Icons.g_mobiledata, size: 28, color: Colors.red),
                                      label: Text('Continue with Google',
                                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
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
