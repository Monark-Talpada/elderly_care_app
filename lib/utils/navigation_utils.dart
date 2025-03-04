import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elderly_care_app/services/auth_service.dart';
import 'package:elderly_care_app/models/family_model.dart';
import 'package:elderly_care_app/models/senior_model.dart';
import 'package:elderly_care_app/models/volunteer_model.dart';

class NavigationUtils {
  static void navigateAfterLogin(BuildContext context, dynamic user) {
    if (user is FamilyMember) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/family_home', 
        (route) => false, 
        arguments: user
      );
    } else if (user is SeniorCitizen) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/senior_home', 
        (route) => false
      );
    } else if (user is Volunteer) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/volunteer_home', 
        (route) => false, 
        arguments: user
      );
    } else {
      // Fallback to login screen if user type is not recognized
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/login', 
        (route) => false
      );
    }
  }

  static void signOut(BuildContext context) {
    // Assuming you have an AuthService method to sign out
    Provider.of<AuthService>(context, listen: false).signOut();
    
    // Clear the navigation stack and go to login screen
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/login', 
      (route) => false
    );
  }
}