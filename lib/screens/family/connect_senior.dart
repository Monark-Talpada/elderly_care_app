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
        final authService = Provider.of<AuthService>(context, listen: false);
        final dbService = Provider.of<DatabaseService>(context, listen: false);
        
        final senior = await dbService.getSeniorByEmail(_email.trim());
        
        if (senior == null) {
          setState(() {
            _errorMessage = 'No senior found with this email';
            _isLoading = false;
          });
          return;
        }
        
        if (widget.family.connectedSeniorIds.contains(senior.id)) {
          setState(() {
            _errorMessage = 'Already connected to this senior';
            _isLoading = false;
          });
          return;
        }

        final updatedFamily = widget.family.copyWith(
          connectedSeniorIds: [...widget.family.connectedSeniorIds, senior.id],
        );
        final familyUpdated = await dbService.updateFamilyMember(updatedFamily);

        final updatedSenior = senior.copyWith(
          connectedFamilyIds: [...senior.connectedFamilyIds, widget.family.id],
        );
        final seniorUpdated = await dbService.updateSenior(updatedSenior);

        if (!mounted) return;
        
        if (familyUpdated && seniorUpdated) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Successfully connected to senior'),
              backgroundColor: Colors.green,
            ),
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Connect to Senior',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        elevation: 0,
        backgroundColor: theme.primaryColor,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Section
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.primaryColor,
                        theme.primaryColor.withOpacity(0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.person_add,
                        size: 40,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Connect with a Senior',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Enter the senior\'s email address to establish a connection',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Form Section
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Senior\'s Email',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          decoration: InputDecoration(
                            labelText: 'Email Address',
                            prefixIcon: const Icon(Icons.email),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
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
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.red[200]!,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: Colors.red[700],
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: TextStyle(
                                      color: Colors.red[700],
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 24),
                        _isLoading
                            ? Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    theme.primaryColor,
                                  ),
                                ),
                              )
                            : ElevatedButton.icon(
                                onPressed: _connectToSenior,
                                icon: const Icon(Icons.person_add),
                                label: const Text(
                                  'Connect',
                                  style: TextStyle(fontSize: 16),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.primaryColor,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(double.infinity, 50),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}