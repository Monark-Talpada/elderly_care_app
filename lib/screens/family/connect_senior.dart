import 'package:elderly_care_app/models/family_model.dart';
import 'package:elderly_care_app/models/senior_model.dart';
import 'package:elderly_care_app/services/auth_service.dart';
import 'package:elderly_care_app/services/database_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ConnectSeniorScreen extends StatefulWidget {
  final FamilyMember family;

  const ConnectSeniorScreen({Key? key, required this.family}) : super(key: key);

  @override
  State<ConnectSeniorScreen> createState() => _ConnectSeniorScreenState();
}

class _ConnectSeniorScreenState extends State<ConnectSeniorScreen> {
  final _formKey = GlobalKey<FormState>();
  String _email = '';
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _connectToSenior() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        // Get both services
        final authService = Provider.of<AuthService>(context, listen: false);
        final dbService = Provider.of<DatabaseService>(context, listen: false);
        
        // First, try to get the senior by email using DatabaseService
        final senior = await dbService.getSeniorByEmail(_email.trim());
        
        if (senior == null) {
          setState(() {
            _errorMessage = 'No senior found with this email';
            _isLoading = false;
          });
          return;
        }
        
        // Check if already connected
        if (widget.family.connectedSeniorIds.contains(senior.id)) {
          setState(() {
            _errorMessage = 'Already connected to this senior';
            _isLoading = false;
          });
          return;
        }

        // Use DatabaseService to update both models
        // Update family member's connectedSeniorIds
        final updatedFamily = widget.family.copyWith(
          connectedSeniorIds: [...widget.family.connectedSeniorIds, senior.id],
        );
        final familyUpdated = await dbService.updateFamilyMember(updatedFamily);

        // Update senior's connectedFamilyIds
        final updatedSenior = senior.copyWith(
          connectedFamilyIds: [...senior.connectedFamilyIds, widget.family.id],
        );
        final seniorUpdated = await dbService.updateSenior(updatedSenior);

        // Alternatively, we could use the AuthService method:
        // final success = await authService.connectSeniorWithEmail(_email.trim());

        if (!mounted) return;
        
        if (familyUpdated && seniorUpdated) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Successfully connected to senior')),
          );
          Navigator.of(context).pop();
        } else {
          setState(() {
            _errorMessage = 'Error connecting to senior';
            _isLoading = false;
          });
        }
      } catch (e) {
        setState(() {
          _errorMessage = 'Error connecting to senior: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect to Senior'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter the senior\'s email to connect',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Senior\'s Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an email';
                  }
                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
                onSaved: (value) => _email = value!,
              ),
              const SizedBox(height: 16),
              if (_errorMessage != null)
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              const SizedBox(height: 16),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _connectToSenior,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: const Text('Connect'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}