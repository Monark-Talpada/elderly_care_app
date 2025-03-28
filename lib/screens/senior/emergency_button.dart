import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

class EmergencyButtonScreen extends StatefulWidget {
  const EmergencyButtonScreen({Key? key}) : super(key: key);

  @override
  State<EmergencyButtonScreen> createState() => _EmergencyButtonScreenState();
}

class _EmergencyButtonScreenState extends State<EmergencyButtonScreen> {
  bool _emergencyActive = false;
  bool _loading = false;
  Position? currentPosition;

  @override
  void initState() {
    super.initState();
    _checkExistingEmergencies();
    _requestLocationPermission();
  }

  Future<void> _requestLocationPermission() async {
    print('Requesting location permission...');
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('Location service not enabled');
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      print('Location permission denied, requesting...');
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        print('Location permission not granted');
        return;
      }
    }
    print('Location permission granted');
  }

  Future<void> _checkExistingEmergencies() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        print('No user ID found, cannot check emergencies');
        return;
      }

      print('Checking existing emergencies for user: $userId');
      final emergencyDoc = await FirebaseFirestore.instance
          .collection('emergencies')
          .where('seniorId', isEqualTo: userId)
          .where('active', isEqualTo: true)
          .get();

      if (emergencyDoc.docs.isNotEmpty) {
        print('Found active emergencies, setting emergencyActive to true');
        setState(() {
          _emergencyActive = true;
        });
      } else {
        print('No active emergencies found');
      }
    } catch (e) {
      print('Error checking emergencies: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error checking emergencies: $e')),
      );
    }
  }

  Future<void> _triggerEmergency() async {
    print('Triggering emergency...');
    setState(() {
      _loading = true;
    });

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        print('No user ID found, cannot trigger emergency');
        setState(() {
          _loading = false;
        });
        return;
      }
      print('User ID: $userId');

      // Get current location (optional, proceed even if it fails)
      print('Getting current location...');
      try {
        currentPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        print(
            'Location obtained: ${currentPosition?.latitude}, ${currentPosition?.longitude}');
      } catch (e) {
        print('Failed to get location: $e');
        currentPosition = null; // Continue without location
      }

      // Get senior name
      print('Fetching senior document...');
      final seniorDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (!seniorDoc.exists) {
        print('Senior document not found for user: $userId');
        setState(() {
          _loading = false;
        });
        return;
      }

      final seniorData = seniorDoc.data() as Map<String, dynamic>;
      final seniorName = seniorData['name'] ?? 'Senior';
      print('Senior name: $seniorName');

      // Update senior's emergencyModeActive status
      print('Updating senior document with emergencyModeActive: true...');
      await FirebaseFirestore.instance
          .collection('seniors')
          .doc(userId)
          .update({'emergencyModeActive': true});
      print('Senior document updated successfully');

      // Create emergency document
      print('Creating emergency document...');
      final emergencyRef = FirebaseFirestore.instance.collection('emergencies').doc();
      await emergencyRef.set({
        'id': emergencyRef.id,
        'seniorId': userId,
        'seniorName': seniorName,
        'timestamp': FieldValue.serverTimestamp(),
        'active': true,
        'location': currentPosition != null
            ? GeoPoint(currentPosition!.latitude, currentPosition!.longitude)
            : null,
      });
      print('Emergency document created with ID: ${emergencyRef.id}');

      setState(() {
        _emergencyActive = true;
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Emergency alert sent to all family members')),
      );
    } catch (e) {
      print('Failed to trigger emergency: $e');
      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send emergency alert: $e')),
      );
    }
  }

  Future<void> _cancelEmergency() async {
    print('Cancelling emergency...');
    setState(() {
      _loading = true;
    });

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        print('No user ID found, cannot cancel emergency');
        setState(() {
          _loading = false;
        });
        return;
      }

      // Update senior's emergencyModeActive status
      print('Updating senior document with emergencyModeActive: false...');
      await FirebaseFirestore.instance
          .collection('seniors')
          .doc(userId)
          .update({'emergencyModeActive': false});
      print('Senior document updated successfully');

      // Get all active emergencies for this senior
      print('Fetching active emergencies for user: $userId');
      final emergencyDocs = await FirebaseFirestore.instance
          .collection('emergencies')
          .where('seniorId', isEqualTo: userId)
          .where('active', isEqualTo: true)
          .get();

      print('Found ${emergencyDocs.docs.length} active emergencies');
      // Deactivate all emergencies
      for (var doc in emergencyDocs.docs) {
        print('Deactivating emergency: ${doc.id}');
        await doc.reference.update({
          'active': false,
          'cancelledAt': FieldValue.serverTimestamp(),
        });
      }

      setState(() {
        _emergencyActive = false;
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Emergency cancelled')),
      );
    } catch (e) {
      print('Failed to cancel emergency: $e');
      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to cancel emergency: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Button'),
        backgroundColor: _emergencyActive ? Colors.red : Colors.blue,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _emergencyActive ? 'EMERGENCY ACTIVE' : 'Press for Emergency',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: _emergencyActive ? Colors.red : Colors.black,
              ),
            ),
            const SizedBox(height: 30),
            _loading
                ? const CircularProgressIndicator()
                : GestureDetector(
                    onTap: _emergencyActive ? _cancelEmergency : _triggerEmergency,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _emergencyActive ? Colors.green : Colors.red,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            spreadRadius: 5,
                            blurRadius: 7,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          _emergencyActive ? 'CANCEL' : 'HELP',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
            const SizedBox(height: 30),
            Text(
              _emergencyActive
                  ? 'Press the button to cancel the emergency'
                  : 'Press the button to send an emergency alert to your family members',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}