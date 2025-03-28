// import 'dart:html' as html;
// import 'dart:convert';
// import 'package:js/js.dart';
// import 'notification_service.dart';

// @JS('saveOneSignalUserId')
// external void saveOneSignalUserId(String userId);

// Future<void> initializeWeb(String oneSignalAppId) async {
//   print('Initializing OneSignal for web via index.html');
//   // Listen for messages from OneSignal
//   html.window.onMessage.listen((event) {
//     print('Received message from window: ${event.data}');
//     try {
//       final data = jsonDecode(event.data);
//       if (data['type'] == 'oneSignalUserId') {
//         print('Received OneSignal user ID from web SDK: ${data['userId']}');
//         // Use the public method to set the user ID and trigger saving
//         NotificationService().setOneSignalUserId(data['userId']);
//       } else {
//         print('Message type not recognized: ${data['type']}');
//       }
//     } catch (e) {
//       print('Error decoding message: $e');
//     }
//   });
// }