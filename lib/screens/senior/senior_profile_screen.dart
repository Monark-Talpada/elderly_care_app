import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elderly_care_app/services/auth_service.dart';
import 'package:elderly_care_app/services/database_service.dart';
import 'package:elderly_care_app/models/senior_model.dart';

class SeniorProfile extends StatefulWidget {
  const SeniorProfile({Key? key}) : super(key: key);

  @override
  _SeniorProfileState createState() => _SeniorProfileState();
}

class _SeniorProfileState extends State<SeniorProfile> {
  late AuthService _authService;
  late DatabaseService _databaseService;
  SeniorCitizen? _senior;
  bool _isLoading = true;
  bool _isSaving = false;

  // Controllers for editable fields
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  bool _fallDetectionEnabled = true;

  @override
  void initState() {
    super.initState();
    _authService = Provider.of<AuthService>(context, listen: false);
    _databaseService = Provider.of<DatabaseService>(context, listen: false);
    _loadSeniorData();
  }

  /// Fetches the senior's data from the database
  Future<void> _loadSeniorData() async {
    try {
      final user = _authService.currentUser;
      if (user != null) {
        final senior = await _databaseService.getSeniorById(user.id);
        if (senior != null) {
          setState(() {
            _senior = senior;
            _nameController = TextEditingController(text: _senior!.name);
            _phoneController = TextEditingController(text: _senior!.phoneNumber ?? '');
            _fallDetectionEnabled = _senior!.fallDetectionEnabled;
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading senior data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Saves the edited data back to the database
  Future<void> _saveChanges() async {
    if (_senior == null) return;

    setState(() {
      _isSaving = true;
    });

    try {
      // Create an updated SeniorCitizen object with the new values
      final updatedSenior = SeniorCitizen(
        id: _senior!.id,
        email: _senior!.email,
        name: _nameController.text,
        photoUrl: _senior!.photoUrl,
        phoneNumber: _phoneController.text,
        createdAt: _senior!.createdAt,
        connectedFamilyIds: _senior!.connectedFamilyIds,
        emergencyModeActive: _senior!.emergencyModeActive,
        lastKnownLocation: _senior!.lastKnownLocation,
        lastLocationUpdate: _senior!.lastLocationUpdate,
        fallDetectionEnabled: _fallDetectionEnabled,
      );

      // Update the database
      bool success = await _databaseService.updateSenior(updatedSenior);
      if (success) {
        setState(() {
          _senior = updatedSenior;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update profile')),
        );
      }
    } catch (e) {
      print('Error saving profile: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error saving profile')),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show a loading indicator while fetching data
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Handle case where senior data couldn't be loaded
    if (_senior == null) {
      return const Scaffold(
        body: Center(child: Text('Unable to load profile')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          // Show a loading indicator or save button based on saving state
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveChanges,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile picture display
            Center(
              child: CircleAvatar(
                radius: 50,
                backgroundImage: _senior!.photoUrl != null
                    ? NetworkImage(_senior!.photoUrl!)
                    : null,
                child: _senior!.photoUrl == null
                    ? Text(
                        _senior!.name.substring(0, 1).toUpperCase(),
                        style: const TextStyle(fontSize: 32),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            // Editable name field
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 16),
            // Non-editable email field
            TextFormField(
              initialValue: _senior!.email,
              decoration: const InputDecoration(labelText: 'Email'),
              enabled: false,
            ),
            const SizedBox(height: 16),
            // Editable phone number field
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Phone Number'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            // Toggle for fall detection
            SwitchListTile(
              title: const Text('Fall Detection Enabled'),
              value: _fallDetectionEnabled,
              onChanged: (value) {
                setState(() {
                  _fallDetectionEnabled = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}