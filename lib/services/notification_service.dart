import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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
    );
    
    // Define notification channels for Android
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'This channel is used for important notifications',
      importance: Importance.high,
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
              icon: android.smallIcon,
            ),
          ),
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
      // TODO: Save the token to the user's document
    });
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

  // Add this to notification_service.dart
Future<void> sendEmergencyCancelledAlert(
  String familyId, 
  String seniorId, 
  String seniorName
) async {
  // Fetch family member doc to get FCM token
  DocumentSnapshot familyDoc = await FirebaseFirestore.instance
      .collection('users')
      .doc(familyId)
      .get();
      
  final data = familyDoc.data() as Map<String, dynamic>;
  final fcmToken = data['fcmToken'];
  
  if (fcmToken != null) {
    // For now, we'll just show a local notification
    await showLocalNotification(
      title: 'Emergency Cancelled',
      body: '$seniorName is now safe. Emergency has been cancelled.',
      payload: 'emergency_cancelled:$seniorId',
    );
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
  
  // Send emergency notification to family members
  Future<void> sendEmergencyAlert({
  required String seniorId,
  required String seniorName,
  GeoPoint? location,
}) async {
  // Fetch all connected family members
  QuerySnapshot familyDocs = await FirebaseFirestore.instance
      .collection('users')
      .where('connectedSeniorIds', arrayContains: seniorId)
      .get();
      
  // Prepare the message
  String locationStr = location != null 
      ? '${location.latitude},${location.longitude}' 
      : 'unknown';
  
  for (var doc in familyDocs.docs) {
    final data = doc.data() as Map<String, dynamic>;
    final fcmToken = data['fcmToken'];
    
    if (fcmToken != null) {
      // For now, we'll just show a local notification for demo purposes
      await showLocalNotification(
        title: 'Emergency Alert!',
        body: '$seniorName needs help! Tap to view location.',
        payload: 'emergency:$seniorId:$locationStr',
      );
    }
  }
}

// Background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) {
    print('Handling a background message: ${message.messageId}');
  }
  // Initialize necessary services
  // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}
}