import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elderly_care_app/services/notification_service.dart';
import 'package:elderly_care_app/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:location/location.dart';
import 'package:elderly_care_app/models/senior_model.dart';

class EmergencyButtonScreen extends StatefulWidget {
  const EmergencyButtonScreen({Key? key}) : super(key: key);

  @override
  State<EmergencyButtonScreen> createState() => _EmergencyButtonScreenState();
}

class _EmergencyButtonScreenState extends State<EmergencyButtonScreen> {
  bool _emergencyActive = false;
  bool _loading = false;
  Location location = Location();
  LocationData? currentLocation;

  @override
  void initState() {
    super.initState();
    _checkExistingEmergencies();
    _requestLocationPermission();
  }

  Future<void> _requestLocationPermission() async {
    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) {
        return;
      }
    }

    PermissionStatus permissionStatus = await location.hasPermission();
    if (permissionStatus == PermissionStatus.denied) {
      permissionStatus = await location.requestPermission();
      if (permissionStatus != PermissionStatus.granted) {
        return;
      }
    }
  }

  Future<void> _checkExistingEmergencies() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      final emergencyDoc = await FirebaseFirestore.instance
          .collection('emergencies')
          .where('seniorId', isEqualTo: userId)
          .where('active', isEqualTo: true)
          .get();

      if (emergencyDoc.docs.isNotEmpty) {
        setState(() {
          _emergencyActive = true;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error checking emergencies: $e')),
      );
    }
  }

  Future<void> _triggerEmergency() async {
    setState(() {
      _loading = true;
    });

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      // Get current location
      try {
        currentLocation = await location.getLocation();
      } catch (e) {
        // If location fails, continue without it
        print('Failed to get location: $e');
      }

      // Get senior name
      final seniorDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      final seniorData = seniorDoc.data() as Map<String, dynamic>;
      final seniorName = seniorData['name'] ?? 'Senior';

      // Create emergency document
      final emergencyRef = FirebaseFirestore.instance.collection('emergencies').doc();
      
      await emergencyRef.set({
        'id': emergencyRef.id,
        'seniorId': userId,
        'seniorName': seniorName,
        'timestamp': FieldValue.serverTimestamp(),
        'active': true,
        'location': currentLocation != null
            ? GeoPoint(currentLocation!.latitude!, currentLocation!.longitude!)
            : null,
      });

      // Send emergency notification
      final notificationService = Provider.of<NotificationService>(context, listen: false);
      await notificationService.sendEmergencyAlert(
        seniorId: userId,
        seniorName: seniorName,
        location: currentLocation != null
            ? GeoPoint(currentLocation!.latitude!, currentLocation!.longitude!)
            : null,
      );

      setState(() {
        _emergencyActive = true;
        _loading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Emergency alert sent to all family members')),
      );
    } catch (e) {
      setState(() {
        _loading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send emergency alert: $e')),
      );
    }
  }

  Future<void> _cancelEmergency() async {
    setState(() {
      _loading = true;
    });

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      // Get senior name
      final seniorDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      final seniorData = seniorDoc.data() as Map<String, dynamic>;
      final seniorName = seniorData['name'] ?? 'Senior';

      // Get all active emergencies for this senior
      final emergencyDocs = await FirebaseFirestore.instance
          .collection('emergencies')
          .where('seniorId', isEqualTo: userId)
          .where('active', isEqualTo: true)
          .get();

      // Deactivate all emergencies
      for (var doc in emergencyDocs.docs) {
        await doc.reference.update({
          'active': false,
          'cancelledAt': FieldValue.serverTimestamp(),
        });
      }

      // Get connected family members
      final familyDocs = await FirebaseFirestore.instance
          .collection('users')
          .where('connectedSeniorIds', arrayContains: userId)
          .get();

      // Send cancellation notification
      final notificationService = Provider.of<NotificationService>(context, listen: false);
      
      for (var doc in familyDocs.docs) {
        await notificationService.sendEmergencyCancelledAlert(
          doc.id,
          userId,
          seniorName,
        );
      }

      setState(() {
        _emergencyActive = false;
        _loading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Emergency cancelled')),
      );
    } catch (e) {
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