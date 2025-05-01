import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

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
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Emergency Button',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        elevation: 0,
        backgroundColor: _emergencyActive ? Colors.red.shade700 : theme.primaryColor,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _emergencyActive ? Colors.red.shade50 : theme.primaryColor.withOpacity(0.1),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
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
                        _emergencyActive ? Icons.warning_amber_rounded : Icons.emergency,
                        size: 80,
                        color: _emergencyActive ? Colors.red.shade700 : theme.primaryColor,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _emergencyActive ? 'EMERGENCY ACTIVE' : 'Emergency Alert',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: _emergencyActive ? Colors.red.shade700 : theme.primaryColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          _emergencyActive
                              ? 'Your emergency alert has been sent to all connected family members. They have been notified of your situation.'
                              : 'Press the button below to send an emergency alert to all your connected family members.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black87,
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (_loading)
                        const CircularProgressIndicator()
                      else
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _emergencyActive ? _cancelEmergency : _triggerEmergency,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _emergencyActive ? Colors.red.shade700 : Colors.red,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 4,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _emergencyActive ? Icons.cancel_outlined : Icons.emergency,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _emergencyActive ? 'Cancel Emergency' : 'Send Emergency Alert',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (_emergencyActive) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.red.shade200,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Emergency Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (currentPosition != null) ...[
                          Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                color: Colors.red.shade700,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Your location has been shared with family members',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              color: Colors.red.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Emergency started at ${DateFormat('h:mm a').format(DateTime.now())}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}