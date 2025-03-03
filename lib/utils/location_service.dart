import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elderly_care_app/services/database_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';

class LocationService {
  // Singleton pattern
  static final LocationService _instance = LocationService._internal();
  
  factory LocationService() {
    return _instance;
  }
  
  LocationService._internal();
  
  StreamSubscription<Position>? _positionStreamSubscription;
  Timer? _periodicUpdateTimer;
  String? _userId;
  
  // Initialize location service
  Future<bool> initialize(String userId) async {
    _userId = userId;
    
    // Check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (kDebugMode) {
        print('Location services are disabled');
      }
      return false;
    }
    
    // Check for location permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (kDebugMode) {
          print('Location permissions are denied');
        }
        return false;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      if (kDebugMode) {
        print('Location permissions are permanently denied');
      }
      return false;
    }
    
    // Set up periodic location updates (every 15 minutes)
    _periodicUpdateTimer = Timer.periodic(const Duration(minutes: 15), (_) {
      _updateLocation();
    });
    
    // Initial location update
    await _updateLocation();
    
    return true;
  }
  
  // Update location in the database
  Future<void> _updateLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
      );
      
      if (_userId != null) {
        GeoPoint geoPoint = GeoPoint(position.latitude, position.longitude);
        await DatabaseService().updateUserLocation(_userId!, geoPoint);
        
        if (kDebugMode) {
          print('Location updated: ${position.latitude}, ${position.longitude}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error updating location: $e');
      }
    }
  }
  
  // Start continuous location tracking (for emergency mode)
  void startEmergencyTracking() {
    // Cancel any existing tracking
    stopTracking();
    
    // Start continuous tracking with high frequency
    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      ),
    ).listen((Position position) async {
      if (_userId != null) {
        GeoPoint geoPoint = GeoPoint(position.latitude, position.longitude);
        await DatabaseService().updateUserLocation(_userId!, geoPoint);
      }
    });
  }
  
  // Stop tracking
  void stopTracking() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
  }
  
  // Dispose
  void dispose() {
    stopTracking();
    _periodicUpdateTimer?.cancel();
    _periodicUpdateTimer = null;
  }
  
  // Get current location for emergency
  Future<GeoPoint?> getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
      );
      
      return GeoPoint(position.latitude, position.longitude);
    } catch (e) {
      if (kDebugMode) {
        print('Error getting current location: $e');
      }
      return null;
    }
  }
}