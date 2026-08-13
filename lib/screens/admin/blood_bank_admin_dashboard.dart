import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/service_locator.dart';
import '../../models/blood_inventory_model.dart';
import '../../widgets/blood_bridge_loader.dart';
import '../../widgets/top_snackbar.dart';

/// Blood Bank Admin Dashboard
/// Allows blood bank admins to manage their own blood inventory,
/// view requests, and manage staff.

class BloodBankAdminDashboard extends StatefulWidget {
  const BloodBankAdminDashboard({super.key});

  @override
  State<BloodBankAdminDashboard> createState() => _BloodBankAdminDashboardState();
}

class _BloodBankAdminDashboardState extends State<BloodBankAdminDashboard> {
  String? _bloodBankId;
  String _bloodBankName = '';
  List<BloodInventoryModel> _inventory = [];
  Map<String, int> _bloodGroupSummary = {};
  int _totalUnits = 0;
  int _lowStockCount = 0;
  int _expiringSoonCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBloodBankData();
  }

  Future<void> _loadBloodBankData({bool showLoader = true}) async {
    if (showLoader) setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Get user's blood bank ID
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};
      _bloodBankId = userData['bloodBankId']?.toString();

      if (_bloodBankId == null) return;

      // Get blood bank details
      final orgDoc = await FirebaseFirestore.instance.collection('organizations').doc(_bloodBankId).get();
      if (orgDoc.exists) {
        _bloodBankName = (orgDoc.data()?['name'] ?? 'Blood Bank').toString();
      }

      // Load inventory
      _inventory = await sl.bloodInventory.getInventoryForBloodBank(_bloodBankId!);
      _bloodGroupSummary = await sl.bloodInventory.getBloodGroupSummary(_bloodBankId!);
      _totalUnits = await sl.bloodInventory.getTotalAvailableUnits(_bloodBankId!);

      _lowStockCount = _inventory.where((i) => i.status == 'low_stock').length;
      _expiringSoonCount = _inventory.where((i) => i.status == 'expiring_soon').length;
    } catch (e) {
      if (mounted) showTopSnackBar(context, message: 'Error: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _showAddInventoryDialog() {
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
                  subtitle: Text('${collectionDate.toLocal()}'.split(' ')[0]),
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
                  subtitle: Text('${expiryDate.toLocal()}'.split(' ')[0]),
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
              onPressed: () async {
                final qty = int.tryParse(quantityCtl.text) ?? 1;
                final inventory = BloodInventoryModel(
                  id: '',
                  bloodBankId: _bloodBankId!,
                  bloodGroup: selectedGroup,
                  quantity: qty,
                  collectionDate: collectionDate,
                  expiryDate: expiryDate,
                );
                try {
                  await sl.bloodInventory.addInventory(inventory);
                  Navigator.pop(ctx);
                  _loadBloodBankData(showLoader: false);
                  showTopSnackBar(context, message: 'Blood unit added!', backgroundColor: Colors.green.shade700);
                } catch (e) {
                  showTopSnackBar(context, message: 'Error: $e');
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
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

  DateTime? _nearestExpiryFor(String bg) {
    DateTime? nearest;
    for (final item in _inventory) {
      if (item.bloodGroup != bg) continue;
      if (item.status == 'expired' || item.status == 'used') continue;
      if (nearest == null || item.expiryDate.isBefore(nearest)) {
        nearest = item.expiryDate;
      }
    }
    return nearest;
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

    if (_bloodBankId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Blood Bank'), backgroundColor: Colors.red.shade700),
        body: const Center(child: Text('No blood bank assigned to your account.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_bloodBankName),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => _loadBloodBankData(showLoader: false)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadBloodBankData(showLoader: false),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stats Cards
              Row(
                children: [
                  _statCard('Total Units', '$_totalUnits', Icons.bloodtype, Colors.red),
                  const SizedBox(width: 8),
                  _statCard('Low Stock', '$_lowStockCount', Icons.warning_amber, Colors.orange),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _statCard('Expiring Soon', '$_expiringSoonCount', Icons.timer, Colors.amber),
                  const SizedBox(width: 8),
                  _statCard('Groups', '${_bloodGroupSummary.length}', Icons.pie_chart, Colors.blue),
                ],
              ),
              const SizedBox(height: 20),

              // Blood Group Summary
              const Text('Blood Group Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (_bloodGroupSummary.isEmpty)
                const Card(child: Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No inventory yet'))))
              else
                ..._bloodGroupSummary.entries
                    .where((e) => e.key.isNotEmpty && e.value > 0)
                    .map((entry) {
                      final bg = entry.key;
                      final count = entry.value;
                      final nearest = _nearestExpiryFor(bg);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 4),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _bloodGroupColor(bg),
                            child: Text(bg, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                          title: Text('$bg - $count units'),
                          subtitle: nearest != null
                              ? Text('Expires: ${_formatDate(nearest)}')
                              : null,
                          trailing: count <= 5
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(12)),
                                  child: const Text('Low', style: TextStyle(color: Colors.orange, fontSize: 11)),
                                )
                              : null,
                        ),
                      );
                    }),
              const SizedBox(height: 20),

              // Recent Inventory
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Inventory Records', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  TextButton.icon(
                    onPressed: _showAddInventoryDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Unit'),
                  ),
                ],
              ),
              if (_inventory.isEmpty)
                const Card(child: Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No inventory records'))))
              else
                ..._inventory.take(10).map((item) => Card(
                  margin: const EdgeInsets.only(bottom: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _bloodGroupColor(item.bloodGroup),
                      child: Text(item.bloodGroup, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    title: Text('${item.quantity} ${item.unit}'),
                    subtitle: Text('Expires: ${_formatDate(item.expiryDate)}'),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: item.status == 'expired' ? Colors.red.shade100 :
                               item.status == 'expiring_soon' ? Colors.orange.shade100 :
                               item.status == 'low_stock' ? Colors.amber.shade100 :
                               Colors.green.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        item.status.replaceAll('_', ' ').toUpperCase(),
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: item.status == 'expired' ? Colors.red : Colors.green.shade700),
                      ),
                    ),
                    onTap: () async {
                      // Edit/remove quantity
                      final qtyCtl = TextEditingController(text: '${item.quantity}');
                      final result = await showDialog<String>(
                        context: context,
                        builder: (_) => AlertDialog(
                          backgroundColor: Colors.white.withOpacity(0.85),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                          ),
                          title: Text('Update ${item.bloodGroup}'),
                          content: TextField(
                            controller: qtyCtl,
                            decoration: const InputDecoration(labelText: 'New Quantity'),
                            keyboardType: TextInputType.number,
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, 'delete'),
                              child: const Text('Delete', style: TextStyle(color: Colors.red)),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context, qtyCtl.text),
                              child: const Text('Update'),
                            ),
                          ],
                        ),
                      );
                      if (result == 'delete') {
                        await sl.bloodInventory.deleteInventory(item.id);
                        _loadBloodBankData(showLoader: false);
                      } else if (result != null) {
                        final newQty = int.tryParse(result) ?? item.quantity;
                        await sl.bloodInventory.updateQuantity(item.id, newQty);
                        _loadBloodBankData(showLoader: false);
                      }
                    },
                  ),
                )),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
