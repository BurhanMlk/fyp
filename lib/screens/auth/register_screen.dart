import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../core/service_locator.dart';
import '../../widgets/animated_blood_bg.dart';
import '../../widgets/blood_bridge_loader.dart';
import '../../widgets/top_snackbar.dart';
import '../../theme.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailCtl = TextEditingController();
  final _passCtl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _role = 'donor';
  bool _isSubmitting = false;
  bool _showPassword = false;

  @override
  void dispose() {
    _emailCtl.dispose();
    _passCtl.dispose();
    super.dispose();
  }

  void _showMsg(String msg, {bool err = true}) {
    showTopSnackBar(context, message: msg,
        backgroundColor: err ? Colors.red.shade700 : Colors.green.shade700);
  }

  Future<void> _registerWithEmail() async {
    if (!_formKey.currentState!.validate()) return;
    final email = _emailCtl.text.trim();
    final pass = _passCtl.text;
    setState(() => _isSubmitting = true);
    showDialog(context: context, barrierDismissible: false, builder: (_) => Center(child: BloodBridgeLoader()));

    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: pass);
      await cred.user!.sendEmailVerification();
      await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set({
        'name': email.split('@').first, 'email': email, 'contact': '',
        'bloodGroup': '', 'role': _role, 'location': '',
        'approved': _role == 'recipient', 'isDonor': _role == 'donor',
        'verificationStatus': 'not_uploaded', 'createdAt': FieldValue.serverTimestamp(),
      });
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.of(context).pop();
        _showMsg('Verification email sent! Check inbox & verify, then login.', err: false);
        await Future.delayed(Duration(seconds: 2));
        if (mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => LoginScreen()));
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) Navigator.of(context).pop();
      String m = e.message ?? 'Failed';
      if (e.code == 'email-already-in-use') m = 'Email already registered. Login instead.';
      else if (e.code == 'weak-password') m = 'Password too weak (min 6 chars).';
      _showMsg(m);
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      _showMsg('Error: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _registerWithGoogle() async {
    setState(() => _isSubmitting = true);
    showDialog(context: context, barrierDismissible: false, builder: (_) => Center(child: BloodBridgeLoader()));
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
          if (mounted) { Navigator.of(context).pop(); setState(() => _isSubmitting = false); }
          return;
        }
        googleEmail = googleUser.email;
        googleDisplayName = googleUser.displayName;
        final googleAuth = await googleUser.authentication;
        if (googleAuth.idToken == null || googleAuth.idToken!.isEmpty) {
          if (mounted) Navigator.of(context).pop();
          _showMsg('Google Sign-In failed: No ID token. Add SHA-1 in Firebase Console → Project Settings.');
          if (mounted) setState(() => _isSubmitting = false);
          return;
        }
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken!,
        );
        userCred = await FirebaseAuth.instance.signInWithCredential(credential);
      }

      final user = userCred.user!;
      final email = user.email ?? googleEmail ?? '';
      final name = user.displayName ?? googleDisplayName ?? email.split('@').first;

      final existing = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (!existing.exists) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'name': name, 'email': email, 'contact': '', 'bloodGroup': '',
          'role': _role, 'location': '', 'approved': _role == 'recipient',
          'isDonor': _role == 'donor', 'verificationStatus': 'not_uploaded',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      if (mounted) {
        Navigator.of(context).pop();
        _showMsg('Account created successfully!', err: false);
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => LoginScreen()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) Navigator.of(context).pop();
      String m = 'Google sign-in error: ${e.message}';
      if (e.code == 'account-exists-with-different-credential') {
        m = 'An account already exists with this email. Please use email/password login.';
      }
      _showMsg(m);
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      final errStr = e.toString();
      if (errStr.contains('ApiException: 10')) {
        _showMsg('Google Sign-In failed: SHA-1 fingerprint not registered in Firebase Console.');
      } else if (errStr.contains('ApiException: 12500')) {
        _showMsg('Google Sign-In failed: OAuth consent screen not configured.');
      } else {
        _showMsg('Google sign-up failed: ${errStr.length > 100 ? errStr.substring(0, 100) : errStr}');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
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
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 520),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.black, width: 1.5),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: Offset(0, 4))],
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
                      child: Form(
                        key: _formKey,
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Container(
                            width: 70, height: 70,
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)]),
                            child: ClipRRect(borderRadius: BorderRadius.circular(10),
                              child: Image.asset('assets/images/blood_bridge.png', fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => Icon(Icons.bloodtype, size: 36, color: AppTheme.actionRed))),
                          ),
                          SizedBox(height: 16),
                          Text('Create Account', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black)),
                          SizedBox(height: 4),
                          Text('Join Blood Bridge and save lives', style: TextStyle(color: Colors.black54, fontSize: 14)),
                          SizedBox(height: 24),

                          // Role Selector
                          Text('I want to register as:', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black87)),
                          SizedBox(height: 10),
                          Row(children: [
                            _roleCard('donor', 'Donor', Icons.volunteer_activism),
                            SizedBox(width: 12),
                            _roleCard('recipient', 'Recipient', Icons.local_hospital),
                          ]),
                          SizedBox(height: 20),

                          // Email
                          TextFormField(
                            controller: _emailCtl, keyboardType: TextInputType.emailAddress,
                            style: TextStyle(color: Colors.black),
                            decoration: InputDecoration(
                              labelText: 'Email', prefixIcon: Icon(Icons.email_outlined, color: Colors.black54),
                              labelStyle: TextStyle(color: Colors.black54),
                              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black26)),
                              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.actionRed, width: 2)),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Email required' : (!v.contains('@') ? 'Valid email required' : null),
                          ),
                          SizedBox(height: 16),

                          // Password
                          TextFormField(
                            controller: _passCtl, obscureText: !_showPassword,
                            style: TextStyle(color: Colors.black),
                            decoration: InputDecoration(
                              labelText: 'Password', prefixIcon: Icon(Icons.lock_outline, color: Colors.black54),
                              suffixIcon: IconButton(icon: Icon(_showPassword ? Icons.visibility : Icons.visibility_off, color: Colors.black54),
                                onPressed: () => setState(() => _showPassword = !_showPassword)),
                              labelStyle: TextStyle(color: Colors.black54),
                              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black26)),
                              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.actionRed, width: 2)),
                            ),
                            validator: (v) => (v == null || v.isEmpty) ? 'Password required' : (v.length < 6 ? 'Min 6 characters' : null),
                          ),
                          SizedBox(height: 24),

                          // Register Button
                          SizedBox(width: double.infinity, height: 50,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.actionRed, foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 3),
                              onPressed: _isSubmitting ? null : _registerWithEmail,
                              child: Text('Create Account', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          SizedBox(height: 16),

                          // OR
                          Row(children: [
                            Expanded(child: Divider(color: Colors.black26)),
                            Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('OR', style: TextStyle(color: Colors.black45, fontWeight: FontWeight.w600))),
                            Expanded(child: Divider(color: Colors.black26)),
                          ]),
                          SizedBox(height: 16),

                          // Google Sign-Up
                          SizedBox(width: double.infinity, height: 50,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(foregroundColor: Colors.black87,
                                side: BorderSide(color: Colors.black26, width: 1.5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), backgroundColor: Colors.white),
                              onPressed: _isSubmitting ? null : _registerWithGoogle,
                              icon: Icon(Icons.g_mobiledata, size: 28, color: Colors.red),
                              label: Text('Continue with Google', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                            ),
                          ),
                          SizedBox(height: 20),

                          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Text('Already have an account? ', style: TextStyle(color: Colors.black54)),
                            GestureDetector(
                              onTap: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => LoginScreen())),
                              child: Text('Login', style: TextStyle(color: AppTheme.actionRed, fontWeight: FontWeight.bold, fontSize: 15)),
                            ),
                          ]),
                        ]),
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

  Widget _roleCard(String role, String label, IconData icon) {
    final selected = _role == role;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _role = role),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? AppTheme.actionRed : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? AppTheme.actionRed : Colors.black26, width: 2),
          ),
          child: Column(children: [
            Icon(icon, color: selected ? Colors.white : Colors.black54, size: 28),
            SizedBox(height: 4),
            Text(label, style: TextStyle(color: selected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 15)),
          ]),
        ),
      ),
    );
  }
}
