import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/firebase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../widgets/blood_bridge_loader.dart';

class EmergencyRequestScreen extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  const EmergencyRequestScreen({super.key, this.initialData});

  @override
  _EmergencyRequestScreenState createState() => _EmergencyRequestScreenState();
}

class _EmergencyRequestScreenState extends State<EmergencyRequestScreen> {
  String _blood = 'A+';
  String _urgency = 'High';
  final _qtyCtl = TextEditingController(text: '1');
  final _msgCtl = TextEditingController();
  final _phoneCtl = TextEditingController();
  DateTime? _requiredDate;
  bool _sending = false;

  final List<String> _bloodTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
  final List<String> _urgencies = ['Low', 'Medium', 'High', 'Critical'];
  static const double _controlHeight = 48;

  @override
  void dispose() {
    _qtyCtl.dispose();
    _msgCtl.dispose();
    _phoneCtl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final init = widget.initialData;
    if (init != null) {
      setState(() {
        _blood = (init['bloodGroup'] ?? _blood).toString();
        _urgency = (init['urgency'] ?? _urgency).toString();
        _qtyCtl.text = (init['quantity'] ?? _qtyCtl.text).toString();
        _msgCtl.text = (init['message'] ?? '').toString();
        _phoneCtl.text = (init['requesterPhone'] ?? '').toString();
        if (init['requiredDate'] != null) {
          try {
            _requiredDate = DateTime.parse(init['requiredDate'].toString());
          } catch (_) {}
        }
      });
    }
  }



  Future<void> _sendRequest() async {
    final qty = int.tryParse(_qtyCtl.text.trim()) ?? 1;
    final msg = _msgCtl.text.trim();
    final phone = _phoneCtl.text.trim();
    if (msg.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fill message and contact phone')));
      return;
    }
    if (_requiredDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please select required date'), backgroundColor: Colors.red));
      return;
    }
    setState(() => _sending = true);
    final payload = {
      'bloodGroup': _blood,
      'urgency': _urgency,
      'quantity': qty,
      'message': msg,
      'requesterPhone': phone,
      'requiredDate': _requiredDate!.toIso8601String(),
      'status': 'new',
      'requestedAt': DateTime.now().toIso8601String(),
    };

    if (FirebaseService.initialized) {
      try {
        await FirebaseFirestore.instance.collection('emergency_requests').add(payload);
        // try finding super_admin contact
        final snap = await FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'super_admin').limit(1).get();
        String adminPhone = '';
        if (snap.docs.isNotEmpty) {
          final adminData = snap.docs.first.data();
          adminPhone = (adminData['contact'] ?? '').toString();
        }
        if (adminPhone.isNotEmpty) {
          final body = Uri.encodeComponent('Emergency ($_urgency): $qty x $_blood. Message: $msg');
          final uri = Uri.parse('sms:$adminPhone?body=$body');
          await launchUrl(uri);
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Emergency request submitted')));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Submit failed: ${e.toString()}')));
      }
    } else {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('emergency_requests') ?? <String>[];
      list.add(jsonEncode(payload));
      await prefs.setStringList('emergency_requests', list);
      // simulate notifying superadmin: find demo super admin
      final users = prefs.getStringList('demo_users') ?? <String>[];
      String adminPhone = '';
      for (final s in users) {
        try {
          final Map<String,dynamic> u = jsonDecode(s);
          if ((u['role'] ?? '') == 'super_admin') { adminPhone = (u['contact'] ?? '').toString(); break; }
        } catch (_) {}
      }
      final sms = {'to': adminPhone.isNotEmpty ? adminPhone : 'superadmin', 'body': 'Emergency ($_urgency): $qty x $_blood. ${msg.isNotEmpty ? msg : ''}', 'at': DateTime.now().toIso8601String()};
      final msgs = prefs.getStringList('sent_sms') ?? <String>[];
      msgs.add(jsonEncode(sms));
      await prefs.setStringList('sent_sms', msgs);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Emergency request saved (demo) and superadmin notified (simulated)')));
    }

    setState(() => _sending = false);
    Navigator.of(context).pop();
  }

  InputDecoration _compactFieldDecoration({
    String? hintText,
    Widget? prefixIcon,
  }) {
    return InputDecoration(
      isDense: true,
      filled: false,
      hintText: hintText,
      hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
      prefixIcon: prefixIcon,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(25),
        borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(25),
        borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(25),
        borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Emergency Request',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.red.shade700, Colors.red.shade400, Colors.pink.shade300],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        iconTheme: IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFF5F5), Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Card
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.red.shade400, Colors.red.shade300],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.2),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.emergency, color: Colors.white, size: 32),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Blood Emergency',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Fill the details to send urgent request',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24),

                // Blood Group Card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.bloodtype, color: Colors.red.shade700, size: 24),
                            SizedBox(width: 8),
                            Text(
                              'Blood Group',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        SizedBox(
                          height: _controlHeight,
                          child: DropdownButtonFormField<String>(
                            value: _blood,
                            isExpanded: true,
                            itemHeight: _controlHeight,
                            dropdownColor: Colors.white,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
                            items: _bloodTypes.map((b) => DropdownMenuItem(
                              value: b,
                              child: Text(b, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                            )).toList(),
                            onChanged: (v) => setState(() => _blood = v ?? _blood),
                            decoration: _compactFieldDecoration(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16),

                // Urgency Card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.priority_high, color: Colors.black87, size: 24),
                            SizedBox(width: 8),
                            Text(
                              'Urgency Level',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        SizedBox(
                          height: _controlHeight,
                          child: DropdownButtonFormField<String>(
                            value: _urgency,
                            isExpanded: true,
                            itemHeight: _controlHeight,
                            dropdownColor: Colors.white.withOpacity(0.92),
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
                            items: _urgencies.map((u) => DropdownMenuItem(
                              value: u,
                              child: Text(u, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                            )).toList(),
                            onChanged: (v) => setState(() => _urgency = v ?? _urgency),
                            decoration: _compactFieldDecoration(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16),

                // Quantity Card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.local_hospital, color: Colors.red.shade700, size: 24),
                            SizedBox(width: 8),
                            Text(
                              'Quantity (Units)',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        SizedBox(
                          height: _controlHeight,
                          child: TextField(
                            controller: _qtyCtl,
                            keyboardType: TextInputType.number,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                            decoration: _compactFieldDecoration(hintText: 'Enter number of units'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16),

                // Contact Phone Card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.phone, color: Colors.red.shade700, size: 24),
                            SizedBox(width: 8),
                            Text(
                              'Your Contact Phone',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        SizedBox(
                          height: _controlHeight,
                          child: TextField(
                            controller: _phoneCtl,
                            keyboardType: TextInputType.phone,
                            style: TextStyle(fontSize: 14),
                            decoration: _compactFieldDecoration(
                              hintText: 'Enter your contact number',
                              prefixIcon: Icon(Icons.call, color: Colors.red.shade700, size: 18),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16),

                // Required Date Card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.calendar_today, color: Colors.red.shade700, size: 24),
                            SizedBox(width: 8),
                            Text(
                              'Required Date',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        SizedBox(
                          height: _controlHeight,
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _requiredDate ?? DateTime.now(),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(Duration(days: 365)),
                                builder: (context, child) {
                                  return Theme(
                                    data: Theme.of(context).copyWith(
                                      colorScheme: ColorScheme.light(
                                        primary: Colors.red.shade700,
                                        onPrimary: Colors.white,
                                        surface: Colors.white,
                                        onSurface: Colors.black,
                                      ),
                                    ),
                                    child: child!,
                                  );
                                },
                              );
                              if (picked != null) {
                                setState(() => _requiredDate = picked);
                              }
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(25),
                                border: Border.all(
                                  color: Colors.grey.shade300,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.date_range,
                                    size: 18,
                                    color: _requiredDate == null ? Colors.grey.shade500 : Colors.grey.shade700,
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _requiredDate == null
                                          ? 'Select required date'
                                          : '${_requiredDate!.day}/${_requiredDate!.month}/${_requiredDate!.year}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: _requiredDate == null ? FontWeight.normal : FontWeight.w600,
                                        color: _requiredDate == null ? Colors.grey.shade600 : Colors.grey.shade800,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_drop_down,
                                    color: Colors.grey.shade700,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16),

                // Message Card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.message, color: Colors.red.shade700, size: 24),
                            SizedBox(width: 8),
                            Text(
                              'Message / Additional Details',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        TextField(
                          controller: _msgCtl,
                          maxLines: 4,
                          style: TextStyle(fontSize: 16),
                          decoration: InputDecoration(
                            filled: false,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
                            ),
                            contentPadding: EdgeInsets.all(16),
                            hintText: 'Describe your emergency situation, location, etc.',
                            hintStyle: TextStyle(color: Colors.grey.shade500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 24),

                // Submit Button
                Center(
                  child: SizedBox(
                    width: 250,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _sending ? null : _sendRequest,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                        elevation: 3,
                      ),
                      child: _sending
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: BloodBridgeLoader(
                                    size: 20,
                                    duration: Duration(milliseconds: 600),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Sending...',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.send, color: Colors.white, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'Send Request',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
                SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
