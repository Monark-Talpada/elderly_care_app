import 'package:elderly_care_app/firebase_options.dart';
import 'package:elderly_care_app/screens/auth/login_screen.dart';
import 'package:elderly_care_app/screens/auth/register_screen.dart';
import 'package:elderly_care_app/screens/auth/user_type_selection.dart';
import 'package:elderly_care_app/screens/family/family_home.dart';
import 'package:elderly_care_app/screens/senior/senior_home.dart';
import 'package:elderly_care_app/screens/senior/family_connection.dart';
import 'package:elderly_care_app/screens/senior/senior_appointments_screen.dart';
import 'package:elderly_care_app/screens/volunteer/volunteer_home.dart';
import 'screens/volunteer/volunteer_profile_screen.dart';

// New screen imports
import 'package:elderly_care_app/screens/family/connect_senior.dart';
import 'package:elderly_care_app/screens/family/senior_profile.dart';
import 'package:elderly_care_app/screens/family/family_profile.dart';
import 'package:elderly_care_app/screens/family/senior_profile.dart';
import 'package:elderly_care_app/screens/family/emergency_map.dart';
import 'package:elderly_care_app/screens/auth/splash_screen.dart';
import 'package:elderly_care_app/screens/senior/daily_needs.dart';
import 'package:elderly_care_app/screens/senior/add_need.dart';
import 'screens/senior/senior_profile_screen.dart';
import 'screens/senior/select_volunteer.dart';
import 'package:elderly_care_app/screens/senior/emergency_button.dart';
import 'package:elderly_care_app/screens/senior/emergency_contacts.dart';
import 'package:elderly_care_app/screens/volunteer/appointments.dart';
import 'package:elderly_care_app/screens/volunteer/availability.dart';
import 'package:elderly_care_app/services/auth_service.dart';
import 'package:elderly_care_app/services/notification_service.dart';
import 'package:elderly_care_app/services/database_service.dart';
import 'package:elderly_care_app/services/storage_service.dart';
import 'package:elderly_care_app/models/family_model.dart';
import 'package:elderly_care_app/models/senior_model.dart';
import 'package:elderly_care_app/models/volunteer_model.dart';
import 'package:elderly_care_app/models/need_model.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';



void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyAkwW8eKLiqRrHeywhnZqu_nOOl42VZVY8",
        authDomain: "elderlycareapp-35250.firebaseapp.com",
        projectId: "elderlycareapp-35250",
        storageBucket: "elderlycareapp-35250.firebasestorage.app",
        messagingSenderId: "1001240832274",
        appId: "1:1001240832274:web:4f01f16828a9a6fb35ebcb",
      ),
    );
  } else {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

 
  NotificationService().initialize('b00dcbca-ae9e-4275-b465-20370bb2a03f');

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>(
          create: (_) => AuthService(),
        ),
        ChangeNotifierProvider<DatabaseService>(
          create: (_) => DatabaseService(),
        ),
        Provider<NotificationService>(create: (_) => NotificationService()),
        Provider<StorageService>(create: (_) => StorageService()),
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
            navigatorKey: navigatorKey, // Add this

      debugShowCheckedModeBanner: false, 
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
      // Updated routes to include new screens
        routes: {
      '/': (context) => const SplashScreen(),
      '/login': (context) => const LoginScreen(),
      '/register': (context) => const RegisterScreen(),
      '/user_type_selection': (context) {
        final args = ModalRoute.of(context)!.settings.arguments as String;
        return UserTypeSelectionScreen(userId: args);
      },
      '/senior_home': (context) => const SeniorHomeScreen(),
      '/family_home': (context) {
        final args = ModalRoute.of(context)!.settings.arguments as FamilyMember;
        return FamilyHomeScreen(family: args);
      },
      '/volunteer_home': (context) {
        final args = ModalRoute.of(context)!.settings.arguments as Volunteer;
        return VolunteerHomeScreen(volunteerId: args.id);
      },
      '/volunteer_profile': (context) => VolunteerProfileScreen(
  volunteer: ModalRoute.of(context)!.settings.arguments as Volunteer,
),
      
      // Emergency and additional screens
      '/emergency_button': (context) => const EmergencyButtonScreen(),
      
      // Family screens
      '/family/connect_senior': (context) {
        final args = ModalRoute.of(context)!.settings.arguments as FamilyMember;
        return ConnectSeniorScreen(family: args);
      },

       

      '/family/family_profile': (context) {
        final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
        return SeniorProfileScreen(
          senior: args['senior'] as SeniorCitizen, 
          familyMember: args['familyMember'] as FamilyMember,
        );
      },
      '/family/emergency_map': (context) {
        final args = ModalRoute.of(context)!.settings.arguments as List<SeniorCitizen>;
        return EmergencyMapScreen(seniors: args);
      },
       
    '/senior_profile': (context) => const SeniorProfileScreen(
          senior: null, // Will be overridden by arguments
          familyMember: null, // Will be overridden by arguments
        ), 
    
  
       '/senior/emergency_contacts': (context) => const EmergencyContactsScreen(),

      // Senior Needs-related routes
      '/senior/daily_needs': (context) => const DailyNeedsScreen(),
      '/senior/add_need': (context) => const AddNeedScreen(),
      '/senior/edit_need': (context) {
        final need = ModalRoute.of(context)!.settings.arguments as DailyNeed;
        return AddNeedScreen(need: need);
      },
      '/senior/senior_appointments_screen': (context) => SeniorAppointmentsScreen(
  seniorId: ModalRoute.of(context)!.settings.arguments as String,
),
      '/senior/profile': (context) => SeniorProfile(),

      '/family/profile': (context) => FamilyProfileScreen(),
      
      '/senior/select_volunteer': (context) => const SelectVolunteerScreen(),

      '/senior/family_connections': (context) => const FamilyConnectionsScreen(),

      // Volunteer-related routes
      '/volunteer/appointments': (context) {
        final args = ModalRoute.of(context)!.settings.arguments as Volunteer;
        return AppointmentsScreen(volunteer: args);
      },
      '/volunteer/availability': (context) {
        final args = ModalRoute.of(context)!.settings.arguments as Volunteer;
        return AvailabilityScreen(volunteer: args);
      },
    },
      initialRoute: '/',
      onGenerateRoute: (settings) => null,
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(title: const Text('Not Found')),
            body: const Center(child: const Text('Page not found')),
          ),
        );
      },
    );
  }
}