import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../auth/login_screen.dart';
import '../../models/organization_model.dart';
import '../../widgets/top_snackbar.dart';

/// Organization Registration / Application Screen
/// New organizations can apply to join BloodBridge.
/// Their application will be reviewed by the Super Admin.

class OrganizationRegistrationScreen extends StatefulWidget {
  const OrganizationRegistrationScreen({super.key});

  @override
  State<OrganizationRegistrationScreen> createState() => _OrganizationRegistrationScreenState();
}

class _OrganizationRegistrationScreenState extends State<OrganizationRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  String _type = 'society';
  final _nameCtl = TextEditingController();
  final _emailCtl = TextEditingController();
  final _phoneCtl = TextEditingController();
  final _addressCtl = TextEditingController();
  final _cityCtl = TextEditingController();
  final _provinceCtl = TextEditingController();
  final _websiteCtl = TextEditingController();
  final _licenseCtl = TextEditingController();
  final _adminEmailCtl = TextEditingController();
  final _adminNameCtl = TextEditingController();
  final _adminPassCtl = TextEditingController();
  bool _isSubmitting = false;
  bool _showAdminPass = false;

  @override
  void dispose() {
    _nameCtl.dispose();
    _emailCtl.dispose();
    _phoneCtl.dispose();
    _addressCtl.dispose();
    _cityCtl.dispose();
    _provinceCtl.dispose();
    _websiteCtl.dispose();
    _licenseCtl.dispose();
    _adminEmailCtl.dispose();
    _adminNameCtl.dispose();
    _adminPassCtl.dispose();
    super.dispose();
  }

  Future<void> _submitApplication() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final adminEmail = _adminEmailCtl.text.trim();
      final adminPass = _adminPassCtl.text;
      final adminName = _adminNameCtl.text.trim();
      final orgType = _type;
      String adminUid = '';

      // Create Firebase Auth account NOW so admin can login
      try {
        final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: adminEmail,
          password: adminPass,
        );
        adminUid = cred.user!.uid;
        await cred.user!.updateDisplayName(adminName);

        // Send verification email (in case the account is used elsewhere).
        try {
          await cred.user!.sendEmailVerification();
        } catch (_) {}

        // Create the organization FIRST so we get its document ID.
        // The admin user record is then linked to this organization.
        final orgRef = await FirebaseFirestore.instance.collection('organizations').add({
          'type': orgType,
          'name': _nameCtl.text.trim(),
          'email': _emailCtl.text.trim(),
          'phone': _phoneCtl.text.trim(),
          'address': _addressCtl.text.trim(),
          'city': _cityCtl.text.trim(),
          'province': _provinceCtl.text.trim(),
          'website': _websiteCtl.text.trim(),
          if (orgType == 'blood_bank') 'licenseNumber': _licenseCtl.text.trim(),
          'adminId': adminUid,
          'adminName': adminName,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        final orgId = orgRef.id;

        // Write the admin user record with the correct role and
        // the type-specific ID so the right dashboard loads after approval.
        final role = OrganizationModel.adminRoleForType(orgType);
        await FirebaseFirestore.instance.collection('users').doc(adminUid).set({
          'name': adminName,
          'email': adminEmail,
          'contact': _phoneCtl.text.trim(),
          'bloodGroup': '',
          'role': role,
          'location': '${_cityCtl.text.trim()}, ${_provinceCtl.text.trim()}',
          'approved': false,
          'isDonor': false,
          'organizationId': orgId,
          if (orgType == 'blood_bank') 'bloodBankId': orgId,
          if (orgType == 'society' || orgType == 'ngo') 'societyId': orgId,
          if (orgType == 'university') 'universityId': orgId,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Now sign out so admin can login fresh (after approval)
        await FirebaseAuth.instance.signOut();
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          showTopSnackBar(context, message: 'This email is already registered. Use a different admin email.');
          if (mounted) setState(() => _isSubmitting = false);
          return;
        }
        if (e.code == 'weak-password') {
          showTopSnackBar(context, message: 'Password too weak. Use at least 6 characters.');
          if (mounted) setState(() => _isSubmitting = false);
          return;
        }
        rethrow;
      }

      if (mounted) {
        showTopSnackBar(context, message: 'Registered! You can login now. Awaiting approval.', backgroundColor: Colors.green.shade700);
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) showTopSnackBar(context, message: 'Failed: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register Organization'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.red),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Register your organization to use BloodBridge. '
                        'Your application will be reviewed by our team.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Organization Type
              const Text('Organization Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _type,
                dropdownColor: Colors.white,
                icon: const Icon(Icons.arrow_drop_down, color: Colors.black87),
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  filled: true,
                  fillColor: Colors.white,
                  prefixIcon: const Icon(Icons.category_outlined),
                ),
                items: const [
                  DropdownMenuItem(value: 'university', child: Text('University')),
                  DropdownMenuItem(value: 'society', child: Text('University Society / Student Society')),
                  DropdownMenuItem(value: 'blood_bank', child: Text('Blood Bank / Hospital')),
                  DropdownMenuItem(value: 'ngo', child: Text('NGO / Other Organization')),
                ],
                onChanged: (v) => setState(() => _type = v!),
              ),
              const SizedBox(height: 20),

              // Organization Details (2-column layout)
              const Text('Organization Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _buildField(_nameCtl, 'Org Name *', Icons.business)),
                const SizedBox(width: 12),
                Expanded(child: _buildField(_emailCtl, 'Org Email *', Icons.email, keyboardType: TextInputType.emailAddress)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _buildField(_phoneCtl, 'Phone *', Icons.phone, keyboardType: TextInputType.phone)),
                const SizedBox(width: 12),
                Expanded(child: _buildField(_cityCtl, 'City', Icons.location_city)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _buildField(_provinceCtl, 'Province', Icons.map)),
                const SizedBox(width: 12),
                Expanded(child: _buildField(_websiteCtl, 'Website', Icons.language)),
              ]),
              const SizedBox(height: 12),
              _buildField(_addressCtl, 'Address', Icons.location_on, maxLines: 2),

              if (_type == 'blood_bank') ...[
                const SizedBox(height: 12),
                _buildField(_licenseCtl, 'License / Registration Number *', Icons.assignment),
              ],

              const SizedBox(height: 20),

              // Admin Contact (2-column)
              const Text('Admin Account', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _buildField(_adminNameCtl, 'Admin Name *', Icons.person)),
                const SizedBox(width: 12),
                Expanded(child: _buildField(_adminEmailCtl, 'Admin Email *', Icons.email, keyboardType: TextInputType.emailAddress)),
              ]),
              const SizedBox(height: 12),
              _buildPasswordField(),

              const SizedBox(height: 24),

              // Submit
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitApplication,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Submit Application', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController controller, String label, IconData icon,
      {TextInputType keyboardType = TextInputType.text, int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: label.contains('*') ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null : null,
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _adminPassCtl,
      obscureText: !_showAdminPass,
      decoration: InputDecoration(
        labelText: 'Password *',
        prefixIcon: const Icon(Icons.lock),
        suffixIcon: IconButton(
          icon: Icon(_showAdminPass ? Icons.visibility : Icons.visibility_off),
          onPressed: () => setState(() => _showAdminPass = !_showAdminPass),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Required';
        if (v.length < 6) return 'Min 6 characters';
        return null;
      },
    );
  }
}
