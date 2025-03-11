import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elderly_care_app/services/auth_service.dart';
import 'package:elderly_care_app/screens/auth/login_screen.dart';
import 'package:elderly_care_app/utils/navigation_utils.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginState();
  }

  Future<void> _checkLoginState() async {
    // Short delay to show splash screen
    await Future.delayed(const Duration(seconds: 2));
    
    if (!mounted) return;
    
    final authService = Provider.of<AuthService>(context, listen: false);
    await authService.initializeAuth();
    
    if (!mounted) return;
    
    if (authService.isLoggedIn && authService.currentUser != null) {
      // User is already logged in, navigate to appropriate home screen
      NavigationUtils.navigateAfterLogin(context, authService.currentUser!);
    } else {
      // No logged in user, go to login screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.elderly_outlined,
              size: 100,
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
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}