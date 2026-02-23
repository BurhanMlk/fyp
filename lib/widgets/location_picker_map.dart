import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'blood_bridge_loader.dart';

class LocationPickerMap extends StatefulWidget {
  const LocationPickerMap({super.key});

  @override
  State<LocationPickerMap> createState() => _LocationPickerMapState();
}

class _LocationPickerMapState extends State<LocationPickerMap> {
  GoogleMapController? _mapController;
  LatLng _selectedLocation = LatLng(24.8607, 67.0011); // Default Karachi
  String _selectedAddress = 'Tap on map to select location';
  bool _isLoading = false;
  
  // Popular cities and areas in Pakistan
  final Map<String, LatLng> _popularLocations = {
    'Karachi, Sindh': LatLng(24.8607, 67.0011),
    'Lahore, Punjab': LatLng(31.5497, 74.3436),
    'Islamabad': LatLng(33.6844, 73.0479),
    'Rawalpindi, Punjab': LatLng(33.5651, 73.0169),
    'Faisalabad, Punjab': LatLng(31.4504, 73.1350),
    'Multan, Punjab': LatLng(30.1575, 71.5249),
    'Peshawar, KPK': LatLng(34.0151, 71.5249),
    'Quetta, Balochistan': LatLng(30.1798, 66.9750),
    'Sialkot, Punjab': LatLng(32.4945, 74.5229),
    'Gujranwala, Punjab': LatLng(32.1617, 74.1883),
    'Hyderabad, Sindh': LatLng(25.3960, 68.3578),
    'Abbottabad, KPK': LatLng(34.1495, 73.1995),
    'Sargodha, Punjab': LatLng(32.0836, 72.6711),
    'Bahawalpur, Punjab': LatLng(29.4000, 71.6833),
    'Sukkur, Sindh': LatLng(27.7058, 68.8574),
    'Larkana, Sindh': LatLng(27.5590, 68.2123),
    'Gulshan-e-Iqbal, Karachi': LatLng(24.9207, 67.0832),
    'DHA Karachi': LatLng(24.8124, 67.0625),
    'Clifton, Karachi': LatLng(24.8126, 67.0262),
    'Saddar, Karachi': LatLng(24.8546, 67.0199),
    'Malir, Karachi': LatLng(24.9436, 67.2067),
    'Korangi, Karachi': LatLng(24.8293, 67.1256),
    'North Nazimabad, Karachi': LatLng(24.9293, 67.0360),
    'Johar Town, Lahore': LatLng(31.4715, 74.2737),
    'DHA Lahore': LatLng(31.4715, 74.4045),
    'Gulberg, Lahore': LatLng(31.5204, 74.3587),
    'Model Town, Lahore': LatLng(31.4814, 74.3148),
    'Bahria Town, Lahore': LatLng(31.3426, 74.1732),
    'F-6, Islamabad': LatLng(33.7294, 73.0931),
    'F-7, Islamabad': LatLng(33.7184, 73.0479),
    'F-8, Islamabad': LatLng(33.7073, 73.0479),
    'G-9, Islamabad': LatLng(33.6831, 73.0363),
    'Bahria Town, Islamabad': LatLng(33.5267, 72.9873),
  };

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _selectedAddress = 'Location services disabled. Tap on map or search to select location';
          });
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      
      if (permission != LocationPermission.denied && permission != LocationPermission.deniedForever) {
        if (mounted) {
          setState(() => _isLoading = true);
        }
        
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        );
        
        if (mounted) {
          setState(() {
            _selectedLocation = LatLng(position.latitude, position.longitude);
            _isLoading = false;
          });
          _mapController?.animateCamera(CameraUpdate.newLatLng(_selectedLocation));
          await _getAddressFromLatLng(_selectedLocation);
        }
      } else {
        if (mounted) {
          setState(() {
            _selectedAddress = 'Tap on map or search to select location';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _selectedAddress = 'Tap on map or search to select location';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _getAddressFromLatLng(LatLng position) async {
    setState(() => _isLoading = true);
    try {
      // Try geocoding first
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      ).timeout(Duration(seconds: 5));
      
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        List<String> addressParts = [];
        
        if (place.subLocality != null && place.subLocality!.isNotEmpty) {
          addressParts.add(place.subLocality!);
        }
        if (place.locality != null && place.locality!.isNotEmpty) {
          addressParts.add(place.locality!);
        }
        if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) {
          addressParts.add(place.administrativeArea!);
        }
        
        String address = addressParts.join(', ');
        if (address.isEmpty && place.locality != null) {
          address = place.locality!;
        }
        
        setState(() {
          _selectedAddress = address.isNotEmpty ? address : 'Selected Location';
          _isLoading = false;
        });
      } else {
        setState(() {
          _selectedAddress = 'Selected Location (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)})';
          _isLoading = false;
        });
      }
    } catch (e) {
      // If geocoding fails (common on web), use a generic name
      setState(() {
        _selectedAddress = 'Selected Location (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)})';
        _isLoading = false;
      });
    }
  }

  void _onMapTapped(LatLng position) {
    setState(() {
      _selectedLocation = position;
    });
    _getAddressFromLatLng(position);
  }
  
  void _showLocationSearch() {
    
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (bottomSheetContext) => StatefulBuilder(
        builder: (stateContext, setModalState) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) => Container(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  'Select a City or Area',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: 'Search city or area...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onChanged: (value) => setModalState(() {}),
                ),
                SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: _popularLocations.entries
                        .where((entry) =>
                            searchController.text.isEmpty ||
                            entry.key.toLowerCase().contains(searchController.text.toLowerCase()))
                        .map((entry) => ListTile(
                              leading: Icon(Icons.location_on, color: Colors.red),
                              title: Text(entry.key),
                              onTap: () {
                                setState(() {
                                  _selectedLocation = entry.value;
                                  _selectedAddress = entry.key;
                                });
                                _mapController?.animateCamera(
                                  CameraUpdate.newLatLngZoom(entry.value, 14),
                                );
                                Navigator.of(bottomSheetContext).pop();
                              },
                            ))
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Select Location'),
        actions: [
          IconButton(
            icon: Icon(Icons.search),
            onPressed: _showLocationSearch,
            tooltip: 'Search Location',
          ),
          IconButton(
            icon: Icon(Icons.check),
            onPressed: () {
              if (_selectedAddress.isNotEmpty && _selectedAddress != 'Tap on map or search to select location') {
                Navigator.of(context).pop(_selectedAddress);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Please select a location first')),
                );
              }
            },
            tooltip: 'Confirm',
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _selectedLocation,
              zoom: 14,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
            },
            onTap: _onMapTapped,
            markers: {
              Marker(
                markerId: MarkerId('selected'),
                position: _selectedLocation,
                draggable: true,
                onDragEnd: (newPosition) {
                  setState(() {
                    _selectedLocation = newPosition;
                  });
                  _getAddressFromLatLng(newPosition);
                },
              ),
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selected Location:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 8),
                  _isLoading
                      ? Row(
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: BloodBridgeLoader(
                                size: 16,
                                duration: Duration(milliseconds: 600),
                              ),
                            ),
                            SizedBox(width: 8),
                            Text('Loading address...'),
                          ],
                        )
                      : Text(
                          _selectedAddress,
                          style: TextStyle(fontSize: 14),
                        ),
                  SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop(_selectedAddress);
                      },
                      child: Text('Confirm Location'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}
