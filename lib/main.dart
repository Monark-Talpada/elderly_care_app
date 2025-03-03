import 'package:elderly_care_app/firebase_options.dart';
import 'package:elderly_care_app/screens/auth/login_screen.dart';
import 'package:elderly_care_app/services/auth_service.dart';
import 'package:elderly_care_app/services/notification_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

void main() async {
  
  
  WidgetsFlutterBinding.ensureInitialized();

  if(kIsWeb){
  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: "AIzaSyAkwW8eKLiqRrHeywhnZqu_nOOl42VZVY8",
      authDomain: "elderlycareapp-35250.firebaseapp.com",
      projectId: "elderlycareapp-35250",
      storageBucket: "elderlycareapp-35250.firebasestorage.app",
      messagingSenderId: "1001240832274",
      appId: "1:1001240832274:web:4f01f16828a9a6fb35ebcb")
  );
  }
 else{
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  }
  
  
  
  // Initialize notifications
  await NotificationService().initialize();
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Elderly Care',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          primary: Colors.blue,
          secondary: Colors.orange,
        ),
      ),
      home: const LoginScreen(),
    );
  }
}