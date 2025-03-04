import 'package:elderly_care_app/models/family_model.dart';
import 'package:elderly_care_app/models/senior_model.dart';
import 'package:elderly_care_app/models/user_model.dart';
import 'package:elderly_care_app/models/volunteer_model.dart';
import 'package:elderly_care_app/screens/auth/register_screen.dart';
import 'package:elderly_care_app/screens/family/family_home.dart';
import 'package:elderly_care_app/screens/senior/senior_home.dart';
import 'package:elderly_care_app/screens/volunteer/volunteer_home.dart';
import 'package:elderly_care_app/services/auth_service.dart';
import 'package:elderly_care_app/services/database_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _navigateToHomeScreen(User user) {
    if (user.userType == UserType.senior) {
      final senior = user as SeniorCitizen;
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
    } else if (user.userType == UserType.volunteer) {
      final volunteer = user as Volunteer;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => VolunteerHomeScreen(volunteerId: volunteer.id),
        ),
      );
    } else {
      // Handle generic user or prompt them to complete profile
      _showCompleteProfileDialog(user);
    }
  }

  void _showCompleteProfileDialog(User user) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Complete Your Profile'),
        content: const Text(
          'Please select your role to complete your profile setup.',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _setupUserProfile(user, UserType.senior);
            },
            child: const Text('Senior Citizen'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _setupUserProfile(user, UserType.family);
            },
            child: const Text('Family Member'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _setupUserProfile(user, UserType.volunteer);
            },
            child: const Text('Volunteer'),
          ),
        ],
      ),
    );
  }

  Future<void> _setupUserProfile(User user, UserType selectedType) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      User? updatedUser;

      switch (selectedType) {
        case UserType.senior:
          updatedUser = await authService.createSeniorProfile(user.id);
          break;
        case UserType.family:
          updatedUser = await authService.createFamilyProfile(user.id);
          break;
        case UserType.volunteer:
          updatedUser = await authService.createVolunteerProfile(user.id);
          break;
        default:
          throw Exception('Invalid user type selected');
      }

      setState(() {
        _isLoading = false;
      });

      if (updatedUser != null) {
        _navigateToHomeScreen(updatedUser);
      } else {
        setState(() {
          _errorMessage = 'Failed to set up profile. Please try again.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

 Future<void> _signIn() async {
  if (_isLoading) return; // Prevent multiple login attempts
  
  if (!_formKey.currentState!.validate()) {
    return;
  }

  setState(() {
    _isLoading = true;
    _errorMessage = null;
  });

  try {
    final authService = Provider.of<AuthService>(context, listen: false);
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    
    // Add additional logging for debugging
    print('Attempting to sign in with email: $email');
    
    final user = await authService.signIn(email, password);

    if (!mounted) return;
    
    if (user != null) {
      print('User login successful: ${user.id}, Type: ${user.userType}');
      
      // Create a database service for the user
      final databaseService = DatabaseService(userId: user.id);
      
      // If user is a senior, fetch the most up-to-date data
      if (user.userType == UserType.senior) {
        try {
          final currentSenior = await databaseService.getCurrentSenior();
          if (currentSenior != null && mounted) {
            _navigateToHomeScreen(currentSenior);
            return;
          }
        } catch (e) {
          print('Error fetching senior data: $e');
          // Continue with user data we already have
        }
      }
      
      if (mounted) {
        // For other user types or if senior data couldn't be fetched
        _navigateToHomeScreen(user);
      }
    } else {
      if (mounted) {
        setState(() {
          _errorMessage = 'Invalid email or password';
          _isLoading = false;
        });
      }
    }
  } catch (e) {
    print('Login error: $e');
    if (mounted) {
      setState(() {
        _errorMessage = 'Login error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App logo or icon
                  Icon(
                    Icons.elderly_outlined,
                    size: 80,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Elderly Care',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Connecting seniors with caring supporters',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: !_isPasswordVisible,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        // TODO: Implement forgot password
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Forgot password feature coming soon')),
                        );
                      },
                      child: const Text('Forgot Password?'),
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _signIn,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Sign In',
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const RegisterScreen(),
                        ),
                      );
                    },
                    child: const Text("Don't have an account? Register"),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}