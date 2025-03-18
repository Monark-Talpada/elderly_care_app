import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'auth_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  // Singleton pattern
  static final NotificationService _instance = NotificationService._internal();
  
  factory NotificationService() {
    return _instance;
  }
  
  NotificationService._internal();
  
  Future<void> initialize() async {
    // Request permission
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    
    // Configure local notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
        
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );
    
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    
    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
    );
    
    // Define notification channels for Android
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'This channel is used for important notifications',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );
    
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
    
    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    
    // Handle messages when the app is in the foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) {
        print('Handling a foreground message: ${message.messageId}');
      }
      
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;
      
      if (notification != null && android != null) {
        _localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              channel.id,
              channel.name,
              channelDescription: channel.description,
              icon: android.smallIcon ?? '@mipmap/ic_launcher',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: const DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          payload: message.data['payload'],
        );
      }
    });
    
    // Get the FCM token
    String? token = await _fcm.getToken();
    if (kDebugMode) {
      print('FCM Token: $token');
    }
    
    // Listen for token refresh
    _fcm.onTokenRefresh.listen((String token) {
      if (kDebugMode) {
        print('FCM Token refreshed: $token');
      }
      // User ID should be accessible through your auth service
      // You might need to adapt this part based on your authentication flow
      final authService = AuthService(); // You'd need to access this properly
      if (authService.currentUser != null) {
        saveToken(authService.currentUser!.id, token);
      }
    });
    
    // Handle notification click when app is terminated/closed
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        _handleNotificationClick(message.data['payload']);
      }
    });
    
    // Handle notification click when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationClick(message.data['payload']);
    });
  }
  
  void _onDidReceiveNotificationResponse(NotificationResponse response) {
    _handleNotificationClick(response.payload);
  }
  
  void _handleNotificationClick(String? payload) {
    if (payload == null) return;
    
    // Parse the payload
    if (payload.startsWith('emergency:')) {
      List<String> parts = payload.split(':');
      if (parts.length >= 3) {
        String seniorId = parts[1];
        String location = parts.length > 2 ? parts[2] : 'unknown';
        
        // Navigate to emergency map
        // You'll need to implement this navigation logic
        // This might require a navigation service or context
        // For now, we'll just log it
        if (kDebugMode) {
          print('Should navigate to emergency map for senior $seniorId at location $location');
        }
      }
    }
  }
  
  // Save FCM token to user document
  Future<void> saveToken(String userId, String token) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .update({
      'fcmToken': token,
    });
  }

  // Send emergency notification to family members with FCM
  Future<void> sendEmergencyAlert({
    required String seniorId,
    required String seniorName,
    GeoPoint? location,
  }) async {
    try {
      // Fetch all connected family members
      QuerySnapshot familyDocs = await FirebaseFirestore.instance
          .collection('users')
          .where('connectedSeniorIds', arrayContains: seniorId)
          .get();
          
      // Prepare the location string
      String locationStr = location != null 
          ? '${location.latitude},${location.longitude}' 
          : 'unknown';
      
      for (var doc in familyDocs.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final fcmToken = data['fcmToken'];
        
        if (fcmToken != null) {
          // For testing/development: show a local notification
          await showLocalNotification(
            title: 'Emergency Alert!',
            body: '$seniorName needs help! Tap to view location.',
            payload: 'emergency:$seniorId:$locationStr',
          );
          
          // For production: send FCM notification
          await _sendFCMNotification(
            token: fcmToken,
            title: 'Emergency Alert!',
            body: '$seniorName needs help! Tap to view location.',
            payload: 'emergency:$seniorId:$locationStr',
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error sending emergency alert: $e');
      }
    }
  }
  
  // Send emergency cancellation notification
  Future<void> sendEmergencyCancelledAlert(
    String familyId, 
    String seniorId, 
    String seniorName
  ) async {
    try {
      // Fetch family member doc to get FCM token
      DocumentSnapshot familyDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(familyId)
          .get();
          
      final data = familyDoc.data() as Map<String, dynamic>;
      final fcmToken = data['fcmToken'];
      
      if (fcmToken != null) {
        // For testing: show a local notification
        await showLocalNotification(
          title: 'Emergency Cancelled',
          body: '$seniorName is now safe. Emergency has been cancelled.',
          payload: 'emergency_cancelled:$seniorId',
        );
        
        // For production: send FCM notification
        await _sendFCMNotification(
          token: fcmToken,
          title: 'Emergency Cancelled',
          body: '$seniorName is now safe. Emergency has been cancelled.',
          payload: 'emergency_cancelled:$seniorId',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error sending cancellation alert: $e');
      }
    }
  }
  
  // Send local notification
  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      channelDescription: 'This channel is used for important notifications',
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
    );
    
    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
    
    await _localNotifications.show(
      DateTime.now().millisecond,
      title,
      body,
      platformDetails,
      payload: payload,
    );
  }
  
  // Method to send FCM messages through Firebase Cloud Functions or a server
  Future<void> _sendFCMNotification({
    required String token,
    required String title,
    required String body,
    String? payload,
  }) async {
    // NOTE: For production, you should implement this using Firebase Cloud Functions
    // or your own backend server. Direct FCM API calls should not be made from
    // the client as they require your server key, which should be kept secret.
    
    // This is a placeholder for the actual implementation that would be on your server
    if (kDebugMode) {
      print('Would send FCM notification to token: $token');
      print('Title: $title');
      print('Body: $body');
      print('Payload: $payload');
    }
    
    // In a real implementation, you would call your backend API that handles FCM
    // Example pseudo-code for calling your backend:
    /*
    try {
      final response = await http.post(
        Uri.parse('https://your-backend.com/api/send-notification'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'token': token,
          'title': title,
          'body': body,
          'payload': payload,
        }),
      );
      
      if (response.statusCode != 200) {
        if (kDebugMode) {
          print('Failed to send FCM: ${response.body}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error sending FCM: $e');
      }
    }
    */
  }
}

// This needs to be top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) {
    print('Handling a background message: ${message.messageId}');
  }
  // We would initialize Firebase here, but it seems like you are doing that in main()
  // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  // You can add additional background handling logic here if needed
}