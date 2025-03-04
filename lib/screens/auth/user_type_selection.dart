import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elderly_care_app/models/family_model.dart';
import 'package:elderly_care_app/models/senior_model.dart';
import 'package:elderly_care_app/models/user_model.dart';
import 'package:elderly_care_app/models/volunteer_model.dart';
import 'package:elderly_care_app/screens/family/family_home.dart';
import 'package:elderly_care_app/screens/senior/senior_home.dart';
import 'package:elderly_care_app/screens/volunteer/volunteer_home.dart';
import 'package:elderly_care_app/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class UserTypeSelectionScreen extends StatefulWidget {
  final String userId;

  const UserTypeSelectionScreen({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  State<UserTypeSelectionScreen> createState() => _UserTypeSelectionScreenState();
}

class _UserTypeSelectionScreenState extends State<UserTypeSelectionScreen> {
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _selectUserType(UserType userType) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      User? user;

      // Create specific profile based on user type
      if (userType == UserType.senior) {
        SeniorCitizen? senior = await authService.createSeniorProfile(widget.userId);
        user = senior;
      } else if (userType == UserType.family) {
        FamilyMember? family = await authService.createFamilyProfile(widget.userId);
        user = family;
      } else if (userType == UserType.volunteer) {
        Volunteer? volunteer = await authService.createVolunteerProfile(widget.userId);
        user = volunteer;
      }

      if (user != null && mounted) {
        _navigateToHomeScreen(user);
      } else {
        setState(() {
          _errorMessage = 'Failed to create profile. Please try again.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _navigateToHomeScreen(User user) {
    if (user.userType == UserType.senior) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => SeniorHomeScreen(),
        ),
      );
    } else if (user.userType == UserType.family) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => FamilyHomeScreen(family: user as FamilyMember),
        ),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => VolunteerHomeScreen(volunteerId: (user as Volunteer).id),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Your Role'),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'I am a...',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Choose your role in the Elderly Care app',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 32),
                    _buildRoleCard(
                      title: 'Senior Citizen',
                      description: 'I am an elderly person looking for assistance',
                      icon: Icons.elderly,
                      color: Colors.blue,
                      onTap: () => _selectUserType(UserType.senior),
                    ),
                    const SizedBox(height: 16),
                    _buildRoleCard(
                      title: 'Family Member',
                      description: 'I am a family member of an elderly person',
                      icon: Icons.family_restroom,
                      color: Colors.green,
                      onTap: () => _selectUserType(UserType.family),
                    ),
                    const SizedBox(height: 16),
                    _buildRoleCard(
                      title: 'Volunteer',
                      description: 'I want to help elderly people in my community',
                      icon: Icons.volunteer_activism,
                      color: Colors.orange,
                      onTap: () => _selectUserType(UserType.volunteer),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildRoleCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withOpacity(0.2),
                radius: 30,
                child: Icon(
                  icon,
                  color: color,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey[400],
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}