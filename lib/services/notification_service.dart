import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:elderly_care_app/models/senior_model.dart';
import 'package:elderly_care_app/services/database_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:elderly_care_app/models/family_model.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  
  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  // Firestore collections
  final CollectionReference _notificationsCollection = 
      FirebaseFirestore.instance.collection('notifications');
  final CollectionReference _usersCollection = 
      FirebaseFirestore.instance.collection('users');

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

  // Trigger an emergency alert
  Future<void> triggerEmergencyAlert({
    required String seniorId,
    required GeoPoint location,
    String? message,
  }) async {
    try {
      print('🚨 Triggering emergency alert for senior: $seniorId');
      
      // Create an emergency document in Firestore
      // This will trigger the backend service to send notifications
      await FirebaseFirestore.instance.collection('emergencies').add({
        'seniorId': seniorId,
        'location': location,
        'message': message,
        'active': true,
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      print('✅ Emergency alert created successfully');
    } catch (e) {
      print('🚨 Error creating emergency alert: $e');
    }
  }
  
  // Cancel an emergency alert
  Future<void> cancelEmergencyAlert(String emergencyId) async {
    try {
      print('🔄 Cancelling emergency alert: $emergencyId');
      
      // Update the emergency document to inactive
      // This will trigger the backend service to send cancellation notifications
      await FirebaseFirestore.instance
          .collection('emergencies')
          .doc(emergencyId)
          .update({
        'active': false,
        'cancelledAt': FieldValue.serverTimestamp(),
      });
      
      print('✅ Emergency alert cancelled successfully');
    } catch (e) {
      print('🚨 Error cancelling emergency alert: $e');
    }
  }
  
  // General purpose notification sender - compatible with your backend
  Future<void> sendNotification({
    required String userId,
    required String title,
    required String message,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      print('📣 Sending notification to user: $userId');
      print('📝 Title: $title');
      print('📝 Message: $message');
      print('📝 Additional Data: $additionalData');
      
      // Get the user document to find OneSignal ID
      final userDoc = await _usersCollection.doc(userId).get();
      final userData = userDoc.data() as Map<String, dynamic>?;

      if (!userDoc.exists || userData == null || userData['oneSignalUserId'] == null) {
        print('🚨 No OneSignal User ID found for user: $userId');
        return;
      }

      final oneSignalUserId = userData['oneSignalUserId'] as String;
      
      // Create notification document that matches exactly what our backend expects
      await _notificationsCollection.add({
        'recipientOneSignalId': oneSignalUserId,
        'title': title,
        'body': message, // Note: body field matches backend expectations
        'data': additionalData ?? {}, // Additional data for payload
        'status': 'pending', // Backend will look for 'pending' status
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      print('✅ Notification request created for user $userId');
    } catch (e) {
      print('🚨 Error creating notification: $e');
    }
  }
  
  // Send appointment notification - specialized method for appointments
  Future<void> sendAppointmentNotification({
    required String userId,
    required String title,
    required String message,
    required String appointmentId,
    required String action,
  }) async {
    // Use the general method with appointment-specific data
    await sendNotification(
      userId: userId,
      title: title,
      message: message,
      additionalData: {
        'appointmentId': appointmentId,
        'action': action,
      },
    );
  }

 void _handleNotificationClick(Map<String, dynamic> payload) {
  print('📣 Notification clicked with payload: $payload');
  
  // Handle emergency notification
  if (payload.containsKey('emergency') && payload.containsKey('senior_id')) {
    String seniorId = payload['senior_id'];
    print('🚨 Emergency notification for senior: $seniorId');
    navigateToEmergencyMap(seniorId);
  } 
  // Handle emergency cancellation notification
  else if (payload.containsKey('emergency_cancelled') && payload.containsKey('senior_id')) {
    print('✅ Emergency cancellation received');
    // Could navigate to a specific screen or show a dialog
  }
  // Handle appointment notification
  else if (payload.containsKey('appointmentId') && payload.containsKey('action')) {
    String appointmentId = payload['appointmentId'];
    String action = payload['action'];
    print('📅 Appointment notification: $action for appointment $appointmentId');
    navigateToAppointmentScreen(appointmentId, action);
  }
  // Handle need notification
  else if (payload.containsKey('needId') && payload.containsKey('seniorId') && payload.containsKey('action') && payload['action'] == 'view_need') {
    String needId = payload['needId'];
    String seniorId = payload['seniorId'];
    print('📋 Need notification for need: $needId, senior: $seniorId');
    navigateToSeniorProfileNeeds(seniorId, needId);
  }
}
  // Navigate to emergency map
  Future<void> navigateToEmergencyMap(String seniorId) async {
    print('🚑 Emergency navigation requested for senior: $seniorId');
    
    try {
      DocumentSnapshot seniorDoc = await _usersCollection.doc(seniorId).get();
      
      if (seniorDoc.exists) {
        SeniorCitizen senior = SeniorCitizen.fromFirestore(seniorDoc);
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
    
    print('⚠️ Fallback: Attempting direct navigation to emergency map');
    navigatorKey.currentState?.pushNamed('/family/emergency_map', arguments: []);
  }

  // Navigate to appointment screen
  Future<void> navigateToAppointmentScreen(String appointmentId, String action) async {
    print('📅 Navigating to appointment screen for appointment: $appointmentId, action: $action');
    
    try {
      // Navigate to the senior appointments screen
      navigatorKey.currentState?.pushNamed(
        '/senior_appointments_screen', // Ensure this route is defined in your app
        arguments: {
          'appointmentId': appointmentId,
          'action': action, // 'start' or 'end'
        },
      );
      print('✅ Successfully navigated to appointment screen');
    } catch (e) {
      print('🚨 Error navigating to appointment screen: $e');
    }
  }

  // Navigate to senior profile needs section
Future<void> navigateToSeniorProfileNeeds(String seniorId, String needId) async {
  print('📋 Navigating to senior profile needs tab for senior: $seniorId, need: $needId');
  
  try {
    // Fetch the senior
    final senior = await DatabaseService().getSeniorById(seniorId);
    if (senior == null) {
      print('🚨 Senior not found: $seniorId');
      return;
    }

    // Fetch the current family member (assuming the user is logged in)
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      print('🚨 No logged-in user found');
      return;
    }
    final familyMember = await DatabaseService().getFamilyById(userId);
    if (familyMember == null) {
      print('🚨 Family member not found: $userId');
      return;
    }

    navigatorKey.currentState?.pushNamed(
      '/senior_profile', // Ensure this route matches your SeniorProfileScreen
      arguments: {
        'senior': senior,
        'familyMember': familyMember,
        'needId': needId, // To highlight or scroll to the specific need
        'tabIndex': 1, // Select the NEEDS tab (index 1)
      },
    );
    print('✅ Successfully navigated to senior profile');
  } catch (e) {
    print('🚨 Error navigating to senior profile: $e');
  }
}
  // Save OneSignal User ID
  Future<bool> saveOneSignalUserId(String userId) async {
    try {
      final pushSubscription = OneSignal.User.pushSubscription;
      final currentOneSignalUserId = pushSubscription.id;

      print('🔍 Attempting to save OneSignal User ID');
      print('👤 User ID: $userId');
      print('🆔 OneSignal User ID: $currentOneSignalUserId');

      if (currentOneSignalUserId == null) {
        print('❌ No OneSignal User ID available');
        return false;
      }

      await _usersCollection.doc(userId).update({
        'oneSignalUserId': currentOneSignalUserId,
      });

      print('✅ Successfully saved OneSignal User ID to Firestore');
      return true;
    } catch (e) {
      print('🚨 Error saving OneSignal User ID: $e');
      try {
        await _usersCollection.doc(userId).set({
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

  // Handle user login
  Future<void> onUserLogin(String userId) async {
    print('🔐 User logged in: $userId');
    await Future.delayed(Duration(seconds: 2));
    await saveOneSignalUserId(userId);
  }

  // Verify OneSignal User ID
  Future<void> verifyOneSignalUserId(String userId) async {
    try {
      final userDoc = await _usersCollection.doc(userId).get();
      final userData = userDoc.data() as Map<String, dynamic>?;

      print('🕵️ User Document Data:');
      print(userData);
      print('🆔 OneSignal User ID in Document: ${userData?['oneSignalUserId']}');
    } catch (e) {
      print('🚨 Error verifying OneSignal User ID: $e');
    }
  }
}