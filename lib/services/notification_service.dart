import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:elderly_care_app/models/senior_model.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  
  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  Future<void> initialize(String oneSignalAppId) async {
    try {
      print('🔔 Initializing OneSignal with App ID: $oneSignalAppId');

      // Initialize OneSignal
      OneSignal.initialize(oneSignalAppId);

      // Request permission for push notifications
      await OneSignal.Notifications.requestPermission(true);

      // Set a handler for when a notification is opened
      OneSignal.Notifications.addClickListener((event) {
        _handleNotificationOpened(event);
      });
    } catch (e) {
      print('🚨 Error initializing OneSignal: $e');
    }
  }

  void _handleNotificationOpened(OSNotificationClickEvent event) {
    final payload = event.notification.additionalData;
    if (payload != null) {
      _handleNotificationClick(payload);
    }
  }

  // Add this to your NotificationService class

// Helper method to navigate to emergency map with a senior's ID
Future<void> navigateToEmergencyMap(String seniorId) async {
  print('🚑 Emergency navigation requested for senior: $seniorId');
  
  try {
    // Fetch senior data from Firestore
    DocumentSnapshot seniorDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(seniorId)
        .get();
    
    if (seniorDoc.exists) {
      // Convert to SeniorCitizen object
      SeniorCitizen senior = SeniorCitizen.fromFirestore(seniorDoc);
      
      // Navigate to emergency map
      navigatorKey.currentState?.pushNamed(
        '/family/emergency_map',
        arguments: [senior],
      );
      
      print('✅ Successfully navigated to emergency map');
      return;
    } else {
      print('❌ Senior document not found');
    }
  } catch (e) {
    print('🚨 Error navigating to emergency map: $e');
  }
  
  // If we get here, something went wrong
  print('⚠️ Fallback: Attempting direct navigation to emergency map');
  navigatorKey.currentState?.pushNamed('/family/emergency_map', arguments: []);
}

// Call this directly from your notification click handler
void _handleNotificationClick(Map<String, dynamic> payload) {
  print('📣 Notification clicked with payload: $payload');
  
  if (payload.containsKey('emergency') && payload.containsKey('seniorId')) {
    String seniorId = payload['seniorId'];
    print('🚨 Emergency notification for senior: $seniorId');
    
    // Use the dedicated navigation method
    navigateToEmergencyMap(seniorId);
  }
}
  // Method to explicitly save OneSignal User ID
  Future<bool> saveOneSignalUserId(String userId) async {
    try {
      // Get the current OneSignal User ID directly
      final pushSubscription = OneSignal.User.pushSubscription;
      final currentOneSignalUserId = pushSubscription.id;

      print('🔍 Attempting to save OneSignal User ID');
      print('👤 User ID: $userId');
      print('🆔 OneSignal User ID: $currentOneSignalUserId');

      if (currentOneSignalUserId == null) {
        print('❌ No OneSignal User ID available');
        return false;
      }

      // Reference to the user document
      final userDocRef = FirebaseFirestore.instance.collection('users').doc(userId);

      // Directly update the document
      await userDocRef.update({
        'oneSignalUserId': currentOneSignalUserId,
      });

      print('✅ Successfully saved OneSignal User ID to Firestore');
      return true;
    } catch (e) {
      print('🚨 Error saving OneSignal User ID: $e');
      
      // If update fails, try set with merge
      try {
        final userDocRef = FirebaseFirestore.instance.collection('users').doc(userId);
        await userDocRef.set({
          'oneSignalUserId': OneSignal.User.pushSubscription.id
        }, SetOptions(merge: true));
        
        print('✅ Saved OneSignal User ID using merge');
        return true;
      } catch (mergeError) {
        print('🚨 Error during merge: $mergeError');
        return false;
      }
    }
  }

  // Call this method immediately after login
  Future<void> onUserLogin(String userId) async {
    print('🔐 User logged in: $userId');
    
    // Short delay to ensure OneSignal is fully initialized
    await Future.delayed(Duration(seconds: 2));
    
    await saveOneSignalUserId(userId);
  }

  // Verification method
  Future<void> verifyOneSignalUserId(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      print('🕵️ User Document Data:');
      print(userDoc.data());
      print('🆔 OneSignal User ID in Document: ${userDoc.data()?['oneSignalUserId']}');
    } catch (e) {
      print('🚨 Error verifying OneSignal User ID: $e');
    }
  }
}