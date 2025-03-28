import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elderly_care_app/services/database_service.dart';
import 'package:elderly_care_app/utils/location_service.dart';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

class FallDetectionService {
  // Singleton pattern
  static final FallDetectionService _instance = FallDetectionService._internal();

  factory FallDetectionService() {
    return _instance;
  }

  FallDetectionService._internal();

  // Parameters for fall detection
  static const double _accelerationThreshold = 15.0; // m/s^2
  static const int _fallConfirmTimeMs = 1000; // Time to confirm a fall

  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  bool _isFallDetectionActive = false;
  String? _seniorId;
  String? _seniorName;

  DateTime? _potentialFallTime;
  bool _isFallConfirmed = false;

  // Initialize fall detection
  void initialize({
    required String seniorId,
    required String seniorName,
    bool isActive = true,
  }) {
    _seniorId = seniorId;
    _seniorName = seniorName;

    if (isActive) {
      activate();
    }
  }

  // Activate fall detection
  void activate() {
    if (_isFallDetectionActive) {
      return;
    }

    _isFallDetectionActive = true;
    _isFallConfirmed = false;
    _potentialFallTime = null;

    // Listen to accelerometer data
    _accelerometerSubscription = accelerometerEvents.listen(_processAccelerometerData);

    if (kDebugMode) {
      print('Fall detection activated');
    }
  }

  // Deactivate fall detection
  void deactivate() {
    _isFallDetectionActive = false;
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;

    if (kDebugMode) {
      print('Fall detection deactivated');
    }
  }

  // Process accelerometer data to detect falls
  void _processAccelerometerData(AccelerometerEvent event) {
    if (!_isFallDetectionActive) {
      return;
    }

    // Calculate total acceleration magnitude
    double accelerationMagnitude = _calculateMagnitude(event.x, event.y, event.z);

    // Detect sudden acceleration (potential fall)
    if (accelerationMagnitude > _accelerationThreshold) {
      if (_potentialFallTime == null) {
        _potentialFallTime = DateTime.now();

        // Schedule a check after a delay to confirm the fall
        Timer(Duration(milliseconds: _fallConfirmTimeMs), () {
          _confirmFall();
        });
      }
    }
  }

  // Calculate magnitude of acceleration vector
  double _calculateMagnitude(double x, double y, double z) {
    return (x * x + y * y + z * z).abs();
  }

  // Confirm fall after delay and trigger alert
  void _confirmFall() {
    if (_potentialFallTime != null && !_isFallConfirmed) {
      _isFallConfirmed = true;

      if (kDebugMode) {
        print('Fall detected!');
      }

      // Show confirmation dialog to the user
      _showFallConfirmationDialog();
    }
  }

  // Show fall confirmation dialog
  void _showFallConfirmationDialog() {
    // In a real app, this would show a UI dialog
    // For now, let's simulate by waiting a few seconds and then triggering the alert
    if (kDebugMode) {
      print('Showing fall confirmation dialog...');
    }

    // Wait 10 seconds for user response, then trigger alert if no response
    Timer(const Duration(seconds: 10), () {
      _triggerFallAlert();
    });
  }

  // Trigger fall alert
  Future<void> _triggerFallAlert() async {
    if (_seniorId == null || _seniorName == null) {
      return;
    }

    if (kDebugMode) {
      print('Triggering fall alert for $_seniorName');
    }

    // Get current location
    GeoPoint? location = await LocationService().getCurrentLocation();

    // Toggle emergency mode in database
    await DatabaseService().toggleEmergencyMode(_seniorId!, true);

    // Create emergency document
    final emergencyRef = FirebaseFirestore.instance.collection('emergencies').doc();
    await emergencyRef.set({
      'id': emergencyRef.id,
      'seniorId': _seniorId,
      'seniorName': _seniorName,
      'timestamp': FieldValue.serverTimestamp(),
      'active': true,
      'location': location,
    });

    // Start continuous location tracking
    LocationService().startEmergencyTracking();

    // Reset fall detection
    _potentialFallTime = null;
    _isFallConfirmed = false;
  }

  // Cancel fall alert (called when user confirms they are okay)
  Future<void> cancelFallAlert() async {
    if (_seniorId == null) {
      return;
    }

    _potentialFallTime = null;
    _isFallConfirmed = false;

    // Turn off emergency mode
    await DatabaseService().toggleEmergencyMode(_seniorId!, false);

    // Update all active emergencies to inactive
    final emergencyDocs = await FirebaseFirestore.instance
        .collection('emergencies')
        .where('seniorId', isEqualTo: _seniorId)
        .where('active', isEqualTo: true)
        .get();

    for (var doc in emergencyDocs.docs) {
      await doc.reference.update({
        'active': false,
        'cancelledAt': FieldValue.serverTimestamp(),
      });
    }

    // Stop continuous location tracking
    LocationService().stopTracking();
  }

  // Dispose
  void dispose() {
    deactivate();
  }
}