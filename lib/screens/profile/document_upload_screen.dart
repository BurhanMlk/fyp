import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../../services/firebase_service.dart';
import '../../widgets/blood_bridge_loader.dart';
import '../../widgets/top_snackbar.dart';

class DocumentUploadScreen extends StatefulWidget {
  final String userRole;
  final Map<String, dynamic> userData;

  const DocumentUploadScreen({
    super.key,
    required this.userRole,
    required this.userData,
  });

  @override
  _DocumentUploadScreenState createState() => _DocumentUploadScreenState();
}

class _DocumentUploadScreenState extends State<DocumentUploadScreen> {
  bool _isLoading = true;
  Map<String, bool> _uploadingMap = {};
  Map<String, Map<String, dynamic>?> _documents = {
    'id_front': null,
    'id_back': null,
    'blood_test': null,
  };

  static const List<Map<String, dynamic>> _docConfigs = [
    {
      'type': 'id_front',
      'title': 'CNIC / ID Card - Front',
      'icon': Icons.credit_card,
      'desc': 'Upload front side of your CNIC or ID card',
      'emoji': '',
    },
    {
      'type': 'id_back',
      'title': 'CNIC / ID Card - Back',
      'icon': Icons.credit_card_outlined,
      'desc': 'Upload back side of your CNIC or ID card',
      'emoji': '',
    },
    {
      'type': 'blood_test',
      'title': 'Blood Test Report',
      'icon': Icons.health_and_safety,
      'desc': 'Upload your recent blood test report',
      'emoji': '',
    },
  ];

  @override
  void initState() {
    super.initState();
    for (final cfg in _docConfigs) {
      _uploadingMap[cfg['type'] as String] = false;
    }
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    setState(() => _isLoading = true);
    try {
      final userId = FirebaseService.initialized ? FirebaseAuth.instance.currentUser?.uid : widget.userData['uid'];
      final Map<String, Map<String, dynamic>?> freshDocs = {
        'id_front': null,
        'id_back': null,
        'blood_test': null,
      };

      // Try Firebase first
      if (FirebaseService.initialized && userId != null) {
        try {
          for (final cfg in _docConfigs) {
            final docType = cfg['type'] as String;
            try {
              final snap = await FirebaseFirestore.instance
                  .collection('verificationDocuments')
                  .where('userId', isEqualTo: userId)
                  .where('documentType', isEqualTo: docType)
                  .orderBy('uploadedAt', descending: true)
                  .limit(1)
                  .get();
              if (snap.docs.isNotEmpty) {
                freshDocs[docType] = {...snap.docs.first.data(), 'docId': snap.docs.first.id};
              }
            } catch (e) {
              print('⚠️ Error loading $docType from Firebase: $e');
              // Try without orderBy (index might be missing)
              try {
                final snap2 = await FirebaseFirestore.instance
                    .collection('verificationDocuments')
                    .where('userId', isEqualTo: userId)
                    .where('documentType', isEqualTo: docType)
                    .get();
                if (snap2.docs.isNotEmpty) {
                  // Sort manually
                  final docs = snap2.docs.toList()
                    ..sort((a, b) => (b.data()['uploadedAt'] ?? '').compareTo(a.data()['uploadedAt'] ?? ''));
                  freshDocs[docType] = {...docs.first.data(), 'docId': docs.first.id};
                }
              } catch (e2) {
                print('⚠️ Fallback query also failed for $docType: $e2');
              }
            }
          }

          // Backward compatibility: also check old 'id_verification' type → map to id_front
          if (freshDocs['id_front'] == null) {
            try {
              final oldSnap = await FirebaseFirestore.instance
                  .collection('verificationDocuments')
                  .where('userId', isEqualTo: userId)
                  .where('documentType', isEqualTo: 'id_verification')
                  .get();
              if (oldSnap.docs.isNotEmpty) {
                final docs = oldSnap.docs.toList()
                  ..sort((a, b) => (b.data()['uploadedAt'] ?? '').compareTo(a.data()['uploadedAt'] ?? ''));
                freshDocs['id_front'] = {...docs.first.data(), 'docId': docs.first.id};
              }
            } catch (_) {}
          }
        } catch (e) {
          print('❌ Firebase load failed: $e');
        }
      }

      // Demo mode fallback (ALSO used if Firebase loaded nothing)
      if (!FirebaseService.initialized || userId == null) {
        final prefs = await SharedPreferences.getInstance();
        final docsJson = prefs.getStringList('demo_verification_documents') ?? [];
        final allDocs = docsJson
            .map((s) => jsonDecode(s) as Map<String, dynamic>)
            .where((d) => d['userId'] == widget.userData['uid'])
            .toList();
        for (final cfg in _docConfigs) {
          final docType = cfg['type'] as String;
          final found = allDocs.where((d) => d['documentType'] == docType).toList();
          if (found.isNotEmpty) {
            freshDocs[docType] = found.first;
          }
        }
        // Backward compat for demo mode
        if (freshDocs['id_front'] == null) {
          final oldDocs = allDocs.where((d) => d['documentType'] == 'id_verification').toList();
          if (oldDocs.isNotEmpty) freshDocs['id_front'] = oldDocs.first;
        }
      }

      setState(() => _documents = freshDocs);
    } catch (e) {
      print('Error loading documents: $e');
      _showSnack('Error loading documents: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _uploadDocument(String docType) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );
      if (result == null) return;

      final file = result.files.first;
      setState(() => _uploadingMap[docType] = true);

      late Uint8List bytes;
      if (file.bytes != null) {
        bytes = file.bytes!;
      } else {
        throw 'Could not read file';
      }

      final base64File = base64Encode(bytes);
      final userId = FirebaseService.initialized
          ? FirebaseAuth.instance.currentUser?.uid
          : widget.userData['uid'];

      final documentData = {
        'userId': userId,
        'userName': widget.userData['name'] ?? 'Unknown',
        'userEmail': widget.userData['email'] ?? 'N/A',
        'documentType': docType,
        'fileName': file.name,
        'fileSize': file.size,
        'fileData': base64File,
        'status': 'pending',
        'uploadedAt': DateTime.now().toIso8601String(),
        'verifiedAt': null,
        'verifiedBy': null,
        'verificationNotes': '',
      };

      if (FirebaseService.initialized && userId != null) {
        await FirebaseFirestore.instance
            .collection('verificationDocuments')
            .add(documentData);
      } else {
        final prefs = await SharedPreferences.getInstance();
        final docsJson = prefs.getStringList('demo_verification_documents') ?? [];
        documentData['docId'] = 'doc_${DateTime.now().millisecondsSinceEpoch}';
        docsJson.add(jsonEncode(documentData));
        await prefs.setStringList('demo_verification_documents', docsJson);
      }

      final cfg = _docConfigs.firstWhere((c) => c['type'] == docType);
      
      await _loadDocuments();

      // Check if all 3 docs are now uploaded
      final allUploaded = _documents.values.every((d) => d != null);
      
      if (mounted) {
        _showUploadSuccessPopup(cfg['title'] as String, allUploaded);
      }
    } catch (e) {
      print('Error uploading document: $e');
      _showSnack('Error uploading document: $e', isError: true);
    } finally {
      setState(() => _uploadingMap[docType] = false);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    showTopSnackBar(context, message: message, backgroundColor: isError ? Colors.red : Colors.green);
  }

  void _showUploadSuccessPopup(String docTitle, bool allUploaded) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 32, 24, 20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.green.shade50,
                border: Border.all(color: Colors.green.shade300, width: 3),
              ),
              child: Icon(Icons.cloud_done_rounded, color: Colors.green.shade600, size: 48),
            ),
            const SizedBox(height: 20),
            Text(
              '$docTitle\nUploaded Successfully!',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.access_time_rounded, color: Colors.orange.shade700, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      allUploaded
                          ? 'All documents uploaded! Admin is verifying your documents. You will be approved soon, please wait for a while.'
                          : 'Document uploaded! Admin will verify your documents soon. Please upload all remaining documents for faster approval.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD32F2F),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('OK', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(body: Center(child: BloodBridgeLoader()));
    }
    if (widget.userRole != 'recipient') {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'Document uploads are for recipients only',
                style: TextStyle(fontSize: 18, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    final int verifiedCount = _documents.values
        .where((d) => d != null && d['status'] == 'verified')
        .length;
    final int uploadedCount = _documents.values.where((d) => d != null).length;
    final bool allVerified = verifiedCount == _docConfigs.length && uploadedCount == _docConfigs.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Document Verification'),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.red[700]!, Colors.red[500]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Overall Status Banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: allVerified ? Colors.green[50] : Colors.orange[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: allVerified ? Colors.green[300]! : Colors.orange[300]!,
                    width: 2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          allVerified ? Icons.verified : Icons.schedule,
                          color: allVerified ? Colors.green[700] : Colors.orange[700],
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                allVerified
                                    ? 'All Documents Verified'
                                    : uploadedCount > 0
                                        ? '$verifiedCount of ${_docConfigs.length} Verified'
                                        : 'No Documents Uploaded',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: allVerified ? Colors.green[900] : Colors.orange[900],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                allVerified
                                    ? 'Your documents have been verified by the admin.'
                                    : uploadedCount > 0
                                        ? 'Waiting for admin verification...'
                                        : 'Please upload all required documents below',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: allVerified ? Colors.green[800] : Colors.orange[800],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Progress indicators for each doc
                    ..._docConfigs.map((cfg) {
                      final doc = _documents[cfg['type'] as String];
                      final status = doc?['status'] ?? 'not_uploaded';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _buildStatusItem(cfg['emoji'] as String, cfg['title'] as String, status),
                      );
                    }),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Individual Document Upload Cards
              ..._docConfigs.map((cfg) {
                final docType = cfg['type'] as String;
                final doc = _documents[docType];
                final isUploading = _uploadingMap[docType] ?? false;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildDocumentCard(
                    title: cfg['title'] as String,
                    icon: cfg['icon'] as IconData,
                    description: cfg['desc'] as String,
                    document: doc,
                    docType: docType,
                    isUploading: isUploading,
                  ),
                );
              }),

              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusItem(String emoji, String title, String status) {
    final isVerified = status == 'verified';
    final isPending = status == 'pending';
    final isNotUploaded = status == 'not_uploaded';

    IconData statusIcon;
    Color statusColor;
    String statusText;

    if (isVerified) {
      statusIcon = Icons.check_circle;
      statusColor = Colors.green;
      statusText = 'Verified';
    } else if (isPending) {
      statusIcon = Icons.pending_actions;
      statusColor = Colors.orange;
      statusText = 'Pending';
    } else {
      statusIcon = Icons.cloud_upload_outlined;
      statusColor = Colors.grey;
      statusText = 'Not Uploaded';
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isVerified
                ? Colors.green[100]
                : isPending
                    ? Colors.orange[100]
                    : Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(statusIcon, size: 14, color: statusColor),
              const SizedBox(width: 4),
              Text(
                statusText,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentCard({
    required String title,
    required IconData icon,
    required String description,
    required Map<String, dynamic>? document,
    required String docType,
    required bool isUploading,
  }) {
    final status = document?['status'] as String?;
    final isVerified = status == 'verified';
    final isPending = status == 'pending';
    final isUploaded = document != null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isVerified
              ? Colors.green[300]!
              : isPending
                  ? Colors.orange[300]!
                  : Colors.grey[200]!,
          width: isUploaded ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isVerified
                        ? Colors.green[50]
                        : isPending
                            ? Colors.orange[50]
                            : Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isVerified
                        ? Icons.verified
                        : isPending
                            ? Icons.pending_actions
                            : icon,
                    color: isVerified
                        ? Colors.green[700]
                        : isPending
                            ? Colors.orange[700]
                            : Colors.red[400],
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        description,
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                // Status Badge
                if (isUploaded)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: isVerified ? Colors.green[100] : Colors.orange[100],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isVerified ? Icons.check_circle : Icons.schedule,
                          size: 14,
                          color: isVerified ? Colors.green[700] : Colors.orange[700],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isVerified ? 'Verified' : 'Pending',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isVerified ? Colors.green[700] : Colors.orange[700],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 14),

            // Uploaded file info
            if (isUploaded) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.insert_drive_file, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            document!['fileName'] ?? 'Document',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 12, color: Colors.grey[500]),
                        const SizedBox(width: 6),
                        Text(
                          'Uploaded: ${_formatDate(document['uploadedAt'])}',
                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    if (isVerified && document['verifiedAt'] != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.verified, size: 12, color: Colors.blue),
                          const SizedBox(width: 6),
                          Text(
                            'Verified: ${_formatDate(document['verifiedAt'])}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.blue[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Upload / Re-upload Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: isUploading ? null : () => _uploadDocument(docType),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: isUploaded ? Colors.blue : const Color(0xFFD32F2F),
                  side: BorderSide(
                    color: isUploaded ? Colors.blue : const Color(0xFFD32F2F),
                    width: 2,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  disabledForegroundColor: Colors.grey[400],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: isUploading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD32F2F)),
                        ),
                      )
                    : Icon(isUploaded ? Icons.refresh : Icons.cloud_upload, size: 20),
                label: Text(
                  isUploading
                      ? 'Uploading...'
                      : isUploaded
                          ? 'Re-upload'
                          : 'Upload Now',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(dynamic date) {
    try {
      if (date is Timestamp) date = date.toDate().toIso8601String();
      final parsed = DateTime.parse(date.toString());
      return '${parsed.day}/${parsed.month}/${parsed.year}';
    } catch (_) {
      return 'N/A';
    }
  }
}
