import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firebase_service.dart';

class DonorSearchScreen extends StatefulWidget {
  const DonorSearchScreen({super.key});

  @override
  _DonorSearchScreenState createState() => _DonorSearchScreenState();
}

class _DonorSearchScreenState extends State<DonorSearchScreen> {
  String _blood = 'A+';
  double _maxKm = 20.0;
  bool _onlyAvailable = true;
  Position? _position;
  bool _loading = false;
  List<Map<String, dynamic>> _results = [];

  final List<String> _bloodTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

  @override
  void initState() {
    super.initState();
  }

  double _distanceKm(double lat1, double lon1, double lat2, double lon2) {
    // Haversine formula
    const R = 6371.0; // km
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = sin(dLat/2) * sin(dLat/2) + cos(_deg2rad(lat1)) * cos(_deg2rad(lat2)) * sin(dLon/2) * sin(dLon/2);
    final c = 2 * atan2(sqrt(a), sqrt(1-a));
    return R * c;
  }

  double _deg2rad(double deg) => deg * (pi/180);

  Future<void> _locateAndSearch() async {
    setState(() { _loading = true; _results = []; });
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Location permission denied')));
        setState(() { _loading = false; });
        return;
      }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
      setState(() { _position = pos; });

      if (await _hasFirestore()) {
        await _searchFirestore(pos.latitude, pos.longitude);
      } else {
        await _searchDemo(pos.latitude, pos.longitude);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Location/search failed: $e')));
    }
    setState(() { _loading = false; });
  }

  Future<bool> _hasFirestore() async => FirebaseService.initialized;

  Future<void> _searchFirestore(double lat, double lng) async {
    try {
      final snap = await FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'donor').get();
      final docs = snap.docs;
      final list = <Map<String,dynamic>>[];
      for (final d in docs) {
        final data = d.data();
        if ((data['bloodGroup'] ?? '') != _blood) continue;
        if (_onlyAvailable && (data['available'] ?? true) == false) continue;
        final locStr = (data['location'] ?? '') as String;
        if (locStr.isEmpty) continue;
        final parts = locStr.split(',');
        if (parts.length < 2) continue;
        final dlat = double.tryParse(parts[0]) ?? 0.0;
        final dlng = double.tryParse(parts[1]) ?? 0.0;
        final dist = _distanceKm(lat, lng, dlat, dlng);
        if (dist <= _maxKm) {
          final row = Map<String, dynamic>.from(data);
          row['distanceKm'] = dist;
          row['id'] = d.id;
          list.add(row);
        }
      }
      list.sort((a,b) => (a['distanceKm'] as double).compareTo(b['distanceKm'] as double));
      setState(() { _results = list; });
    } catch (e) {
      // fallback: try demo search
      await _searchDemo(lat, lng);
    }
  }

  Future<void> _searchDemo(double lat, double lng) async {
    final prefs = await SharedPreferences.getInstance();
    final users = prefs.getStringList('demo_users') ?? <String>[];
    final list = <Map<String,dynamic>>[];
    for (final s in users) {
      try {
        final Map<String,dynamic> u = jsonDecode(s);
        if ((u['role'] ?? '') != 'donor') continue;
        if ((u['bloodGroup'] ?? '') != _blood) continue;
        if (_onlyAvailable && (u['available'] ?? true) == false) continue;
        final locStr = (u['location'] ?? '') as String;
        if (locStr.isEmpty) continue;
        final parts = locStr.split(',');
        if (parts.length < 2) continue;
        final dlat = double.tryParse(parts[0]) ?? 0.0;
        final dlng = double.tryParse(parts[1]) ?? 0.0;
        final dist = _distanceKm(lat, lng, dlat, dlng);
        if (dist <= _maxKm) {
          final row = Map<String,dynamic>.from(u);
          row['distanceKm'] = dist;
          list.add(row);
        }
      } catch (_) {}
    }
    list.sort((a,b) => (a['distanceKm'] as double).compareTo(b['distanceKm'] as double));
    setState(() { _results = list; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Find nearby donors')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(children: [Expanded(child: DropdownButtonFormField<String>(value: _blood, items: _bloodTypes.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(), onChanged: (v) => setState(() => _blood = v ?? _blood), decoration: InputDecoration(labelText: 'Blood group'))), SizedBox(width: 12), Column(children: [Text('Max km'), SizedBox(height: 4), Text('${_maxKm.toInt()} km')])]),
            Slider(min: 1, max: 200, divisions: 40, value: _maxKm, onChanged: (v) => setState(() => _maxKm = v)),
            Row(children: [Checkbox(value: _onlyAvailable, onChanged: (v) => setState(() => _onlyAvailable = v ?? true)), Text('Only show available donors')]),
            SizedBox(height: 8),
            Row(children: [Expanded(child: ElevatedButton(onPressed: _loading ? null : _locateAndSearch, child: Padding(padding: const EdgeInsets.symmetric(vertical: 12.0), child: Text(_loading ? 'Searching...' : 'Find nearby donors'))))]),
            SizedBox(height: 12),
            if (_position != null) Padding(padding: const EdgeInsets.only(bottom:8.0), child: Text('Your location: ${_position!.latitude.toStringAsFixed(4)}, ${_position!.longitude.toStringAsFixed(4)}', style: TextStyle(fontSize: 12, color: Colors.grey[700]))),
            Expanded(child: _results.isEmpty ? Center(child: Text(_loading ? 'Searching...' : 'No results')) : ListView.builder(itemCount: _results.length, itemBuilder: (context, i) {
              final r = _results[i];
              final dist = (r['distanceKm'] as double?) ?? 0.0;
              final name = (r['name'] ?? r['email'] ?? 'Donor').toString();
              final blood = r['bloodGroup'] ?? '';
              final loc = r['location'] ?? '';
              Widget avatar() {
                try {
                  final pd = r['photoData'] as String?;
                  if (pd != null && pd.isNotEmpty) return CircleAvatar(backgroundImage: MemoryImage(base64Decode(pd)));
                } catch (_) {}
                return CircleAvatar(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?'));
              }
              return ListTile(
                leading: avatar(),
                title: Text(name),
                subtitle: Text('$blood • ${loc.toString()}'),
                trailing: Text('${dist.toStringAsFixed(1)} km'),
                onTap: () {
                  // show details
                  showDialog(context: context, builder: (_) => AlertDialog(title: Text(name), content: Text('Blood: $blood\nLocation: $loc\nDistance: ${dist.toStringAsFixed(1)} km\nContact: ${r['contact'] ?? 'hidden'}'), actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('OK'))]));
                },
              );
            })),
          ],
        ),
      ),
    );
  }
}
