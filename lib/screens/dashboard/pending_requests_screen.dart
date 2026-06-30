import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../services/firebase_service.dart';
import '../../widgets/blood_bridge_loader.dart';
import '../../widgets/top_snackbar.dart';

class PendingRequestsScreen extends StatefulWidget {
  const PendingRequestsScreen({super.key});
  @override
  _PendingRequestsScreenState createState() => _PendingRequestsScreenState();
}

class _PendingRequestsScreenState extends State<PendingRequestsScreen> {
  List<Map<String, dynamic>> _requests = [];
  bool _isLoading = true;
  String _filterStatus = 'pending';
  String? _currentEmail;
  String? _currentRole;
  bool _hasNewUpdates = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _loadData();
  }

  Future<void> _refresh() async {
    await _loadCurrentUser();
    await _loadData();
  }

  Future<void> _loadCurrentUser() async {
    if (FirebaseService.initialized) {
      final u = FirebaseAuth.instance.currentUser;
      _currentEmail = u?.email;
      if (u != null) {
        try {
          final snap = await FirebaseFirestore.instance.collection('users').doc(u.uid).get();
          if (snap.exists) _currentRole = snap.data()?['role']?.toString();
        } catch (_) {}
      }
    } else {
      final prefs = await SharedPreferences.getInstance();
      _currentEmail = prefs.getString('demo_current_email');
      final users = prefs.getStringList('demo_users') ?? <String>[];
      try {
        final me = users.map((s) => jsonDecode(s) as Map<String, dynamic>).firstWhere((u) => (u['email'] ?? '') == (_currentEmail ?? ''), orElse: () => <String, dynamic>{});
        _currentRole = me['role']?.toString();
      } catch (_) { _currentRole = null; }
    }
    setState(() {});
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    if (FirebaseService.initialized) {
      try {
        final snap = await FirebaseFirestore.instance.collection('donor_requests').get();
        _requests = snap.docs.map((d) { final m = d.data(); m['id'] = d.id; return m; }).where((r) => r['recipientEmail'] == _currentEmail || r['requesterEmail'] == _currentEmail || r['donorEmail'] == _currentEmail).toList();
      } catch (_) { _requests = []; }
    } else {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList('donor_requests') ?? [];
      _requests = raw.map((s) { try { return jsonDecode(s) as Map<String, dynamic>; } catch (_) { return <String, dynamic>{}; } }).where((r) => r.isNotEmpty && (r['recipientEmail'] == _currentEmail || r['requesterEmail'] == _currentEmail || r['donorEmail'] == _currentEmail)).toList();
    }
    _checkNewUpdates();
    setState(() => _isLoading = false);
  }

  Future<void> _checkNewUpdates() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSeen = prefs.getString('last_seen_requests_$_currentEmail') ?? '';
    bool hasNew = false;
    for (final r in _requests) {
      final status = r['status'] ?? 'pending';
      final updatedAt = r['updatedAt'] ?? r['requestedAt'] ?? '';
      if (status != 'pending' && updatedAt.toString().compareTo(lastSeen) > 0) {
        hasNew = true;
        break;
      }
    }
    _hasNewUpdates = hasNew;
    // ALWAYS mark as seen when user visits this screen
    await prefs.setString('last_seen_requests_$_currentEmail', DateTime.now().toIso8601String());
  }

  Future<void> _updateStatus(String id, String s) async {
    // Only admin/super_admin can approve/reject
    final role = _currentRole ?? '';
    if (role != 'admin' && role != 'super_admin') {
      showTopSnackBar(context, message: 'Only admin can approve or reject requests');
      return;
    }
    if (FirebaseService.initialized) {
      await FirebaseFirestore.instance.collection('donor_requests').doc(id).update({
        'status': s,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } else {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList('donor_requests') ?? [];
      final updated = raw.map((r) {
        try { final m = jsonDecode(r); if (m['id'] == id) { m['status'] = s; m['updatedAt'] = DateTime.now().toIso8601String(); } return jsonEncode(m); } catch (_) { return r; }
      }).toList();
      await prefs.setStringList('donor_requests', updated);
    }
    _loadData();
  }

  bool get _isAdmin => _currentRole == 'admin' || _currentRole == 'super_admin';

  List<Map<String, dynamic>> get _filtered {
    final list = _requests.where((r) {
      final s = r['status'] ?? 'pending';
      if (_filterStatus == 'all') return true;
      if (_filterStatus == 'approved') return s == 'approved' || s == 'accepted';
      return s == _filterStatus;
    }).toList();
    list.sort((a, b) => (b['requestedAt'] ?? b['createdAt'] ?? '').compareTo(a['requestedAt'] ?? a['createdAt'] ?? ''));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('My Requests', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFD32F2F), Color(0xFFE57373)], begin: Alignment.topLeft, end: Alignment.bottomRight))),
        iconTheme: const IconThemeData(color: Colors.white), elevation: 0,
      ),
      body: _isLoading ? const Center(child: BloodBridgeLoader()) : Column(children: [
        Container(padding: const EdgeInsets.all(12), child: Row(children: [
          _tab('Pending', 'pending'), const SizedBox(width: 6),
          _tab('Approved', 'approved'), const SizedBox(width: 6),
          _tab('Rejected', 'rejected'), const SizedBox(width: 6),
          _tab('All', 'all'),
        ])),
        Expanded(child: list.isEmpty ? Center(child: Text('No $_filterStatus requests', style: TextStyle(color: Colors.grey.shade500))) : RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.separated(padding: const EdgeInsets.symmetric(horizontal: 12), itemCount: list.length, separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) => _buildItem(list[i])),
        )),
      ]),
    );
  }

  Widget _tab(String label, String status) {
    final count = _requests.where((r) {
      final s = r['status'] ?? 'pending';
      if (status == 'all') return true;
      if (status == 'approved') return s == 'approved' || s == 'accepted';
      return s == status;
    }).length;
    final active = _filterStatus == status;
    return Expanded(child: InkWell(
      onTap: () => setState(() => _filterStatus = status),
      child: Container(padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(
        color: active ? const Color(0xFFD32F2F) : Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
        child: Text('$label ($count)', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: active ? Colors.white : Colors.grey.shade700)),
      ),
    ));
  }

  Widget _buildItem(Map<String, dynamic> r) {
    final status = (r['status'] ?? 'pending').toString();
    final isPending = status == 'pending';
    final isApproved = status == 'approved' || status == 'accepted';
    final donor = r['donorName'] ?? r['donorEmail'] ?? 'Unknown';
    final bg = r['bloodGroup'] ?? 'N/A';
    final msg = r['message'] ?? '';
    final id = r['id'] ?? '';
    final cooldownUntil = r['cooldownUntil']?.toString();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        leading: CircleAvatar(radius: 18, backgroundColor: isApproved ? Colors.green.shade100 : isPending ? Colors.orange.shade100 : Colors.red.shade100,
          child: Icon(isApproved ? Icons.check_circle : isPending ? Icons.pending : Icons.cancel, color: isApproved ? Colors.green : isPending ? Colors.orange : Colors.red, size: 22)),
        title: Text('$donor • $bg', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (msg.isNotEmpty) Text(msg, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          Text(status.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isApproved ? Colors.green : isPending ? Colors.orange : Colors.red)),
          if (cooldownUntil != null)
            Text('⏳ Cooldown until: $cooldownUntil', style: const TextStyle(fontSize: 10, color: Colors.blueGrey)),
        ]),
        trailing: isPending && _isAdmin ? Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(icon: const Icon(Icons.check_circle_outline, color: Colors.green, size: 22), onPressed: () => _updateStatus(id, 'approved'), tooltip: 'Approve', padding: EdgeInsets.zero, constraints: const BoxConstraints()),
          const SizedBox(width: 4),
          IconButton(icon: const Icon(Icons.cancel_outlined, color: Colors.red, size: 22), onPressed: () => _updateStatus(id, 'rejected'), tooltip: 'Reject', padding: EdgeInsets.zero, constraints: const BoxConstraints()),
        ]) : null,
      ),
    );
  }
}
