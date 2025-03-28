import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:onesignal_flutter/onesignal_flutter.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  String? _pendingOneSignalUserId;
  
  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  Future<void> initialize(String oneSignalAppId) async {
    try {
      print('Initializing OneSignal with App ID: $oneSignalAppId');

      // Initialize OneSignal
      OneSignal.initialize(oneSignalAppId);

      // Request permission for push notifications
      await OneSignal.Notifications.requestPermission(true);

      // Set a handler for when a notification is opened
      OneSignal.Notifications.addClickListener((event) {
        _handleNotificationOpened(event);
      });

      // Add a listener for push subscription changes
      OneSignal.User.addObserver((state) {
        final pushSubscription = OneSignal.User.pushSubscription;
        print('OneSignal Subscription Observer: ${pushSubscription.id}');
        if (pushSubscription.id != null) {
          _pendingOneSignalUserId = pushSubscription.id;
          print('Pending OneSignal User ID set: $_pendingOneSignalUserId');
        }
      });

      // Get initial subscription ID
      final pushSubscriptionId = OneSignal.User.pushSubscription.id;
      print('Initial OneSignal Subscription ID: $pushSubscriptionId');
      if (pushSubscriptionId != null) {
        _pendingOneSignalUserId = pushSubscriptionId;
      }
    } catch (e) {
      print('Error initializing OneSignal: $e');
    }
  }

  void _handleNotificationOpened(OSNotificationClickEvent event) {
    final payload = event.notification.additionalData;
    if (payload != null) {
      _handleNotificationClick(payload);
    }
  }

  void _handleNotificationClick(Map<String, dynamic> payload) {
    if (payload.containsKey('emergency')) {
      String seniorId = payload['senior_id'] ?? '';
      String location = payload['location'] ?? 'unknown';
      if (kDebugMode) {
        print('Should navigate to emergency map for senior $seniorId at location $location');
      }
      // TODO: Implement navigation logic
    }
  }

  Future<void> saveOneSignalUserId(String userId) async {
    print('Attempting to save OneSignal User ID for user: $userId');
    
    try {
      // Get the current OneSignal User ID
      final currentOneSignalUserId = OneSignal.User.pushSubscription.id;
      print('Current OneSignal User ID: $currentOneSignalUserId');
      
      if (currentOneSignalUserId == null) {
        print('No OneSignal User ID available to save');
        return;
      }

      // Reference to the user document
      final userDocRef = FirebaseFirestore.instance.collection('users').doc(userId);

      // Check if the document exists and doesn't have the OneSignal User ID
      final userDoc = await userDocRef.get();
      
      if (!userDoc.exists) {
        print('User document does not exist');
        return;
      }

      // Check if OneSignal User ID is already set
      final currentData = userDoc.data() ?? {};
      if (currentData['oneSignalUserId'] != null) {
        print('OneSignal User ID already exists in the document');
        return;
      }

      // Update the document with the OneSignal User ID
      await userDocRef.update({
        'oneSignalUserId': currentOneSignalUserId,
      });

      print('Successfully saved OneSignal User ID: $currentOneSignalUserId for user: $userId');
    } catch (e) {
      print('Error saving OneSignal User ID: $e');
    }
  }

  void onUserLogin(String userId) {
    print('User logged in: $userId');
    saveOneSignalUserId(userId);
  }
}