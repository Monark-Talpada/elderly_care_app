import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elderly_care_app/models/senior_model.dart';
import 'package:elderly_care_app/services/auth_service.dart';
import 'package:elderly_care_app/services/database_service.dart';
import 'package:elderly_care_app/services/notification_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class EmergencyButtonScreen extends StatefulWidget {
  const EmergencyButtonScreen({Key? key}) : super(key: key);

  @override
  _EmergencyButtonScreenState createState() => _EmergencyButtonScreenState();
}

class _EmergencyButtonScreenState extends State<EmergencyButtonScreen> with SingleTickerProviderStateMixin {
  late AuthService _authService;
  late DatabaseService _databaseService;
  late NotificationService _notificationService;
  
  SeniorCitizen? _senior;
  bool _isLoading = true;
  bool _emergencyActive = false;
  Position? _currentPosition;
  
  Timer? _pulseTimer;
  late AnimationController _animationController;
  late Animation<double> _animation;
  
  int _countdown = 0;
  Timer? _countdownTimer;
  
  @override
  void initState() {
    super.initState();
    _authService = Provider.of<AuthService>(context, listen: false);
    _databaseService = Provider.of<DatabaseService>(context, listen: false);
    _notificationService = Provider.of<NotificationService>(context, listen: false);
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    
    _animation = Tween<double>(begin: 1.0, end: 1.5).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    
    _animationController.repeat(reverse: true);
    
    _loadSeniorData();
    _checkLocationPermission();
  }
  
  @override
  void dispose() {
    _pulseTimer?.cancel();
    _countdownTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }
  
  Future<void> _loadSeniorData() async {
    try {
      final user = _authService.currentUser;
      if (user != null) {
        final senior = await _databaseService.getSeniorById(user.id);
        
        if (mounted && senior != null) {
          setState(() {
            _senior = senior;
            _emergencyActive = senior.emergencyModeActive;
            _isLoading = false;
          });
          
          if (_emergencyActive) {
            _startPulseAnimation();
          }
        }
      }
    } catch (e) {
      print('Error loading senior data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _checkLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location services are disabled. Please enable the services'),
        ),
      );
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permissions are denied'),
          ),
        );
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location permissions are permanently denied, we cannot request permissions.'),
        ),
      );
      return;
    }
    
    // Get current position once permission is granted
    try {
      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = position;
      });
    } catch (e) {
      print('Error getting location: $e');
    }
  }
  
  void _startPulseAnimation() {
    // Start the pulsing effect for emergency mode
    _pulseTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!_emergencyActive) {
        timer.cancel();
        return;
      }
      
      _updateLocation();
    });
  }
  
  Future<void> _toggleEmergency() async {
    if (_senior == null) return;
    
    if (!_emergencyActive) {
      // User is activating emergency
      _startCountdown();
    } else {
      // User is deactivating emergency
      await _deactivateEmergency();
    }
  }
  
  void _startCountdown() {
    setState(() {
      _countdown = 5; // 5 seconds countdown
    });
    
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _countdown--;
      });
      
      if (_countdown <= 0) {
        timer.cancel();
        _activateEmergency();
      }
    });
  }
  
  void _cancelCountdown() {
    _countdownTimer?.cancel();
    setState(() {
      _countdown = 0;
    });
  }
  
  Future<void> _activateEmergency() async {
    try {
      await _updateLocation();
      
      if (_senior == null) return;
      
      final updatedSenior = _senior!.copyWith(
        emergencyModeActive: true,
      );
      
      await _databaseService.updateSenior(updatedSenior);
      
      // Notify family members
      for (final familyId in updatedSenior.connectedFamilyIds) {
        await _notificationService.sendEmergencyAlert(
          seniorId: updatedSenior.id,
          seniorName: updatedSenior.name,
          location: updatedSenior.lastKnownLocation,
        );
      }
      
      setState(() {
        _senior = updatedSenior;
        _emergencyActive = true;
      });
      
      _startPulseAnimation();
      
    } catch (e) {
      print('Error activating emergency: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _deactivateEmergency() async {
    try {
      if (_senior == null) return;
      
      final updatedSenior = _senior!.copyWith(
        emergencyModeActive: false,
      );
      
      await _databaseService.updateSenior(updatedSenior);
      
      // Notify family members that emergency is over
      for (final familyId in updatedSenior.connectedFamilyIds) {
        await _notificationService.sendEmergencyCancelledAlert(
          familyId,
          updatedSenior.id,
          updatedSenior.name
        );
      }
      
      _pulseTimer?.cancel();
      
      setState(() {
        _senior = updatedSenior;
        _emergencyActive = false;
      });
      
    } catch (e) {
      print('Error deactivating emergency: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _updateLocation() async {
    try {
      if (_senior == null) return;
      
      Position position = await Geolocator.getCurrentPosition();
      
      final updatedSenior = _senior!.copyWith(
        lastKnownLocation: GeoPoint(position.latitude, position.longitude),
        lastLocationUpdate: DateTime.now(),
      );
      
      await _databaseService.updateSenior(updatedSenior);
      
      setState(() {
        _currentPosition = position;
        _senior = updatedSenior;
      });
      
    } catch (e) {
      print('Error updating location: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Button'),
        backgroundColor: _emergencyActive ? Colors.red : null,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _emergencyActive
                    ? 'EMERGENCY MODE ACTIVE'
                    : 'Press in case of emergency',
                style: TextStyle(
                  fontSize: _emergencyActive ? 24 : 18,
                  fontWeight: FontWeight.bold,
                  color: _emergencyActive ? Colors.red : Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              if (_countdown > 0) ...[
                Text(
                  'Activating emergency in $_countdown',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _cancelCountdown,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                  ),
                  child: const Text('Cancel'),
                ),
                const SizedBox(height: 32),
              ],
              _buildEmergencyButton(),
              const SizedBox(height: 32),
              if (_emergencyActive) ...[
                Text(
                  'Family members have been notified',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.red,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Your location is being shared',
                  style: const TextStyle(
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                if (_currentPosition != null) ...[
                  Text(
                    'Lat: ${_currentPosition!.latitude.toStringAsFixed(4)}, '
                    'Lng: ${_currentPosition!.longitude.toStringAsFixed(4)}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildEmergencyButton() {
    return GestureDetector(
      onTap: _countdown > 0 ? null : _toggleEmergency,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Transform.scale(
            scale: _emergencyActive ? _animation.value : 1.0,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _emergencyActive ? Colors.red : Colors.red.shade700,
                boxShadow: [
                  BoxShadow(
                    color: _emergencyActive 
                        ? Colors.red.withOpacity(0.5) 
                        : Colors.black26,
                    blurRadius: _emergencyActive ? 20 : 10,
                    spreadRadius: _emergencyActive ? 5 : 1,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  _emergencyActive ? 'STOP' : 'SOS',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}