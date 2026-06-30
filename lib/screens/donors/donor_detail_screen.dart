import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firebase_service.dart';
import '../../widgets/top_snackbar.dart';

class DonorDetailScreen extends StatefulWidget {
  final Map<String, dynamic> donorData;
  final String? docId;
  final bool isApproved;
  final bool canViewContact;
  final bool isAdmin;

  const DonorDetailScreen({
    super.key,
    required this.donorData,
    this.docId,
    required this.isApproved,
    required this.canViewContact,
    this.isAdmin = false,
  });

  @override
  _DonorDetailScreenState createState() => _DonorDetailScreenState();
}

class _DonorDetailScreenState extends State<DonorDetailScreen> {
  bool _cancelling = false;

  ImageProvider? _imageFromBase64(String? base64Str) {
    if (base64Str == null || base64Str.isEmpty) return null;
    try {
      final bytes = base64Decode(base64Str);
      return MemoryImage(Uint8List.fromList(bytes));
    } catch (_) {
      return null;
    }
  }

  Future<void> _cancelDonation() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Donation?'),
        content: const Text('This will remove the donation record, clear the 3-month cooldown, and reset points. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes, Cancel', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    setState(() => _cancelling = true);

    try {
      final donorEmail = widget.donorData['email'] ?? '';
      final docId = widget.docId;

      if (FirebaseService.initialized && docId != null) {
        // Clear cooldown from Firestore
        await FirebaseFirestore.instance.collection('users').doc(docId).update({
          'cooldownUntil': FieldValue.delete(),
          'lastDonation': FieldValue.delete(),
        });

        // Decrement donation count if possible
        try {
          await FirebaseFirestore.instance.collection('users').doc(docId).update({
            'donationCount': FieldValue.increment(-1),
          });
        } catch (_) {}
      } else {
        // Demo mode
        final prefs = await SharedPreferences.getInstance();
        final users = prefs.getStringList('demo_users') ?? <String>[];
        final updated = users.map((s) {
          try {
            final u = jsonDecode(s) as Map<String, dynamic>;
            if ((u['email'] ?? '') == donorEmail) {
              u.remove('cooldownUntil');
              u.remove('lastDonation');
              u['donationCount'] = ((u['donationCount'] ?? 1) - 1).clamp(0, 999);
            }
            return jsonEncode(u);
          } catch (_) { return s; }
        }).toList();
        await prefs.setStringList('demo_users', updated);
      }

      if (mounted) {
        // Update local donor data too
        widget.donorData.remove('cooldownUntil');
        widget.donorData.remove('lastDonation');
        setState(() => _cancelling = false);
        showTopSnackBar(context, message: 'Donation cancelled! Cooldown cleared.', backgroundColor: Colors.green);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _cancelling = false);
        showTopSnackBar(context, message: 'Error: $e', backgroundColor: Colors.red);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.donorData['name'] ?? 'No name';
    final bloodGroup = widget.donorData['bloodGroup'] ?? 'Unknown';
    final location = widget.donorData['location'] ?? 'Unknown location';
    final contact = widget.donorData['contact'] ?? 'Not available';
    final email = widget.donorData['email'] ?? 'Not available';
    final role = (widget.donorData['role'] ?? 'donor').toString();
    final designation = widget.donorData['designation'] ?? '';
    final lastDonation = widget.donorData['lastDonation']?.toString();
    final cooldownUntil = widget.donorData['cooldownUntil']?.toString();
    final donationCount = widget.donorData['donationCount'] ?? 0;
    final hasActiveCooldown = cooldownUntil != null && cooldownUntil.isNotEmpty;

    // Calculate cooldown remaining
    String? cooldownRemaining;
    if (hasActiveCooldown) {
      try {
        final cooldownDate = DateTime.parse(cooldownUntil);
        final now = DateTime.now();
        if (cooldownDate.isAfter(now)) {
          final daysLeft = cooldownDate.difference(now).inDays;
          cooldownRemaining = '$daysLeft days remaining';
        }
      } catch (_) {}
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Donor Details',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFB71C1C), Color(0xFFD32F2F), Color(0xFFEF5350)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Section with Avatar
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFB71C1C), Color(0xFFD32F2F), Color(0xFFEF5350)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  _buildAvatar(),
                  const SizedBox(height: 16),
                  // Name with verified badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      if (widget.donorData['verified'] == true)
                        const Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: Icon(Icons.verified, color: Colors.blue, size: 26),
                        ),
                    ],
                  ),
                  if (designation.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      designation,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (role == 'donor')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Text(
                        'Donor',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),

            // Details Section
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Cooldown / Donation Status Card (NEW)
                  if (hasActiveCooldown && widget.isAdmin) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.timer, color: Colors.orange.shade700),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Donation Cooldown Active',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (lastDonation != null)
                            Text('🩸 Donated: $lastDonation', style: const TextStyle(fontSize: 13)),
                          if (cooldownRemaining != null)
                            Text('⏳ $cooldownRemaining', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          Text('🔢 Total Donations: $donationCount', style: const TextStyle(fontSize: 13)),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _cancelling ? null : _cancelDonation,
                              icon: _cancelling
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.cancel_outlined, color: Colors.red),
                              label: Text(_cancelling ? 'Cancelling...' : 'Cancel Donation', style: const TextStyle(color: Colors.red)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.red, width: 2),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Donation History Card (NEW)
                  if (donationCount > 0 && !hasActiveCooldown && widget.isAdmin) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.green.shade700),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Last Donation',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (lastDonation != null)
                            Text('🩸 Donated: $lastDonation', style: const TextStyle(fontSize: 13)),
                          Text('🔢 Total Donations: $donationCount', style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Approval Warning
                  if (!widget.isApproved) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.orange.shade700),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'This donor is pending approval.',
                              style: TextStyle(
                                color: Colors.orange.shade900,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  // Blood Group Card
                  _buildInfoCard(
                    icon: Icons.bloodtype,
                    title: 'Blood Group',
                    value: bloodGroup,
                    color: const Color(0xFFB71C1C),
                  ),
                  const SizedBox(height: 12),

                  // Location Card
                  _buildInfoCard(
                    icon: Icons.location_on,
                    title: 'Location',
                    value: location,
                    color: const Color(0xFF455A64),
                  ),
                  const SizedBox(height: 12),

                  // Contact Card
                  if (widget.canViewContact && widget.isApproved)
                    _buildContactCard(
                      icon: Icons.phone,
                      title: 'Contact',
                      value: contact,
                      color: const Color(0xFF4CAF50),
                      onTap: () => _makeCall(contact, context),
                    )
                  else
                    _buildInfoCard(
                      icon: Icons.phone_locked,
                      title: 'Contact',
                      value: widget.isApproved ? 'View details to see contact' : 'Not approved yet',
                      color: Colors.grey,
                    ),
                  const SizedBox(height: 12),

                  // Email Card
                  if (widget.canViewContact && widget.isApproved)
                    _buildContactCard(
                      icon: Icons.email,
                      title: 'Email',
                      value: email,
                      color: const Color(0xFF2196F3),
                      onTap: () => _sendEmail(email, context),
                    )
                  else
                    _buildInfoCard(
                      icon: Icons.email_outlined,
                      title: 'Email',
                      value: widget.isApproved ? 'View details to see email' : 'Not approved yet',
                      color: Colors.grey,
                    ),

                  const SizedBox(height: 24),

                  // Action Buttons
                  if (widget.canViewContact && widget.isApproved) ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _makeCall(contact, context),
                            icon: const Icon(Icons.call),
                            label: const Text('Call'),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.black,
                              side: BorderSide(color: Colors.black, width: 2),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _sendSms(contact, name, context),
                            icon: const Icon(Icons.message),
                            label: const Text('SMS'),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.black,
                              side: BorderSide(color: Colors.black, width: 2),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _sendEmail(email, context),
                        icon: const Icon(Icons.email),
                        label: const Text('Send Email'),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.black,
                          side: BorderSide(color: Colors.black, width: 2),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    final img = _imageFromBase64(widget.donorData['photoData'] as String?);
    final name = (widget.donorData['name'] ?? '').toString();

    if (img != null) {
      return Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          image: DecorationImage(
            image: img,
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: Color(0xFFB71C1C),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  Future<void> _makeCall(String phone, BuildContext context) async {
    final uri = Uri.parse('tel:$phone');
    try {
      if (!await launchUrl(uri)) {
        if (context.mounted) {
          showTopSnackBar(context, message: 'Could not open phone app', backgroundColor: Colors.red);
        }
      }
    } catch (e) {
      if (context.mounted) {
        showTopSnackBar(context, message: 'Error: $e', backgroundColor: Colors.red);
      }
    }
  }

  Future<void> _sendSms(String phone, String donorName, BuildContext context) async {
    final body = Uri.encodeComponent('Hello $donorName, I would like to connect with you regarding blood donation.');
    final uri = Uri.parse('sms:$phone?body=$body');
    try {
      if (!await launchUrl(uri)) {
        if (context.mounted) {
          showTopSnackBar(context, message: 'Could not open SMS app', backgroundColor: Colors.red);
        }
      }
    } catch (e) {
      if (context.mounted) {
        showTopSnackBar(context, message: 'Error: $e', backgroundColor: Colors.red);
      }
    }
  }

  Future<void> _sendEmail(String email, BuildContext context) async {
    final uri = Uri.parse('mailto:$email?subject=Blood Donation Inquiry');
    try {
      if (!await launchUrl(uri)) {
        if (context.mounted) {
          showTopSnackBar(context, message: 'Could not open email app', backgroundColor: Colors.red);
        }
      }
    } catch (e) {
      if (context.mounted) {
        showTopSnackBar(context, message: 'Error: $e', backgroundColor: Colors.red);
      }
    }
  }
}
