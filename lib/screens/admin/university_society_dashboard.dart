import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/service_locator.dart';
import '../../models/blood_inventory_model.dart';
import '../../widgets/blood_bridge_loader.dart';
import '../../widgets/top_snackbar.dart';

/// University Society Admin Dashboard
///
/// A society (registered under a university) can:
///  - Add & manage donors
///  - Create / manage a linked blood bank
///  - Add & view blood inventory for that blood bank
///
/// NGOs keep using the classic [SocietyAdminDashboard].

class UniversitySocietyDashboard extends StatefulWidget {
  const UniversitySocietyDashboard({super.key});

  @override
  State<UniversitySocietyDashboard> createState() => _UniversitySocietyDashboardState();
}

class _UniversitySocietyDashboardState extends State<UniversitySocietyDashboard> {
  String? _societyId;
  String _societyName = '';
  Map<String, dynamic>? _societyData;

  List<Map<String, dynamic>> _donors = [];
  Map<String, dynamic>? _bloodBank; // linked blood bank org doc (+ 'id')
  List<BloodInventoryModel> _inventory = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({bool showLoader = true}) async {
    if (showLoader && mounted) setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};
      _societyId = userData['societyId']?.toString();

      if (_societyId == null) return;

      // Society info
      final orgDoc = await FirebaseFirestore.instance.collection('organizations').doc(_societyId).get();
      if (orgDoc.exists) {
        _societyData = orgDoc.data();
        _societyName = (_societyData?['name'] ?? 'University Society').toString();
      }

      // Donors (users linked to this society)
      final donorsSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('societyId', isEqualTo: _societyId)
          .get();
      _donors = donorsSnap.docs
          .where((d) => d.data()['isDonor'] == true || d.data()['role'] == 'donor')
          .map((d) {
        final data = d.data();
        data['id'] = d.id;
        return data;
      }).toList();

      // Linked blood bank (created by this society)
      final bbSnap = await FirebaseFirestore.instance
          .collection('organizations')
          .where('societyId', isEqualTo: _societyId)
          .limit(1)
          .get();
      if (bbSnap.docs.isNotEmpty) {
        final bbDoc = bbSnap.docs.first;
        _bloodBank = bbDoc.data();
        _bloodBank!['id'] = bbDoc.id;
        _inventory = await sl.bloodInventory.getInventoryForBloodBank(bbDoc.id);
      } else {
        _bloodBank = null;
        _inventory = [];
      }
    } catch (e) {
      if (mounted) showTopSnackBar(context, message: 'Error: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  // ─────────────────────────── ADD DONOR ───────────────────────────
  void _showAddDonorDialog() {
    final nameCtl = TextEditingController();
    final deptCtl = TextEditingController();
    final cnicCtl = TextEditingController();
    final emailCtl = TextEditingController();
    final contactCtl = TextEditingController();
    final whatsappCtl = TextEditingController();
    String bloodGroup = 'O+';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white.withOpacity(0.85),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade300, width: 1.5),
          ),
          title: const Text('Add Donor'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nameCtl, decoration: const InputDecoration(labelText: 'Name *')),
                  const SizedBox(height: 8),
                  TextField(controller: deptCtl, decoration: const InputDecoration(labelText: 'Department')),
                  const SizedBox(height: 8),
                  TextField(
                    controller: cnicCtl,
                    decoration: const InputDecoration(labelText: 'CNIC'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: emailCtl,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: bloodGroup,
                    decoration: const InputDecoration(labelText: 'Blood Group'),
                    items: const ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']
                        .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                        .toList(),
                    onChanged: (v) => setDialogState(() => bloodGroup = v!),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: contactCtl,
                    decoration: const InputDecoration(labelText: 'Contact Number'),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: whatsappCtl,
                    decoration: const InputDecoration(labelText: 'WhatsApp Number'),
                    keyboardType: TextInputType.phone,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
              onPressed: () async {
                final name = nameCtl.text.trim();
                if (name.isEmpty) {
                  showTopSnackBar(context, message: 'Name is required');
                  return;
                }
                Navigator.pop(ctx);
                try {
                  await FirebaseFirestore.instance.collection('users').add({
                    'name': name,
                    'department': deptCtl.text.trim(),
                    'cnic': cnicCtl.text.trim(),
                    'email': emailCtl.text.trim(),
                    'bloodGroup': bloodGroup,
                    'contact': contactCtl.text.trim(),
                    'whatsapp': whatsappCtl.text.trim(),
                    'role': 'donor',
                    'isDonor': true,
                    'approved': true,
                    'available': true,
                    'societyId': _societyId,
                    'universityId': _societyData?['universityId'],
                    'organizationId': _societyId,
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                  showTopSnackBar(context, message: 'Donor added!', backgroundColor: Colors.green.shade700);
                  _loadData(showLoader: false);
                } catch (e) {
                  showTopSnackBar(context, message: 'Error: $e');
                }
              },
              child: const Text('Add', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _approveDonor(Map<String, dynamic> donor) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(donor['id']).update({'approved': true});
      showTopSnackBar(context, message: '${donor['name'] ?? 'Donor'} approved', backgroundColor: Colors.green.shade700);
      _loadData(showLoader: false);
    } catch (e) {
      showTopSnackBar(context, message: 'Error: $e');
    }
  }

  Future<void> _removeDonor(Map<String, dynamic> donor) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(donor['id']).update({
        'societyId': FieldValue.delete(),
        'universityId': FieldValue.delete(),
        'organizationId': FieldValue.delete(),
        'isDonor': false,
        'approved': false,
      });
      showTopSnackBar(context, message: 'Donor removed from society', backgroundColor: Colors.orange.shade700);
      _loadData(showLoader: false);
    } catch (e) {
      showTopSnackBar(context, message: 'Error: $e');
    }
  }

  // ─────────────────────────── BLOOD BANK ───────────────────────────
  void _showAddBloodBankDialog() {
    final nameCtl = TextEditingController();
    final emailCtl = TextEditingController();
    final phoneCtl = TextEditingController();
    final cityCtl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white.withOpacity(0.85),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade300, width: 1.5),
        ),
        title: const Text('Add Blood Bank'),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtl, decoration: const InputDecoration(labelText: 'Blood Bank Name *')),
                const SizedBox(height: 8),
                TextField(controller: emailCtl, decoration: const InputDecoration(labelText: 'Organization Email')),
                const SizedBox(height: 8),
                TextField(controller: phoneCtl, decoration: const InputDecoration(labelText: 'Phone')),
                const SizedBox(height: 8),
                TextField(controller: cityCtl, decoration: const InputDecoration(labelText: 'City')),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () async {
              final name = nameCtl.text.trim();
              if (name.isEmpty) {
                showTopSnackBar(context, message: 'Blood bank name is required');
                return;
              }
              Navigator.pop(ctx);
              try {
                final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
                await FirebaseFirestore.instance.collection('organizations').add({
                  'type': 'blood_bank',
                  'name': name,
                  'email': emailCtl.text.trim(),
                  'phone': phoneCtl.text.trim(),
                  'city': cityCtl.text.trim(),
                  'societyId': _societyId,
                  'universityId': _societyData?['universityId'],
                  'adminId': uid,
                  'status': 'active',
                  'createdAt': FieldValue.serverTimestamp(),
                  'updatedAt': FieldValue.serverTimestamp(),
                });
                showTopSnackBar(context, message: 'Blood bank added!', backgroundColor: Colors.green.shade700);
                _loadData(showLoader: false);
              } catch (e) {
                showTopSnackBar(context, message: 'Error: $e');
              }
            },
            child: const Text('Create', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────── INVENTORY ───────────────────────────
  void _showAddInventoryDialog() {
    if (_bloodBank == null) return;
    final bloodBankId = _bloodBank!['id'].toString();

    String selectedGroup = 'O+';
    final quantityCtl = TextEditingController(text: '1');
    DateTime collectionDate = DateTime.now();
    DateTime expiryDate = DateTime.now().add(const Duration(days: 35));

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white.withOpacity(0.85),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade300, width: 1.5),
          ),
          title: const Text('Add Blood Unit'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedGroup,
                  decoration: const InputDecoration(labelText: 'Blood Group'),
                  items: const [
                    'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-',
                  ].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                  onChanged: (v) => setDialogState(() => selectedGroup = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: quantityCtl,
                  decoration: const InputDecoration(labelText: 'Quantity (units)'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                ListTile(
                  title: const Text('Collection Date'),
                  subtitle: Text(_formatDate(collectionDate)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: ctx,
                      initialDate: collectionDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) setDialogState(() => collectionDate = date);
                  },
                ),
                ListTile(
                  title: const Text('Expiry Date'),
                  subtitle: Text(_formatDate(expiryDate)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: ctx,
                      initialDate: expiryDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) setDialogState(() => expiryDate = date);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
              onPressed: () async {
                final qty = int.tryParse(quantityCtl.text) ?? 1;
                final inventory = BloodInventoryModel(
                  id: '',
                  bloodBankId: bloodBankId,
                  bloodGroup: selectedGroup,
                  quantity: qty,
                  collectionDate: collectionDate,
                  expiryDate: expiryDate,
                );
                try {
                  await sl.bloodInventory.addInventory(inventory);
                  Navigator.pop(ctx);
                  showTopSnackBar(context, message: 'Blood unit added!', backgroundColor: Colors.green.shade700);
                  _loadData(showLoader: false);
                } catch (e) {
                  showTopSnackBar(context, message: 'Error: $e');
                }
              },
              child: const Text('Add', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Color _bloodGroupColor(String bg) {
    if (bg.contains('O')) return Colors.red.shade600;
    if (bg.contains('A')) return Colors.blue.shade600;
    if (bg.contains('B')) return Colors.green.shade600;
    return Colors.purple.shade600;
  }

  String _formatDate(DateTime d) {
    final local = d.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    return '${local.year}-$mm-$dd';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: BloodBridgeLoader()));

    if (_societyId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('University Society'), backgroundColor: Colors.red.shade700),
        body: const Center(child: Text('No society assigned to your account.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_societyName),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => _loadData(showLoader: false)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadData(showLoader: false),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.green.shade100,
                        child: const Icon(Icons.groups, size: 28, color: Colors.green),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_societyName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            if (_societyData?['email'] != null)
                              Text(_societyData!['email'], style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Quick actions
              Row(
                children: [
                  Expanded(child: _actionCard(Icons.person_add, 'Add Donor', _showAddDonorDialog)),
                  const SizedBox(width: 8),
                  Expanded(child: _actionCard(Icons.local_hospital, 'Add Blood Bank', _showAddBloodBankDialog)),
                  const SizedBox(width: 8),
                  Expanded(child: _actionCard(Icons.bloodtype, 'Add Unit', _showAddInventoryDialog)),
                ],
              ),
              const SizedBox(height: 20),

              // Donors section
              _sectionHeader('Donors', '${_donors.length}'),
              const SizedBox(height: 8),
              if (_donors.isEmpty)
                const Card(child: Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No donors yet'))))
              else
                ..._donors.map((donor) => Card(
                  margin: const EdgeInsets.only(bottom: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.red.shade100,
                      child: const Icon(Icons.person, color: Colors.red),
                    ),
                    title: Text(donor['name'] ?? 'Donor', style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      [
                        if (donor['department']?.toString().isNotEmpty == true) donor['department'].toString(),
                        if (donor['bloodGroup']?.toString().isNotEmpty == true) donor['bloodGroup'].toString(),
                        if (donor['contact']?.toString().isNotEmpty == true) donor['contact'].toString(),
                        if (donor['whatsapp']?.toString().isNotEmpty == true) 'WhatsApp: ${donor['whatsapp']}',
                      ].join(' • '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (donor['approved'] != true)
                          IconButton(
                            icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                            tooltip: 'Approve',
                            onPressed: () => _approveDonor(donor),
                          ),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                          tooltip: 'Remove',
                          onPressed: () => _removeDonor(donor),
                        ),
                      ],
                    ),
                  ),
                )),
              const SizedBox(height: 20),

              // Blood bank section
              _sectionHeader('Linked Blood Bank', _bloodBank == null ? '0' : '1'),
              const SizedBox(height: 8),
              if (_bloodBank == null)
                const Card(child: Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No blood bank linked yet — tap "Add Blood Bank"'))))
              else
                Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.orange.shade100,
                      child: const Icon(Icons.local_hospital, color: Colors.orange),
                    ),
                    title: Text(_bloodBank!['name'] ?? 'Blood Bank', style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(_bloodBank!['city']?.toString() ?? ''),
                    trailing: TextButton.icon(
                      onPressed: _showAddInventoryDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Unit'),
                    ),
                  ),
                ),
              const SizedBox(height: 20),

              // Inventory section
              _sectionHeader('Blood Inventory', '${_inventory.length}'),
              const SizedBox(height: 8),
              if (_inventory.isEmpty)
                const Card(child: Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No inventory records'))))
              else
                ..._inventory.map((item) => Card(
                  margin: const EdgeInsets.only(bottom: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _bloodGroupColor(item.bloodGroup),
                      child: Text(item.bloodGroup, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    title: Text('${item.quantity} ${item.unit}'),
                    subtitle: Text('Expires: ${_formatDate(item.expiryDate)}'),
                    trailing: Text(
                      item.status.replaceAll('_', ' ').toUpperCase(),
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: item.status == 'expired' ? Colors.red : Colors.green.shade700),
                    ),
                  ),
                )),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, String count) {
    return Row(
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(width: 8),
        Text('($count)', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
      ],
    );
  }

  Widget _actionCard(IconData icon, String label, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300, width: 1.2),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Icon(icon, color: Colors.red.shade700, size: 26),
                const SizedBox(height: 6),
                Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12), textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
