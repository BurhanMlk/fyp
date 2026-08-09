import 'package:flutter/material.dart';
import '../../core/service_locator.dart';
import '../../models/organization_model.dart';
import '../../widgets/top_snackbar.dart';
import '../../widgets/blood_bridge_loader.dart';

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
  String _type = 'university';
  final _nameCtl = TextEditingController();
  final _emailCtl = TextEditingController();
  final _phoneCtl = TextEditingController();
  final _addressCtl = TextEditingController();
  final _cityCtl = TextEditingController();
  final _provinceCtl = TextEditingController();
  final _websiteCtl = TextEditingController();
  final _descriptionCtl = TextEditingController();
  final _licenseCtl = TextEditingController(); // For blood banks
  final _adminEmailCtl = TextEditingController();
  final _adminNameCtl = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameCtl.dispose();
    _emailCtl.dispose();
    _phoneCtl.dispose();
    _addressCtl.dispose();
    _cityCtl.dispose();
    _provinceCtl.dispose();
    _websiteCtl.dispose();
    _descriptionCtl.dispose();
    _licenseCtl.dispose();
    _adminEmailCtl.dispose();
    _adminNameCtl.dispose();
    super.dispose();
  }

  Future<void> _submitApplication() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    try {
      final org = OrganizationModel(
        id: '',
        type: _type,
        name: _nameCtl.text.trim(),
        email: _emailCtl.text.trim(),
        phone: _phoneCtl.text.trim(),
        address: _addressCtl.text.trim(),
        city: _cityCtl.text.trim(),
        province: _provinceCtl.text.trim(),
        website: _websiteCtl.text.trim(),
        description: _descriptionCtl.text.trim(),
        licenseNumber: _type == 'blood_bank' ? _licenseCtl.text.trim() : null,
        adminId: _adminEmailCtl.text.trim(), // Will be updated when admin account is created
        status: 'pending',
      );

      await sl.organization.createOrganization(org);

      if (mounted) {
        showTopSnackBar(
          context,
          message: 'Application submitted! We will review and get back to you.',
          backgroundColor: Colors.green.shade700,
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showTopSnackBar(context, message: 'Failed to submit: $e');
      }
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
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                items: const [
                  DropdownMenuItem(value: 'university', child: Text('🏫 University')),
                  DropdownMenuItem(value: 'society', child: Text('👥 University Society')),
                  DropdownMenuItem(value: 'blood_bank', child: Text('🏥 Blood Bank')),
                  DropdownMenuItem(value: 'ngo', child: Text('🤝 NGO / Other Organization')),
                ],
                onChanged: (v) => setState(() => _type = v!),
              ),
              const SizedBox(height: 20),

              // Organization Details
              const Text('Organization Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              _buildField(_nameCtl, 'Organization Name *', Icons.business),
              const SizedBox(height: 12),
              _buildField(_emailCtl, 'Organization Email *', Icons.email, keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 12),
              _buildField(_phoneCtl, 'Phone Number *', Icons.phone, keyboardType: TextInputType.phone),
              const SizedBox(height: 12),
              _buildField(_addressCtl, 'Address', Icons.location_on, maxLines: 2),
              const SizedBox(height: 12),
              _buildField(_cityCtl, 'City', Icons.location_city),
              const SizedBox(height: 12),
              _buildField(_provinceCtl, 'Province', Icons.map),
              const SizedBox(height: 12),
              _buildField(_websiteCtl, 'Website (optional)', Icons.language),
              const SizedBox(height: 12),
              _buildField(_descriptionCtl, 'Description (optional)', Icons.description, maxLines: 3),

              // Blood Bank specific
              if (_type == 'blood_bank') ...[
                const SizedBox(height: 12),
                _buildField(_licenseCtl, 'License / Registration Number *', Icons.assignment),
              ],

              const SizedBox(height: 20),

              // Admin Contact
              const Text('Admin Contact', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              _buildField(_adminNameCtl, 'Admin Name *', Icons.person),
              const SizedBox(height: 12),
              _buildField(_adminEmailCtl, 'Admin Email *', Icons.email, keyboardType: TextInputType.emailAddress),

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
}
