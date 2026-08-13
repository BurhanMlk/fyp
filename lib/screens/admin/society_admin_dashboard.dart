import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/service_locator.dart';
import '../../widgets/blood_bridge_loader.dart';
import '../../widgets/top_snackbar.dart';

/// Society Admin Dashboard
/// Manages a single society: members, donors, events, campaigns.

class SocietyAdminDashboard extends StatefulWidget {
  const SocietyAdminDashboard({super.key});

  @override
  State<SocietyAdminDashboard> createState() => _SocietyAdminDashboardState();
}

class _SocietyAdminDashboardState extends State<SocietyAdminDashboard> {
  String? _societyId;
  String _societyName = '';
  Map<String, dynamic>? _societyData;
  int _totalMembers = 0;
  int _activeDonors = 0;
  int _totalDonations = 0;
  int _pendingRequests = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};
      _societyId = userData['societyId']?.toString();

      if (_societyId != null) {
        final orgDoc = await FirebaseFirestore.instance.collection('organizations').doc(_societyId).get();
        if (orgDoc.exists) {
          _societyData = orgDoc.data();
          _societyName = (_societyData?['name'] ?? 'Society').toString();
        }

        // Count members
        final membersSnap = await FirebaseFirestore.instance
            .collection('users')
            .where('societyId', isEqualTo: _societyId)
            .get();
        _totalMembers = membersSnap.docs.length;
        _activeDonors = membersSnap.docs.where((d) =>
            d.data()['isDonor'] == true && d.data()['approved'] == true).length;
      }
    } catch (e) {
      if (mounted) showTopSnackBar(context, message: 'Error: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _showAddMemberDialog() {
    final emailCtl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white.withOpacity(0.85),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade300, width: 1.5),
        ),
        title: const Text('Add Member'),
        content: TextField(
          controller: emailCtl,
          decoration: const InputDecoration(
            labelText: 'Member Email',
            hintText: 'Enter email to invite',
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final email = emailCtl.text.trim();
              if (email.isEmpty) return;

              // Find user by email and update their societyId
              try {
                final snap = await FirebaseFirestore.instance
                    .collection('users')
                    .where('email', isEqualTo: email)
                    .limit(1)
                    .get();

                if (snap.docs.isEmpty) {
                  showTopSnackBar(context, message: 'User not found with that email');
                  return;
                }

                final userId = snap.docs.first.id;
                final userData = snap.docs.first.data();
                await FirebaseFirestore.instance.collection('users').doc(userId).update({
                  'societyId': _societyId,
                  'universityId': _societyData?['universityId'],
                  'organizationId': _societyId,
                  'role': userData['isDonor'] == true ? 'donor' : 'volunteer',
                });

                Navigator.pop(context);
                showTopSnackBar(context, message: 'Member added!', backgroundColor: Colors.green.shade700);
                _loadData();
              } catch (e) {
                showTopSnackBar(context, message: 'Error: $e');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showCampaignDialog() {
    final titleCtl = TextEditingController();
    final descCtl = TextEditingController();
    final locationCtl = TextEditingController();
    final targetCtl = TextEditingController();
    DateTime date = DateTime.now().add(const Duration(days: 7));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white.withOpacity(0.85),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade300, width: 1.5),
          ),
          title: const Text('Create Blood Donation Campaign'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtl,
                  decoration: const InputDecoration(labelText: 'Campaign Title *'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descCtl,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 3,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: locationCtl,
                  decoration: const InputDecoration(labelText: 'Location'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: targetCtl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Target Blood Units'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: date,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) setDialogState(() => date = picked);
                  },
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: Text('${date.day}/${date.month}/${date.year}'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
              onPressed: () async {
                final title = titleCtl.text.trim();
                if (title.isEmpty) {
                  showTopSnackBar(context, message: 'Please enter a campaign title');
                  return;
                }
                Navigator.pop(ctx);
                try {
                  await FirebaseFirestore.instance.collection('campaigns').add({
                    'organizationId': _societyId,
                    'title': title,
                    'description': descCtl.text.trim(),
                    'location': locationCtl.text.trim(),
                    'targetUnits': int.tryParse(targetCtl.text.trim()) ?? 0,
                    'date': date.toIso8601String(),
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                  showTopSnackBar(context, message: 'Campaign created!', backgroundColor: Colors.green.shade700);
                } catch (e) {
                  showTopSnackBar(context, message: 'Error: $e');
                }
              },
              child: const Text('Create', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showEventDialog() {
    final titleCtl = TextEditingController();
    final descCtl = TextEditingController();
    final locationCtl = TextEditingController();
    DateTime date = DateTime.now().add(const Duration(days: 7));
    TimeOfDay time = const TimeOfDay(hour: 10, minute: 0);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white.withOpacity(0.85),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade300, width: 1.5),
          ),
          title: const Text('Create Donation Event'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtl,
                  decoration: const InputDecoration(labelText: 'Event Title *'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descCtl,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 3,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: locationCtl,
                  decoration: const InputDecoration(labelText: 'Location'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: date,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) setDialogState(() => date = picked);
                        },
                        icon: const Icon(Icons.calendar_today, size: 18),
                        label: Text('${date.day}/${date.month}/${date.year}'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showTimePicker(context: ctx, initialTime: time);
                          if (picked != null) setDialogState(() => time = picked);
                        },
                        icon: const Icon(Icons.access_time, size: 18),
                        label: Text(time.format(ctx)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
              onPressed: () async {
                final title = titleCtl.text.trim();
                if (title.isEmpty) {
                  showTopSnackBar(context, message: 'Please enter an event title');
                  return;
                }
                Navigator.pop(ctx);
                try {
                  await FirebaseFirestore.instance.collection('events').add({
                    'organizationId': _societyId,
                    'title': title,
                    'description': descCtl.text.trim(),
                    'location': locationCtl.text.trim(),
                    'date': date.toIso8601String(),
                    'time': '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                  showTopSnackBar(context, message: 'Event created!', backgroundColor: Colors.green.shade700);
                } catch (e) {
                  showTopSnackBar(context, message: 'Error: $e');
                }
              },
              child: const Text('Create', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showReportsDialog() async {
    // Show a lightweight loading indicator while fetching report data.
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final membersSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('societyId', isEqualTo: _societyId)
          .get();
      final members = membersSnap.docs;
      final donors = members.where((d) =>
          d.data()['isDonor'] == true && d.data()['approved'] == true).length;

      final bg = <String, int>{};
      for (final d in members) {
        final b = (d.data()['bloodGroup'] ?? '').toString();
        if (b.isNotEmpty) bg[b] = (bg[b] ?? 0) + 1;
      }

      final campaignsSnap = await FirebaseFirestore.instance
          .collection('campaigns')
          .where('organizationId', isEqualTo: _societyId)
          .get();
      final eventsSnap = await FirebaseFirestore.instance
          .collection('events')
          .where('organizationId', isEqualTo: _societyId)
          .get();

      if (!mounted) return;
      Navigator.pop(context); // close loading

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: Colors.white.withOpacity(0.85),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade300, width: 1.5),
          ),
          title: const Text('Society Report'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _reportRow('Total Members', members.length),
                _reportRow('Active Donors', donors),
                _reportRow('Campaigns', campaignsSnap.docs.length),
                _reportRow('Events', eventsSnap.docs.length),
                const Divider(height: 24),
                const Text('Blood Group Distribution', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (bg.isEmpty)
                  const Text('No blood group data yet', style: TextStyle(color: Colors.grey))
                else
                  ...bg.entries.map((e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Blood Group ${e.key}', style: const TextStyle(fontSize: 14)),
                        Text('${e.value}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        showTopSnackBar(context, message: 'Error loading report: $e');
      }
    }
  }

  Widget _reportRow(String label, int value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text('$value', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: BloodBridgeLoader()));

    if (_societyId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Society'), backgroundColor: Colors.red.shade700),
        body: const Center(child: Text('No society assigned to your account.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_societyName),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Society Info
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.green.shade100,
                        child: const Icon(Icons.groups, size: 30, color: Colors.green),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_societyName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            if (_societyData?['description'] != null)
                              Text(_societyData!['description'], style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Stats
              Row(
                children: [
                  _statCard('Members', '$_totalMembers', Icons.people, Colors.blue),
                  const SizedBox(width: 8),
                  _statCard('Donors', '$_activeDonors', Icons.volunteer_activism, Colors.red),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _statCard('Donations', '$_totalDonations', Icons.favorite, Colors.pink),
                  const SizedBox(width: 8),
                  _statCard('Requests', '$_pendingRequests', Icons.bloodtype, Colors.orange),
                ],
              ),
              const SizedBox(height: 20),

              // Quick Actions
              const Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _actionCard(Icons.person_add, 'Add Member', _showAddMemberDialog),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _actionCard(Icons.campaign, 'Campaign', _showCampaignDialog),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _actionCard(Icons.event, 'Create Event', _showEventDialog),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _actionCard(Icons.analytics, 'Reports', _showReportsDialog),
                  ),
                ],
              ),
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
              Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 11), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
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
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Icon(icon, color: Colors.red.shade700, size: 32),
                const SizedBox(height: 8),
                Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
