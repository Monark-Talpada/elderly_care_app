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

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _heightController;
  late TextEditingController _weightController;
  late TextEditingController _bloodGroupController;
  late TextEditingController _allergiesController;
  late TextEditingController _medicationsController;
  late TextEditingController _medicalConditionsController;
  late TextEditingController _emergencyContactNameController;
  late TextEditingController _emergencyContactPhoneController;
  late TextEditingController _primaryPhysicianNameController;
  late TextEditingController _primaryPhysicianPhoneController;

  @override
  void initState() {
    super.initState();
    _authService = Provider.of<AuthService>(context, listen: false);
    _databaseService = Provider.of<DatabaseService>(context, listen: false);
    _loadSeniorData();
  }

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
            _heightController = TextEditingController(text: _senior!.height?.toString() ?? '');
            _weightController = TextEditingController(text: _senior!.weight?.toString() ?? '');
            _bloodGroupController = TextEditingController(text: _senior!.bloodGroup ?? '');
            _allergiesController = TextEditingController(text: _senior!.allergies?.join(', ') ?? '');
            _medicationsController = TextEditingController(text: _senior!.medications?.join(', ') ?? '');
            _medicalConditionsController = TextEditingController(text: _senior!.medicalConditions?.join(', ') ?? '');
            _emergencyContactNameController = TextEditingController(text: _senior!.emergencyContactName ?? '');
            _emergencyContactPhoneController = TextEditingController(text: _senior!.emergencyContactPhone ?? '');
            _primaryPhysicianNameController = TextEditingController(text: _senior!.primaryPhysicianName ?? '');
            _primaryPhysicianPhoneController = TextEditingController(text: _senior!.primaryPhysicianPhone ?? '');
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

  Future<void> _saveChanges() async {
    if (_senior == null) return;

    setState(() {
      _isSaving = true;
    });

    try {
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
        height: double.tryParse(_heightController.text),
        weight: double.tryParse(_weightController.text),
        bloodGroup: _bloodGroupController.text.isNotEmpty ? _bloodGroupController.text : null,
        allergies: _allergiesController.text.isNotEmpty ? _allergiesController.text.split(',').map((e) => e.trim()).toList() : null,
        medications: _medicationsController.text.isNotEmpty ? _medicationsController.text.split(',').map((e) => e.trim()).toList() : null,
        medicalConditions: _medicalConditionsController.text.isNotEmpty ? _medicalConditionsController.text.split(',').map((e) => e.trim()).toList() : null,
        emergencyContactName: _emergencyContactNameController.text.isNotEmpty ? _emergencyContactNameController.text : null,
        emergencyContactPhone: _emergencyContactPhoneController.text.isNotEmpty ? _emergencyContactPhoneController.text : null,
        primaryPhysicianName: _primaryPhysicianNameController.text.isNotEmpty ? _primaryPhysicianNameController.text : null,
        primaryPhysicianPhone: _primaryPhysicianPhoneController.text.isNotEmpty ? _primaryPhysicianPhoneController.text : null,
      );

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

  Widget _buildCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    int? maxLines,
    String? hintText,
    bool enabled = true,
  }) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: theme.primaryColor.withOpacity(0.3),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: theme.primaryColor,
              width: 2,
            ),
          ),
          prefixIcon: Icon(
            _getFieldIcon(label),
            color: theme.primaryColor,
          ),
          filled: true,
          fillColor: theme.primaryColor.withOpacity(0.05),
        ),
      ),
    );
  }

  IconData _getFieldIcon(String label) {
    switch (label.toLowerCase()) {
      case 'name':
        return Icons.person;
      case 'phone number':
        return Icons.phone;
      case 'email':
        return Icons.email;
      case 'height':
        return Icons.height;
      case 'weight':
        return Icons.monitor_weight;
      case 'blood group':
        return Icons.bloodtype;
      case 'allergies':
        return Icons.warning;
      case 'current medications':
        return Icons.medication;
      case 'medical conditions':
        return Icons.medical_services;
      case 'emergency contact name':
        return Icons.emergency;
      case 'emergency contact phone':
        return Icons.phone_android;
      case 'primary physician name':
        return Icons.medical_information;
      case 'primary physician phone':
        return Icons.phone_iphone;
      default:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_senior == null) {
      return const Scaffold(
        body: Center(child: Text('Unable to load profile')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        elevation: 0,
        backgroundColor: theme.primaryColor,
        actions: [
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.primaryColor.withOpacity(0.1),
              Colors.white,
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.primaryColor,
                      width: 2,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 50,
                    backgroundImage: _senior!.photoUrl != null
                        ? NetworkImage(_senior!.photoUrl!)
                        : null,
                    child: _senior!.photoUrl == null
                        ? Text(
                            _senior!.name.substring(0, 1).toUpperCase(),
                            style: TextStyle(
                              fontSize: 32,
                              color: theme.primaryColor,
                            ),
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildCard(
                title: 'Personal Information',
                child: Column(
                  children: [
                    _buildTextField(
                      controller: _nameController,
                      label: 'Name',
                    ),
                    _buildTextField(
                      controller: _phoneController,
                      label: 'Phone Number',
                      keyboardType: TextInputType.phone,
                    ),
                    _buildTextField(
                      controller: TextEditingController(text: _senior!.email),
                      label: 'Email',
                      enabled: false,
                    ),
                  ],
                ),
              ),
              _buildCard(
                title: 'Physical Details',
                child: Column(
                  children: [
                    _buildTextField(
                      controller: _heightController,
                      label: 'Height (cm)',
                      keyboardType: TextInputType.number,
                    ),
                    _buildTextField(
                      controller: _weightController,
                      label: 'Weight (kg)',
                      keyboardType: TextInputType.number,
                    ),
                    _buildTextField(
                      controller: _bloodGroupController,
                      label: 'Blood Group',
                    ),
                  ],
                ),
              ),
              _buildCard(
                title: 'Health Information',
                child: Column(
                  children: [
                    _buildTextField(
                      controller: _allergiesController,
                      label: 'Allergies',
                      hintText: 'Enter allergies separated by commas',
                      maxLines: 2,
                    ),
                    _buildTextField(
                      controller: _medicationsController,
                      label: 'Current Medications',
                      hintText: 'Enter medications separated by commas',
                      maxLines: 2,
                    ),
                    _buildTextField(
                      controller: _medicalConditionsController,
                      label: 'Medical Conditions',
                      hintText: 'Enter conditions separated by commas',
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              _buildCard(
                title: 'Emergency Contacts',
                child: Column(
                  children: [
                    _buildTextField(
                      controller: _emergencyContactNameController,
                      label: 'Emergency Contact Name',
                    ),
                    _buildTextField(
                      controller: _emergencyContactPhoneController,
                      label: 'Emergency Contact Phone',
                      keyboardType: TextInputType.phone,
                    ),
                  ],
                ),
              ),
              _buildCard(
                title: 'Primary Physician',
                child: Column(
                  children: [
                    _buildTextField(
                      controller: _primaryPhysicianNameController,
                      label: 'Primary Physician Name',
                    ),
                    _buildTextField(
                      controller: _primaryPhysicianPhoneController,
                      label: 'Primary Physician Phone',
                      keyboardType: TextInputType.phone,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _bloodGroupController.dispose();
    _allergiesController.dispose();
    _medicationsController.dispose();
    _medicalConditionsController.dispose();
    _emergencyContactNameController.dispose();
    _emergencyContactPhoneController.dispose();
    _primaryPhysicianNameController.dispose();
    _primaryPhysicianPhoneController.dispose();
    super.dispose();
  }
}
