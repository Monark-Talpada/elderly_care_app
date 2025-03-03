import 'package:elderly_care_app/models/senior_model.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class EmergencyMapScreen extends StatefulWidget {
  final List<SeniorCitizen> seniors;

  const EmergencyMapScreen({Key? key, required this.seniors}) : super(key: key);

  @override
  State<EmergencyMapScreen> createState() => _EmergencyMapScreenState();
}

class _EmergencyMapScreenState extends State<EmergencyMapScreen> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  LatLng? _initialPosition;

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  void _initializeMap() {
    final seniorsWithLocation = widget.seniors.where((senior) => senior.lastKnownLocation != null).toList();
    
    if (seniorsWithLocation.isNotEmpty) {
      _initialPosition = LatLng(
        seniorsWithLocation.first.lastKnownLocation!.latitude,
        seniorsWithLocation.first.lastKnownLocation!.longitude,
      );

      _markers = seniorsWithLocation.map((senior) {
        return Marker(
          markerId: MarkerId(senior.id),
          position: LatLng(
            senior.lastKnownLocation!.latitude,
            senior.lastKnownLocation!.longitude,
          ),
          infoWindow: InfoWindow(
            title: senior.name,
            snippet: 'Emergency Mode Active',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        );
      }).toSet();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Map'),
        backgroundColor: Colors.red,
      ),
      body: _initialPosition == null
          ? const Center(
              child: Text(
                'No location data available for seniors in emergency mode',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : GoogleMap(
              onMapCreated: (controller) {
                _mapController = controller;
              },
              initialCameraPosition: CameraPosition(
                target: _initialPosition!,
                zoom: 12,
              ),
              markers: _markers,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
            ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}