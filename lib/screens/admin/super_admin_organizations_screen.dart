import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  Future<void> _loadData({bool showLoader = true}) async {
    if (showLoader) setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        sl.organization.getAllOrganizations(),
        sl.subscriptionPlan.getAllPlans(activeOnly: true),
      ]);
      _organizations = results[0] as List<OrganizationModel>;
      _plans = results[1] as List<SubscriptionPlanModel>;
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
      final orgDoc = await FirebaseFirestore.instance.collection('organizations').doc(org.id).get();
      final orgData = orgDoc.data() ?? {};
      final adminUid = (orgData['adminId'] ?? '').toString();

      // Approve user if exists
      if (adminUid.isNotEmpty) {
        try {
          await FirebaseFirestore.instance.collection('users').doc(adminUid).update({
            'approved': true,
            'role': OrganizationModel.adminRoleForType(org.type),
            'organizationId': org.id,
            if (org.type == 'blood_bank') 'bloodBankId': org.id,
            if (org.type == 'society' || org.type == 'ngo') 'societyId': org.id,
            if (org.type == 'university') 'universityId': org.id,
          });
        } catch (_) {}
      }

      await sl.organization.approveOrganization(org.id);
      final updates = <String, dynamic>{'status': 'active'};

      // Auto-assign trial subscription. This is optional and must never
      // block the approval itself, so it is isolated in its own try/catch.
      try {
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
          final subId = await sl.subscription.createSubscription(sub);
          updates['subscriptionId'] = subId;
        }
      } catch (e) {
        debugPrint('Trial subscription assignment failed: $e');
      }

      await sl.organization.updateOrganization(org.id, updates);
      showTopSnackBar(context, message: '${org.name} approved!', backgroundColor: Colors.green.shade700);
      _loadData(showLoader: false);
    } catch (e) {
      showTopSnackBar(context, message: 'Failed to approve: $e');
    }
  }

  Future<void> _rejectOrg(OrganizationModel org) async {
    try {
      await sl.organization.rejectOrganization(org.id);
      showTopSnackBar(context, message: '${org.name} rejected', backgroundColor: Colors.orange.shade700);
      _loadData(showLoader: false);
    } catch (e) {
      showTopSnackBar(context, message: 'Failed to reject: $e');
    }
  }

  Future<void> _suspendOrg(OrganizationModel org) async {
    try {
      await sl.organization.suspendOrganization(org.id);
      showTopSnackBar(context, message: '${org.name} suspended', backgroundColor: Colors.red.shade700);
      _loadData(showLoader: false);
    } catch (e) {
      showTopSnackBar(context, message: 'Failed to suspend: $e');
    }
  }

  Future<void> _activateOrg(OrganizationModel org) async {
    try {
      await sl.organization.activateOrganization(org.id);
      showTopSnackBar(context, message: '${org.name} activated', backgroundColor: Colors.green.shade700);
      _loadData(showLoader: false);
    } catch (e) {
      showTopSnackBar(context, message: 'Failed to activate: $e');
    }
  }

  Future<void> _deleteOrg(OrganizationModel org) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white.withOpacity(0.85),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade300, width: 1.5),
        ),
        title: const Text('Delete Organization?'),
        content: Text(
          'Are you sure you want to delete "${org.name}"?\n\n'
          'Its linked admin account will also be removed. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      // Remove the linked admin user record (if any) so no orphan admin remains.
      final adminUid = org.adminId;
      if (adminUid.isNotEmpty) {
        try {
          await FirebaseFirestore.instance.collection('users').doc(adminUid).delete();
        } catch (_) {}
      }
      await sl.organization.deleteOrganization(org.id);
      // Optimistically remove from the list so the UI updates instantly.
      setState(() {
        _organizations.removeWhere((o) => o.id == org.id);
      });
      showTopSnackBar(context, message: '${org.name} deleted', backgroundColor: Colors.red.shade700);
    } catch (e) {
      showTopSnackBar(context, message: 'Failed to delete: $e');
    }
  }

  Future<void> _showOrgDetails(OrganizationModel org) async {
    final extras = await _fetchOrgExtras(org);
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white.withOpacity(0.85),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade300, width: 1.5),
        ),
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
              if (extras.isNotEmpty) ...[
                const Divider(height: 16),
                ...extras.map((e) => _detailRow(e['label']!, e['value']!)),
              ],
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

  // Fetches extra operational data for an organization so the Super Admin
  // can see donors, linked blood banks, and blood inventory at a glance.
  Future<List<Map<String, String>>> _fetchOrgExtras(OrganizationModel org) async {
    final extras = <Map<String, String>>[];
    try {
      // Donors for societies and NGOs
      if (org.type == 'society' || org.type == 'ngo') {
        final donorsSnap = await FirebaseFirestore.instance
            .collection('users')
            .where('societyId', isEqualTo: org.id)
            .get();
        final donors = donorsSnap.docs
            .where((d) => d.data()['isDonor'] == true || d.data()['role'] == 'donor')
            .length;
        extras.add({'label': 'Donors', 'value': '$donors'});
      }

      // Societies under a university
      if (org.type == 'university') {
        final socSnap = await FirebaseFirestore.instance
            .collection('organizations')
            .where('universityId', isEqualTo: org.id)
            .get();
        final societies = socSnap.docs.where((d) => d.data()['type'] == 'society').length;
        extras.add({'label': 'Societies', 'value': '$societies'});
      }

      // Inventory for blood banks
      if (org.type == 'blood_bank') {
        final invSnap = await FirebaseFirestore.instance
            .collection('blood_inventory')
            .where('bloodBankId', isEqualTo: org.id)
            .get();
        int units = 0;
        final groups = <String>{};
        for (final d in invSnap.docs) {
          final q = d.data()['quantity'];
          units += q is int ? q : int.tryParse(q?.toString() ?? '0') ?? 0;
          final bg = (d.data()['bloodGroup'] ?? '').toString();
          if (bg.isNotEmpty) groups.add(bg);
        }
        extras.add({'label': 'Blood Units', 'value': '$units'});
        extras.add({'label': 'Blood Groups', 'value': '${groups.length}'});
      }

      // Linked blood banks + their inventory for societies
      if (org.type == 'society') {
        final bbSnap = await FirebaseFirestore.instance
            .collection('organizations')
            .where('societyId', isEqualTo: org.id)
            .get();
        extras.add({'label': 'Linked Blood Banks', 'value': '${bbSnap.docs.length}'});
        int units = 0;
        for (final bb in bbSnap.docs) {
          final invSnap = await FirebaseFirestore.instance
              .collection('blood_inventory')
              .where('bloodBankId', isEqualTo: bb.id)
              .get();
          for (final d in invSnap.docs) {
            final q = d.data()['quantity'];
            units += q is int ? q : int.tryParse(q?.toString() ?? '0') ?? 0;
          }
        }
        extras.add({'label': 'Blood Units', 'value': '$units'});
      }
    } catch (_) {}
    return extras;
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
                        onRefresh: () => _loadData(showLoader: false),
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
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                      tooltip: 'Delete Organization',
                                      onPressed: () => _deleteOrg(org),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    try {
      final adminEmail = _adminEmailCtl.text.trim();
      final adminPass = _adminPassCtl.text;
      final adminName = _adminNameCtl.text.trim();
      final orgType = _type;
      String adminUid = '';
      bool isNewUser = false;

      try {
        // Reuse an existing user account if this email already exists.
        final existing = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: adminEmail)
            .limit(1)
            .get();

        if (existing.docs.isNotEmpty) {
          adminUid = existing.docs.first.id;
        } else {
          final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: adminEmail,
            password: adminPass,
          );
          adminUid = cred.user!.uid;
          await cred.user!.updateDisplayName(adminName);
          try {
            await cred.user!.sendEmailVerification();
          } catch (_) {}
          isNewUser = true;
        }
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

      // Create the organization (auto-approved because Super Admin creates it).
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
        'adminId': adminUid.isNotEmpty ? adminUid : 'pending_${DateTime.now().millisecondsSinceEpoch}',
        'adminName': adminName,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      final orgId = orgRef.id;

      // Link / create the admin user record with the correct role and IDs.
      final role = OrganizationModel.adminRoleForType(orgType);
      if (isNewUser) {
        await FirebaseFirestore.instance.collection('users').doc(adminUid).set({
          'name': adminName,
          'email': adminEmail,
          'contact': _phoneCtl.text.trim(),
          'bloodGroup': '',
          'role': role,
          'location': '${_cityCtl.text.trim()}, ${_provinceCtl.text.trim()}',
          'approved': true,
          'isDonor': false,
          'organizationId': orgId,
          if (orgType == 'blood_bank') 'bloodBankId': orgId,
          if (orgType == 'society' || orgType == 'ngo') 'societyId': orgId,
          if (orgType == 'university') 'universityId': orgId,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else if (adminUid.isNotEmpty) {
        await FirebaseFirestore.instance.collection('users').doc(adminUid).update({
          'role': role,
          'approved': true,
          'organizationId': orgId,
          if (orgType == 'blood_bank') 'bloodBankId': orgId,
          if (orgType == 'society' || orgType == 'ngo') 'societyId': orgId,
          if (orgType == 'university') 'universityId': orgId,
        });
      }

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header note
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
                        'Create an organization manually. It will be activated immediately (auto-approved).',
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

              // Organization Details
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

              // Admin Account
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
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Create Organization', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
