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
          child: Column(
            children: [
              const Icon(
                Icons.location_on,
                color: Colors.red,
                size: 40.0,
              ),
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 2,
                    )
                  ]
                ),
                child: Text(
                  senior.name,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        );
      }).toList();
    }
    
    // We'll add current user location marker in the build method
  }

  @override
  Widget build(BuildContext context) {
    // Create a complete markers list including user's current location
    List<Marker> allMarkers = List.from(_markers);
    
    // Add current user location marker if available
    if (_currentUserLocation != null) {
      allMarkers.add(
        Marker(
          width: 60.0,
          height: 60.0,
          point: _currentUserLocation!,
          child: const Column(
            children: [
              Icon(
                Icons.my_location,
                color: Colors.blue,
                size: 30.0,
              ),
              Text(
                'You',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Map'),
        backgroundColor: Colors.red,
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
            const Center(
              child: Text(
                'No location data available for seniors in emergency mode',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
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
                MarkerLayer(markers: allMarkers),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Container(
                    margin: const EdgeInsets.only(right: 5, bottom: 5),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: const Text(
                      '© OpenStreetMap contributors',
                      style: TextStyle(color: Colors.black54, fontSize: 10),
                    ),
                  ),
                ),
              ],
            ),
          if (_isLoadingLocation)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.blue.withOpacity(0.7),
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: const Center(
                  child: Text(
                    'Getting your location...',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          if (_locationPermissionDenied)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.red.withOpacity(0.7),
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: const Center(
                  child: Text(
                    'Location permission denied. Some features may be limited.',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: (_initialPosition != null || _currentUserLocation != null)
          ? Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FloatingActionButton(
                  heroTag: 'centerOnUser',
                  backgroundColor: Colors.blue,
                  child: const Icon(Icons.my_location),
                  onPressed: () {
                    if (_currentUserLocation != null && _mapController != null) {
                      _mapController!.move(_currentUserLocation!, 15.0);
                    } else {
                      _getCurrentLocation();
                    }
                  },
                  mini: true,
                ),
                const SizedBox(height: 10),
                if (_initialPosition != null)
                  FloatingActionButton(
                    heroTag: 'centerOnSenior',
                    backgroundColor: Colors.red,
                    child: const Icon(Icons.person_pin_circle),
                    onPressed: () {
                      if (_initialPosition != null && _mapController != null) {
                        _mapController!.move(_initialPosition!, 13.0);
                      }
                    },
                  ),
              ],
            )
          : null,
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