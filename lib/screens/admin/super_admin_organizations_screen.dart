import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/service_locator.dart';
import '../../models/organization_model.dart';
import '../../models/subscription_plan_model.dart';
import '../../models/subscription_model.dart';
import '../../widgets/top_snackbar.dart';
import '../../widgets/blood_bridge_loader.dart';

/// Super Admin - Organization Management Screen
/// Allows super admin to view, approve, reject, suspend, activate organizations
/// and manage subscriptions.

class SuperAdminOrganizationsScreen extends StatefulWidget {
  const SuperAdminOrganizationsScreen({super.key});

  @override
  State<SuperAdminOrganizationsScreen> createState() => _SuperAdminOrganizationsScreenState();
}

class _SuperAdminOrganizationsScreenState extends State<SuperAdminOrganizationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<OrganizationModel> _organizations = [];
  List<SubscriptionPlanModel> _plans = [];
  bool _isLoading = true;
  String _searchQuery = '';

  static const List<String> _tabs = [
    'All',
    'Universities',
    'Societies',
    'Blood Banks',
    'Pending',
    'Active',
    'Suspended',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      _organizations = await sl.organization.getAllOrganizations();
      _plans = await sl.subscriptionPlan.getAllPlans(activeOnly: true);
    } catch (e) {
      if (mounted) {
        showTopSnackBar(context, message: 'Failed to load organizations: $e');
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  List<OrganizationModel> get _filteredOrgs {
    var list = _organizations;
    final tabIndex = _tabController.index;

    // Filter by tab
    switch (tabIndex) {
      case 1: list = list.where((o) => o.type == 'university').toList();
      case 2: list = list.where((o) => o.type == 'society').toList();
      case 3: list = list.where((o) => o.type == 'blood_bank').toList();
      case 4: list = list.where((o) => o.status == 'pending').toList();
      case 5: list = list.where((o) => o.status == 'active' || o.status == 'approved').toList();
      case 6: list = list.where((o) => o.status == 'suspended').toList();
    }

    // Filter by search
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((o) =>
          o.name.toLowerCase().contains(q) ||
          o.email.toLowerCase().contains(q) ||
          (o.city?.toLowerCase().contains(q) ?? false)).toList();
    }
    return list;
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'active': case 'approved': return Colors.green;
      case 'pending': return Colors.orange;
      case 'suspended': return Colors.red;
      case 'rejected': return Colors.grey;
      default: return Colors.blueGrey;
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'university': return 'University';
      case 'society': return 'Society';
      case 'blood_bank': return 'Blood Bank';
      case 'ngo': return 'NGO';
      default: return type;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'university': return Icons.school;
      case 'society': return Icons.groups;
      case 'blood_bank': return Icons.local_hospital;
      case 'ngo': return Icons.volunteer_activism;
      default: return Icons.business;
    }
  }

  Future<void> _approveOrg(OrganizationModel org) async {
    try {
      await sl.organization.approveOrganization(org.id);
      // Auto-assign trial subscription
      final trialPlan = await sl.subscriptionPlan.getTrialPlan();
      if (trialPlan != null) {
        final trialDays = trialPlan.trialDays ?? 14;
        final sub = SubscriptionModel(
          id: '',
          organizationId: org.id,
          planId: trialPlan.id,
          planName: trialPlan.name,
          startDate: DateTime.now(),
          endDate: DateTime.now().add(Duration(days: trialDays)),
          status: 'trial',
          amount: 0,
        );
        await sl.subscription.createSubscription(sub);
        await sl.organization.updateOrganization(org.id, {
          'subscriptionId': sub.id,
          'status': 'active',
        });
      }
      showTopSnackBar(context, message: '${org.name} approved!', backgroundColor: Colors.green.shade700);
      _loadData();
    } catch (e) {
      showTopSnackBar(context, message: 'Failed to approve: $e');
    }
  }

  Future<void> _rejectOrg(OrganizationModel org) async {
    try {
      await sl.organization.rejectOrganization(org.id);
      showTopSnackBar(context, message: '${org.name} rejected', backgroundColor: Colors.orange.shade700);
      _loadData();
    } catch (e) {
      showTopSnackBar(context, message: 'Failed to reject: $e');
    }
  }

  Future<void> _suspendOrg(OrganizationModel org) async {
    try {
      await sl.organization.suspendOrganization(org.id);
      showTopSnackBar(context, message: '${org.name} suspended', backgroundColor: Colors.red.shade700);
      _loadData();
    } catch (e) {
      showTopSnackBar(context, message: 'Failed to suspend: $e');
    }
  }

  Future<void> _activateOrg(OrganizationModel org) async {
    try {
      await sl.organization.activateOrganization(org.id);
      showTopSnackBar(context, message: '${org.name} activated', backgroundColor: Colors.green.shade700);
      _loadData();
    } catch (e) {
      showTopSnackBar(context, message: 'Failed to activate: $e');
    }
  }

  void _showOrgDetails(OrganizationModel org) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(children: [
          Icon(_typeIcon(org.type), color: Colors.red.shade700),
          const SizedBox(width: 8),
          Expanded(child: Text(org.name, style: const TextStyle(fontSize: 16))),
        ]),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _detailRow('Type', _typeLabel(org.type)),
              _detailRow('Email', org.email),
              _detailRow('Phone', org.phone),
              if (org.address != null) _detailRow('Address', org.address!),
              if (org.city != null) _detailRow('City', org.city!),
              if (org.website != null) _detailRow('Website', org.website!),
              if (org.universityId != null) _detailRow('University ID', org.universityId!),
              _detailRow('Status', org.status.toUpperCase()),
              _detailRow('Created', org.createdAt?.toString().substring(0, 10) ?? 'N/A'),
            ],
          ),
        ),
        actions: [
          if (org.status == 'pending') ...[
            TextButton(
              onPressed: () { Navigator.pop(context); _rejectOrg(org); },
              child: const Text('Reject', style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: () { Navigator.pop(context); _approveOrg(org); },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Approve', style: TextStyle(color: Colors.white)),
            ),
          ] else if (org.status == 'active' || org.status == 'approved') ...[
            TextButton(
              onPressed: () { Navigator.pop(context); _suspendOrg(org); },
              child: const Text('Suspend', style: TextStyle(color: Colors.red)),
            ),
          ] else if (org.status == 'suspended') ...[
            ElevatedButton(
              onPressed: () { Navigator.pop(context); _activateOrg(org); },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Activate', style: TextStyle(color: Colors.white)),
            ),
          ],
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Organizations'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search organizations...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          // List
          Expanded(
            child: _isLoading
                ? const Center(child: BloodBridgeLoader())
                : _filteredOrgs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.business_outlined, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 8),
                            Text('No organizations found', style: TextStyle(color: Colors.grey.shade600)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: _filteredOrgs.length,
                          itemBuilder: (_, i) {
                            final org = _filteredOrgs[i];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: _statusColor(org.status).withOpacity(0.1),
                                  child: Icon(_typeIcon(org.type), color: _statusColor(org.status)),
                                ),
                                title: Text(org.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Text('${_typeLabel(org.type)} · ${org.status.toUpperCase()}'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _statusColor(org.status).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        org.status.toUpperCase(),
                                        style: TextStyle(
                                          color: _statusColor(org.status),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.chevron_right),
                                  ],
                                ),
                                onTap: () => _showOrgDetails(org),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          // Navigate to create organization (Super Admin can manually add orgs)
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const _CreateOrganizationScreen()),
          );
          if (result == true) _loadData();
        },
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Organization'),
      ),
    );
  }
}

/// Internal screen for Super Admin to manually create an organization
class _CreateOrganizationScreen extends StatefulWidget {
  const _CreateOrganizationScreen();

  @override
  State<_CreateOrganizationScreen> createState() => _CreateOrganizationScreenState();
}

class _CreateOrganizationScreenState extends State<_CreateOrganizationScreen> {
  final _formKey = GlobalKey<FormState>();
  String _type = 'university';
  final _nameCtl = TextEditingController();
  final _emailCtl = TextEditingController();
  final _phoneCtl = TextEditingController();
  final _addressCtl = TextEditingController();
  final _cityCtl = TextEditingController();
  final _adminEmailCtl = TextEditingController();
  final _adminPassCtl = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameCtl.dispose();
    _emailCtl.dispose();
    _phoneCtl.dispose();
    _addressCtl.dispose();
    _cityCtl.dispose();
    _adminEmailCtl.dispose();
    _adminPassCtl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    try {
      // Create the org admin user account
      final adminEmail = _adminEmailCtl.text.trim();
      final adminPass = _adminPassCtl.text;
      String? adminId;

      try {
        // Check if user already exists or create via Firebase Auth
        final methods = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: adminEmail)
            .limit(1)
            .get();

        if (methods.docs.isNotEmpty) {
          adminId = methods.docs.first.id;
        }
      } catch (_) {}

      // Create the organization
      final org = OrganizationModel(
        id: '',
        type: _type,
        name: _nameCtl.text.trim(),
        email: _emailCtl.text.trim(),
        phone: _phoneCtl.text.trim(),
        address: _addressCtl.text.trim(),
        city: _cityCtl.text.trim(),
        adminId: adminId ?? 'pending_${DateTime.now().millisecondsSinceEpoch}',
        status: 'active', // Auto-approved when Super Admin creates
      );

      await sl.organization.createOrganization(org);

      if (mounted) {
        showTopSnackBar(context, message: 'Organization created!', backgroundColor: Colors.green.shade700);
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        showTopSnackBar(context, message: 'Error: $e');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Organization'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                value: _type,
                decoration: const InputDecoration(labelText: 'Organization Type'),
                items: const [
                  DropdownMenuItem(value: 'university', child: Text('University')),
                  DropdownMenuItem(value: 'society', child: Text('Society')),
                  DropdownMenuItem(value: 'blood_bank', child: Text('Blood Bank')),
                  DropdownMenuItem(value: 'ngo', child: Text('NGO / Other')),
                ],
                onChanged: (v) => setState(() => _type = v!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameCtl,
                decoration: const InputDecoration(labelText: 'Organization Name'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailCtl,
                decoration: const InputDecoration(labelText: 'Organization Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (v) => (v == null || !v.contains('@')) ? 'Valid email required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneCtl,
                decoration: const InputDecoration(labelText: 'Phone'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressCtl,
                decoration: const InputDecoration(labelText: 'Address'),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _cityCtl,
                decoration: const InputDecoration(labelText: 'City'),
              ),
              const SizedBox(height: 24),
              const Text('Admin Account', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _adminEmailCtl,
                decoration: const InputDecoration(labelText: 'Admin Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _adminPassCtl,
                decoration: const InputDecoration(labelText: 'Admin Password (optional)'),
                obscureText: true,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Create Organization'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
