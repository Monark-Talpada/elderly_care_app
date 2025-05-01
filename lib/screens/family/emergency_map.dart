import 'package:elderly_care_app/models/senior_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EmergencyMapScreen extends StatefulWidget {
  final List<SeniorCitizen> seniors;

  const EmergencyMapScreen({Key? key, required this.seniors}) : super(key: key);

  @override
  State<EmergencyMapScreen> createState() => _EmergencyMapScreenState();
}

class _EmergencyMapScreenState extends State<EmergencyMapScreen> {
  MapController? _mapController;
  List<Marker> _markers = [];
  LatLng? _initialPosition;
  LatLng? _currentUserLocation;
  bool _isLoadingLocation = false;
  bool _locationPermissionDenied = false;
  Map<String, GeoPoint> _emergencyLocations = {};

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _loadEmergencyLocations();
    _getCurrentLocation();
  }

  Future<void> _loadEmergencyLocations() async {
    try {
      // Get all active emergencies
      final emergencies = await FirebaseFirestore.instance
          .collection('emergencies')
          .where('active', isEqualTo: true)
          .get();

      // Create a map of seniorId to emergency location
      final locations = <String, GeoPoint>{};
      for (var doc in emergencies.docs) {
        final data = doc.data();
        if (data['location'] != null) {
          locations[data['seniorId']] = data['location'] as GeoPoint;
        }
      }

      setState(() {
        _emergencyLocations = locations;
        _initializeMap();
      });
    } catch (e) {
      print('Error loading emergency locations: $e');
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Location services are not enabled
        setState(() {
          _isLoadingLocation = false;
          _locationPermissionDenied = true;
        });
        return;
      }

      // Check for location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          // Permissions are denied
          setState(() {
            _isLoadingLocation = false;
            _locationPermissionDenied = true;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        // Permissions are permanently denied
        setState(() {
          _isLoadingLocation = false;
          _locationPermissionDenied = true;
        });
        return;
      }

      // Get the current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentUserLocation = LatLng(position.latitude, position.longitude);
        _isLoadingLocation = false;
        
        // If there's no senior location, use current location as initial
        if (_initialPosition == null) {
          _initialPosition = _currentUserLocation;
          if (_mapController != null) {
            _mapController!.move(_initialPosition!, 13.0);
          }
        }
      });
    } catch (e) {
      setState(() {
        _isLoadingLocation = false;
      });
      print("Error getting location: $e");
    }
  }

  void _initializeMap() {
    // Filter seniors who have emergency locations
    final seniorsWithEmergency = widget.seniors.where((senior) => 
      _emergencyLocations.containsKey(senior.id)).toList();
    
    if (seniorsWithEmergency.isNotEmpty) {
      final firstSenior = seniorsWithEmergency.first;
      final emergencyLocation = _emergencyLocations[firstSenior.id]!;
      
      _initialPosition = LatLng(
        emergencyLocation.latitude,
        emergencyLocation.longitude,
      );

      _markers = seniorsWithEmergency.map((senior) {
        final location = _emergencyLocations[senior.id]!;
        return Marker(
          width: 80.0,
          height: 80.0,
          point: LatLng(
            location.latitude,
            location.longitude,
          ),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.red[700],
                  size: 24.0,
                ),
                const SizedBox(height: 4),
                Text(
                  senior.name,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Create a complete markers list including user's current location
    List<Marker> allMarkers = List.from(_markers);
    
    // Add current user location marker if available
    if (_currentUserLocation != null) {
      allMarkers.add(
        Marker(
          width: 60.0,
          height: 60.0,
          point: _currentUserLocation!,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.my_location,
                  color: theme.primaryColor,
                  size: 24.0,
                ),
                const SizedBox(height: 4),
                Text(
                  'You',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: theme.primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Emergency Map',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        backgroundColor: Colors.red,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadEmergencyLocations();
              _getCurrentLocation();
            },
            tooltip: 'Refresh Location',
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_initialPosition == null && _currentUserLocation == null)
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.red,
                    Colors.red.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 64,
                      color: Colors.white.withOpacity(0.8),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No location data available',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'No seniors in emergency mode have shared their location',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                center: _initialPosition ?? _currentUserLocation!,
                zoom: 13.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c'],
                  userAgentPackageName: 'com.elderly_care_app',
                ),
                MarkerLayer(
                  markers: allMarkers,
                ),
              ],
            ),
          if (_isLoadingLocation)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
          if (_locationPermissionDenied)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.location_off,
                      size: 32,
                      color: Colors.red[300],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Location Access Required',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Please enable location services to view emergency locations',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () async {
                        await Geolocator.openAppSettings();
                      },
                      icon: const Icon(Icons.settings),
                      label: const Text('Open Settings'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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
}

// A simple layer to indicate current location (Note: this is a placeholder)
// In a real app, you would use a location plugin to get the actual location
class CurrentLocationLayer extends StatelessWidget {
  const CurrentLocationLayer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink(); // Placeholder
    // In real app, you'd implement geolocator and show actual location
  }
}