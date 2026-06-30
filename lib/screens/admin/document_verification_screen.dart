import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../../services/firebase_service.dart';
import '../../widgets/blood_bridge_loader.dart';
import '../../widgets/top_snackbar.dart';

class DocumentVerificationScreen extends StatefulWidget {
  const DocumentVerificationScreen({super.key});

  @override
  _DocumentVerificationScreenState createState() => _DocumentVerificationScreenState();
}

class _DocumentVerificationScreenState extends State<DocumentVerificationScreen> with WidgetsBindingObserver {
  List<Map<String, dynamic>> _allDocuments = [];
  bool _isLoading = true;
  int _selectedTabIndex = 0; // 0=Pending, 1=Verified, 2=All
  String _searchQuery = '';

  static const List<Map<String, String>> _docTypeConfig = [
    {'type': 'id_front', 'label': 'ID Front', 'emoji': ''},
    {'type': 'id_back', 'label': 'ID Back', 'emoji': ''},
    {'type': 'blood_test', 'label': 'Blood Test', 'emoji': ''},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadDocuments();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadDocuments();
    }
  }

  Future<void> _loadDocuments() async {
    setState(() => _isLoading = true);
    
    try {
      if (FirebaseService.initialized) {
        final snap = await FirebaseFirestore.instance
            .collection('verificationDocuments')
            .get();
        
        setState(() {
          _allDocuments = snap.docs.map((doc) {
            final data = doc.data();
            data['docId'] = doc.id;
            return data;
          }).toList();
          // Sort by uploadedAt descending
          _allDocuments.sort((a, b) => 
            (b['uploadedAt'] ?? '').toString().compareTo((a['uploadedAt'] ?? '').toString()));
        });
      } else {
        final prefs = await SharedPreferences.getInstance();
        final docsJson = prefs.getStringList('demo_verification_documents') ?? [];
        setState(() {
          _allDocuments = docsJson.map((s) => jsonDecode(s) as Map<String, dynamic>).toList();
        });
      }
    } catch (e) {
      print('❌ Error loading documents: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Group documents by userId → returns Map<userId, {userInfo, docs}>
  Map<String, Map<String, dynamic>> _groupByRecipient() {
    final grouped = <String, Map<String, dynamic>>{};
    for (final doc in _allDocuments) {
      final userId = doc['userId'] ?? 'unknown';
      if (!grouped.containsKey(userId)) {
        grouped[userId] = {
          'userId': userId,
          'userName': doc['userName'] ?? 'Unknown',
          'userEmail': doc['userEmail'] ?? 'N/A',
          'docs': <String, Map<String, dynamic>?>{'id_front': null, 'id_back': null, 'blood_test': null},
        };
      }
      final docType = doc['documentType'] ?? '';
      if (grouped[userId]!['docs'].containsKey(docType)) {
        grouped[userId]!['docs'][docType] = doc;
      }
    }
    return grouped;
  }

  List<Map<String, dynamic>> _getFilteredRecipients() {
    final grouped = _groupByRecipient();
    var recipients = grouped.values.toList();

    // Search filter by name or email
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      recipients = recipients.where((r) {
        final name = (r['userName'] ?? '').toString().toLowerCase();
        final email = (r['userEmail'] ?? '').toString().toLowerCase();
        return name.contains(q) || email.contains(q);
      }).toList();
    }

    if (_selectedTabIndex == 0) {
      // Pending: at least one doc is pending
      return recipients.where((r) {
        final docs = r['docs'] as Map<String, dynamic>;
        return docs.values.any((d) => d != null && d['status'] == 'pending');
      }).toList();
    } else if (_selectedTabIndex == 1) {
      // Verified: all docs are verified
      return recipients.where((r) {
        final docs = r['docs'] as Map<String, dynamic>;
        final nonNullDocs = docs.values.where((d) => d != null).toList();
        return nonNullDocs.isNotEmpty && nonNullDocs.every((d) => d['status'] == 'verified');
      }).toList();
    }
    // All
    return recipients;
  }

  int get _pendingCount {
    return _allDocuments.where((d) => d['status'] == 'pending').length;
  }

  int get _verifiedCount {
    return _allDocuments.where((d) => d['status'] == 'verified').length;
  }

  int get _pendingRecipientsCount {
    final grouped = _groupByRecipient();
    return grouped.values.where((r) {
      final docs = r['docs'] as Map<String, dynamic>;
      return docs.values.any((d) => d != null && d['status'] == 'pending');
    }).length;
  }

  int get _verifiedRecipientsCount {
    final grouped = _groupByRecipient();
    return grouped.values.where((r) {
      final docs = r['docs'] as Map<String, dynamic>;
      final nonNullDocs = docs.values.where((d) => d != null).toList();
      return nonNullDocs.isNotEmpty && nonNullDocs.every((d) => d['status'] == 'verified');
    }).length;
  }

  Future<void> _approveDocument(Map<String, dynamic> doc) async {
    await _updateDocStatus(doc, 'verified');
    _showSnack('Document approved');
  }

  Future<void> _rejectDocument(Map<String, dynamic> doc) async {
    await _updateDocStatus(doc, 'rejected');
    _showSnack('Document rejected');
  }

  Future<void> _deleteDocument(Map<String, dynamic> doc) async {
    final docId = doc['docId'];
    if (docId == null) return;

    try {
      if (FirebaseService.initialized) {
        await FirebaseFirestore.instance
            .collection('verificationDocuments')
            .doc(docId)
            .delete();
      } else {
        final prefs = await SharedPreferences.getInstance();
        final docsJson = prefs.getStringList('demo_verification_documents') ?? [];
        final updated = docsJson.where((s) {
          final d = jsonDecode(s);
          return d['docId'] != docId;
        }).toList();
        await prefs.setStringList('demo_verification_documents', updated);
      }
      _showSnack('Document deleted');
      await _loadDocuments();
    } catch (e) {
      _showSnack('Error deleting: $e', isError: true);
    }
  }

  Future<void> _updateDocStatus(Map<String, dynamic> doc, String status) async {
    final docId = doc['docId'];
    final userId = doc['userId'];
    if (docId == null) return;

    try {
      if (FirebaseService.initialized) {
        await FirebaseFirestore.instance
            .collection('verificationDocuments')
            .doc(docId)
            .update({
          'status': status,
          'verifiedAt': status == 'verified' ? FieldValue.serverTimestamp() : null,
          'verifiedBy': FirebaseAuth.instance.currentUser?.uid,
        });

        if (status == 'verified') {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .update({
            'documentsVerified': true,
            'verificationDatetime': FieldValue.serverTimestamp(),
          });
        }
      } else {
        final prefs = await SharedPreferences.getInstance();
        final docsJson = prefs.getStringList('demo_verification_documents') ?? [];
        final allDocs = docsJson.map((s) => jsonDecode(s) as Map<String, dynamic>).toList();
        final index = allDocs.indexWhere((d) => d['docId'] == docId);
        if (index != -1) {
          allDocs[index]['status'] = status;
          allDocs[index]['verifiedAt'] = DateTime.now().toIso8601String();
          allDocs[index]['verifiedBy'] = 'demo_admin';
          await prefs.setStringList('demo_verification_documents', 
              allDocs.map((d) => jsonEncode(d)).toList());
        }
        if (status == 'verified') {
          final usersList = prefs.getStringList('demo_users') ?? [];
          final uIdx = usersList.indexWhere((s) {
            final u = jsonDecode(s);
            return u['uid'] == userId;
          });
          if (uIdx != -1) {
            final user = jsonDecode(usersList[uIdx]) as Map<String, dynamic>;
            user['documentsVerified'] = true;
            usersList[uIdx] = jsonEncode(user);
            await prefs.setStringList('demo_users', usersList);
          }
        }
      }
      await _loadDocuments();
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    showTopSnackBar(context, message: message, backgroundColor: isError ? Colors.red : Colors.green);
  }

  void _showDocPreview(Map<String, dynamic> doc) {
    final fileData = doc['fileData'] as String?;
    final fileName = doc['fileName'] as String? ?? 'Document';
    if (fileData == null || fileData.isEmpty) return;

    final isPdf = fileName.toLowerCase().endsWith('.pdf');
    ImageProvider? imageProvider;
    if (!isPdf) {
      try {
        final bytes = base64Decode(fileData);
        imageProvider = MemoryImage(Uint8List.fromList(bytes));
      } catch (_) {}
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: isPdf
                  ? Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Icon(Icons.picture_as_pdf, size: 64, color: Colors.red[400]),
                          const SizedBox(height: 12),
                          Text(fileName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )
                  : imageProvider != null
                      ? InteractiveViewer(
                          maxScale: 5.0,
                          child: Image(image: imageProvider, fit: BoxFit.contain),
                        )
                      : const Icon(Icons.broken_image, size: 64, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(fileName, style: const TextStyle(color: Colors.white, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: BloodBridgeLoader());
    }

    final recipients = _getFilteredRecipients();

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Documents Verification',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey[800]),
                ),
                IconButton(
                  onPressed: _loadDocuments,
                  icon: Icon(Icons.refresh, color: Colors.grey[600]),
                  tooltip: 'Refresh',
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Review, approve, or delete recipient documents',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),

            // Search Bar
            TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Search recipient by name or email...',
                hintStyle: TextStyle(fontSize: 14),
                prefixIcon: Icon(Icons.search, color: Colors.grey[600], size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, size: 18, color: Colors.grey[600]),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Color(0xFFD32F2F), width: 2),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Stats Cards Row
            Row(
              children: [
                Expanded(
                  child: _buildStatCard('Pending', _pendingCount.toString(), Colors.orange, Icons.pending_actions),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildStatCard('Verified', _verifiedCount.toString(), Colors.green, Icons.verified_user),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildStatCard('Recipients', '${_groupByRecipient().length}', Colors.blue, Icons.people),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 3 Tabs
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  _buildTab('Pending', 0, _pendingRecipientsCount),
                  _buildTab('Verified', 1, _verifiedRecipientsCount),
                  _buildTab('All', 2, _groupByRecipient().length),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Recipients List
            if (recipients.isEmpty)
              _buildEmptyState()
            else
              ...recipients.map((recipient) => _buildRecipientCard(recipient)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 40),
          Icon(Icons.inbox_rounded, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            _selectedTabIndex == 0 ? 'No pending documents' : 
            _selectedTabIndex == 1 ? 'No verified recipients yet' : 'No documents found',
            style: TextStyle(fontSize: 16, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String label, int index, int count) {
    final isSelected = _selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTabIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected ? [
              BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 2)),
            ] : null,
          ),
          child: Column(
            children: [
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? const Color(0xFFD32F2F) : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFD32F2F).withOpacity(0.1) : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? const Color(0xFFD32F2F) : Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String count, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: color.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 10),
          Text(count, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey[800])),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildRecipientCard(Map<String, dynamic> recipient) {
    final userName = recipient['userName'] ?? 'Unknown';
    final userEmail = recipient['userEmail'] ?? 'N/A';
    final docs = recipient['docs'] as Map<String, dynamic>;

    // Determine overall status
    final nonNullDocs = docs.values.where((d) => d != null).toList();
    final hasPending = nonNullDocs.any((d) => d['status'] == 'pending');
    final allVerified = nonNullDocs.isNotEmpty && nonNullDocs.every((d) => d['status'] == 'verified');
    final overallStatus = allVerified ? 'Verified' : (hasPending ? 'Pending' : 'No Docs');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: allVerified ? Colors.green.shade300 : (hasPending ? Colors.orange.shade300 : Colors.grey.shade300),
          width: 2,
        ),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Recipient Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: allVerified ? Colors.green.shade50 : (hasPending ? Colors.orange.shade50 : Colors.grey.shade50),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: allVerified ? Colors.green : (hasPending ? Colors.orange : Colors.grey),
                  radius: 22,
                  child: Text(
                    userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(userName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                      const SizedBox(height: 2),
                      Text(userEmail, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: allVerified ? Colors.green : (hasPending ? Colors.orange : Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    overallStatus,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: allVerified ? Colors.green.shade800 : (hasPending ? Colors.orange.shade800 : Colors.grey.shade700),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3 Document Type Rows
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: _docTypeConfig.map((cfg) {
                final docType = cfg['type']!;
                final doc = docs[docType] as Map<String, dynamic>?;
                return _buildDocRow(
                  emoji: cfg['emoji']!,
                  label: cfg['label']!,
                  doc: doc,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocRow({
    required String emoji,
    required String label,
    required Map<String, dynamic>? doc,
  }) {
    final isUploaded = doc != null;
    final status = doc?['status'] ?? 'not_uploaded';
    final fileName = doc?['fileName'] as String? ?? '';

    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (status) {
      case 'verified':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'Verified';
        break;
      case 'pending':
        statusColor = Colors.orange;
        statusIcon = Icons.pending_actions;
        statusText = 'Pending';
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        statusText = 'Rejected';
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.cloud_off;
        statusText = 'Not Uploaded';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87)),
                if (isUploaded)
                  Text(fileName, style: TextStyle(fontSize: 11, color: Colors.grey[500]), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcon, size: 12, color: statusColor),
                const SizedBox(width: 4),
                Text(statusText, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor)),
              ],
            ),
          ),
          if (isUploaded) ...[
            const SizedBox(width: 6),
            // View button
            _buildMiniButton(Icons.visibility, Colors.blue, () => _showDocPreview(doc!)),
            const SizedBox(width: 4),
            if (status == 'pending') ...[
              // Approve
              _buildMiniButton(Icons.check, Colors.green, () => _approveDocument(doc!)),
              const SizedBox(width: 4),
              // Reject
              _buildMiniButton(Icons.close, Colors.red, () => _rejectDocument(doc!)),
            ],
            const SizedBox(width: 4),
            // Delete
            _buildMiniButton(Icons.delete_outline, Colors.grey.shade600, () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete Document'),
                  content: Text('Are you sure you want to delete "$label"?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                    ElevatedButton(
                      onPressed: () { Navigator.pop(ctx); _deleteDocument(doc!); },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text('Delete', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildMiniButton(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}
