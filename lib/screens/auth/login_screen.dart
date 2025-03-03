import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:elderly_care_app/screens/auth/register_screen.dart';
import 'package:elderly_care_app/screens/family/family_home.dart';
import 'package:elderly_care_app/screens/senior/senior_home.dart';
import 'package:elderly_care_app/screens/volunteer/volunteer_home.dart';

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

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      User? user = userCredential.user;
      if (user != null) {
        print("Login successful: ${user.email}");
        await _navigateToHomeScreen(user.uid);
      }
    } on FirebaseAuthException catch (e) {
      print("FirebaseAuthException: ${e.code} - ${e.message}");
      setState(() {
        _errorMessage = e.message ?? 'Invalid email or password.';
        _isLoading = false;
      });
    } catch (e) {
      print("Unexpected error: $e");
      setState(() {
        _errorMessage = 'An unexpected error occurred.';
        _isLoading = false;
      });
    }
  }

  Future<void> _navigateToHomeScreen(String userId) async {
    try {
      DocumentSnapshot userDoc =
          await FirebaseFirestore.instance.collection('users').doc(userId).get();

      if (!userDoc.exists || !userDoc.data().toString().contains('userType')) {
        setState(() {
          _errorMessage = 'User data not found or missing userType.';
          _isLoading = false;
        });
        return;
      }

      String userType = userDoc['userType'];
      switch (userType) {
        case 'senior':
          Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (context) => const SeniorHomeScreen()));
          break;
        case 'family':
          Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (context) => const FamilyHomeScreen()));
          break;
        case 'volunteer':
          Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (context) => const VolunteerHomeScreen()));
          break;
        default:
          setState(() {
            _errorMessage = 'Invalid userType assigned.';
            _isLoading = false;
          });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching user data: ${e.toString()}';
        _isLoading = false;
      });
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
                  Icon(Icons.elderly_outlined, size: 80, color: Theme.of(context).primaryColor),
                  const SizedBox(height: 24),
                  const Text('Elderly Care',
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.blue),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  const Text('Connecting seniors with caring supporters',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                      textAlign: TextAlign.center),
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
                      if (value == null || value.isEmpty) return 'Please enter your email';
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w]{2,4}$').hasMatch(value)) {
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
                        icon: Icon(_isPasswordVisible ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Please enter your password';
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {}, // TODO: Implement Forgot Password
                      child: const Text('Forgot Password?'),
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(_errorMessage!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _signIn,
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                        : const Text('Sign In', style: TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterScreen())),
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
