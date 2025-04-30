import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elderly_care_app/services/auth_service.dart';
import 'package:elderly_care_app/services/database_service.dart';
import 'package:elderly_care_app/models/family_model.dart';

class FamilyProfileScreen extends StatefulWidget {
  final FamilyMember? family;

  const FamilyProfileScreen({Key? key, this.family}) : super(key: key);

  @override
  _FamilyProfileScreenState createState() => _FamilyProfileScreenState();
}

class _FamilyProfileScreenState extends State<FamilyProfileScreen> {
  late AuthService _authService;
  late DatabaseService _databaseService;
  FamilyMember? _familyMember;
  bool _isLoading = true;
  bool _isSaving = false;

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _relationshipController;
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _authService = Provider.of<AuthService>(context, listen: false);
    _databaseService = Provider.of<DatabaseService>(context, listen: false);

    if (widget.family != null) {
      _initializeFromMember(widget.family!);
    } else {
      _loadFamilyData();
    }
  }

  

  void _initializeFromMember(FamilyMember member) {
    _familyMember = member;
    _nameController = TextEditingController(text: member.name);
    _phoneController = TextEditingController(text: member.phoneNumber ?? '');
    _relationshipController = TextEditingController(text: member.relationship ?? '');
    _notificationsEnabled = member.notificationsEnabled;
    _isLoading = false;
  }

  Future<void> _loadFamilyData() async {
    try {
      final user = _authService.currentUser;
      if (user != null) {
        final member = await _databaseService.getFamilyById(user.id);
        if (member != null) {
          setState(() {
            _initializeFromMember(member);
          });
        } else {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      print('Error loading family data: $e');
      setState(() => _isLoading = false);
    }
  }


 Future<void> _saveChanges() async {
  if (_familyMember == null) return;

  setState(() => _isSaving = true);

  try {
    final updatedMember = _familyMember!.copyWith(
      name: _nameController.text,
      phoneNumber: _phoneController.text,
      relationship: _relationshipController.text,
      notificationsEnabled: _notificationsEnabled,
      connectedSeniorIds: _familyMember!.connectedSeniorIds,
      notificationPreferences: _familyMember!.notificationPreferences,
    );

    bool success = await _databaseService.updateFamily(updatedMember);
    if (success) {
      setState(() => _familyMember = updatedMember);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
        Navigator.pop(context, updatedMember);
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
    setState(() => _isSaving = false);
  }
}


  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_familyMember == null) {
      return const Scaffold(
        body: Center(child: Text('Unable to load profile')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Profile'),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(12.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
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
            Center(
              child: CircleAvatar(
                radius: 50,
                backgroundImage: _familyMember!.photoUrl != null
                    ? NetworkImage(_familyMember!.photoUrl!)
                    : null,
                child: _familyMember!.photoUrl == null
                    ? Text(
                        _familyMember!.name.substring(0, 1).toUpperCase(),
                        style: const TextStyle(fontSize: 32),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: _familyMember!.email,
              decoration: const InputDecoration(labelText: 'Email'),
              enabled: false,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Phone Number'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _relationshipController,
              decoration: const InputDecoration(labelText: 'Relationship'),
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
    _relationshipController.dispose();
    super.dispose();
  }
}
