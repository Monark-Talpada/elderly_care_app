import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elderly_care_app/models/family_model.dart';
import 'package:elderly_care_app/models/senior_model.dart';
import 'package:elderly_care_app/models/volunteer_model.dart';
import 'package:elderly_care_app/models/user_model.dart';
import 'package:elderly_care_app/services/notification_service.dart'; // Import NotificationService
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService extends ChangeNotifier {
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? _currentUser;

  User? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  AuthService() {
    _auth.authStateChanges().listen(_onAuthStateChanged);
    _checkSavedLogin(); // Check for saved login on initialization
  }

  // Check for saved login credentials
  Future<void> _checkSavedLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool('is_logged_in') ?? false;

      if (isLoggedIn) {
        final firebaseUser = _auth.currentUser;
        if (firebaseUser != null) {
          await _fetchUserData(firebaseUser);
          // In methods like signIn, register, createSeniorProfile, etc.
NotificationService().onUserLogin(_currentUser!.id); // Save OneSignal ID if logged in
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error checking saved login: $e');
      }
    }
  }

  Future<void> _onAuthStateChanged(firebase_auth.User? firebaseUser) async {
  if (firebaseUser == null) {
    _currentUser = null;
    notifyListeners();
    return;
  }

  try {
    DocumentSnapshot userDoc = await _firestore
        .collection('users')
        .doc(firebaseUser.uid)
        .get();

    if (userDoc.exists) {
      Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
      String userType = data['userType'] ?? '';

      // Ensure OneSignal user ID is added during auth state change
      await _ensureOneSignalUserIdExists(firebaseUser.uid);

      // Rest of the existing code remains the same...
    } else {
      _currentUser = null;
    }

    notifyListeners();

    // Save OneSignal ID when auth state changes and user is set
    if (_currentUser != null) {
// In methods like signIn, register, createSeniorProfile, etc.
NotificationService().onUserLogin(_currentUser!.id);
      _saveLoginState(firebaseUser.uid, firebaseUser.email ?? '');
    }
  } catch (e) {
    if (kDebugMode) {
      print('Error fetching user data: $e');
    }
    _currentUser = null;
    notifyListeners();
  }
}

// New method to ensure OneSignal user ID exists
Future<void> _ensureOneSignalUserIdExists(String userId) async {
  try {
    final userDoc = await _firestore.collection('users').doc(userId).get();
    
    if (userDoc.exists) {
      final userData = userDoc.data() ?? {};
      
      // If OneSignal user ID is not present, initialize it
      if (userData['oneSignalUserId'] == null) {
        // Trigger OneSignal user ID generation and saving
// In methods like signIn, register, createSeniorProfile, etc.
NotificationService().onUserLogin(_currentUser!.id);      }
    }
  } catch (e) {
    if (kDebugMode) {
      print('Error ensuring OneSignal user ID: $e');
    }
  }
}

  Future<void> _fetchUserData(firebase_auth.User firebaseUser) async {
    try {
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(firebaseUser.uid)
          .get();

      if (userDoc.exists) {
        Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
        String userType = data['userType'] ?? '';

        if (userType == 'senior') {
          DocumentSnapshot seniorDoc = await _firestore
              .collection('seniors')
              .doc(firebaseUser.uid)
              .get();

          if (seniorDoc.exists) {
            Map<String, dynamic> seniorData = seniorDoc.data() as Map<String, dynamic>;
            Map<String, dynamic> mergedData = {...data, ...seniorData};
            _currentUser = SeniorCitizen.fromMap(mergedData, userDoc.id);
          } else {
            _currentUser = SeniorCitizen.fromFirestore(userDoc);
          }
        } else if (userType == 'family') {
          DocumentSnapshot familyDoc = await _firestore
              .collection('family_member')
              .doc(firebaseUser.uid)
              .get();

          if (familyDoc.exists) {
            Map<String, dynamic> familyData = familyDoc.data() as Map<String, dynamic>;
            Map<String, dynamic> mergedData = {...data, ...familyData};
            _currentUser = FamilyMember.fromMap(mergedData, userDoc.id);
          } else {
            _currentUser = FamilyMember.fromFirestore(userDoc);
          }
        } else if (userType == 'volunteer') {
          DocumentSnapshot volunteerDoc = await _firestore
              .collection('volunteers')
              .doc(firebaseUser.uid)
              .get();

          if (volunteerDoc.exists) {
            Map<String, dynamic> volunteerData = volunteerDoc.data() as Map<String, dynamic>;
            Map<String, dynamic> mergedData = {...data, ...volunteerData};
            _currentUser = Volunteer.fromMap(mergedData, userDoc.id);
          } else {
            _currentUser = Volunteer.fromFirestore(userDoc);
          }
        } else {
          _currentUser = User.fromFirestore(userDoc);
        }
      } else {
        _currentUser = null;
      }

      notifyListeners();

      if (_currentUser != null) {
        _saveLoginState(firebaseUser.uid, firebaseUser.email ?? '');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching user data: $e');
      }
      _currentUser = null;
      notifyListeners();
    }
  }

  Future<void> _saveLoginState(String userId, String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_logged_in', true);
      await prefs.setString('user_id', userId);
      await prefs.setString('user_email', email);
    } catch (e) {
      if (kDebugMode) {
        print('Error saving login state: $e');
      }
    }
  }

  Future<User?> signIn(String email, String password) async {
    try {
      // Clear current user state first
      _currentUser = null;

      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final firebaseUser = userCredential.user;
      if (firebaseUser == null) {
        return null;
      }

      await _fetchUserData(firebaseUser);

      // Save OneSignal ID after successful sign-in
      // In methods like signIn, register, createSeniorProfile, etc.
NotificationService().onUserLogin(_currentUser!.id);

      if (_currentUser != null) {
        await _saveLoginState(firebaseUser.uid, email);
      }

      return _currentUser;
    } catch (e) {
      if (kDebugMode) {
        print('Sign in error: $e');
      }
      return null;
    }
  }

  Future<User?> register({
    required String email,
    required String password,
    required String name,
    required UserType userType,
    String? phoneNumber,
  }) async {
    try {
      final firebase_auth.UserCredential result =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final firebase_auth.User? firebaseUser = result.user;

      if (firebaseUser != null) {
        final userData = User(
          id: firebaseUser.uid,
          email: email,
          name: name,
          userType: userType,
          phoneNumber: phoneNumber,
          createdAt: DateTime.now(),
        );

        await _firestore
            .collection('users')
            .doc(firebaseUser.uid)
            .set(userData.toMap());

        _currentUser = userData;
        notifyListeners();

        // Save OneSignal ID after registration
        // In methods like signIn, register, createSeniorProfile, etc.
NotificationService().onUserLogin(_currentUser!.id);

        await _saveLoginState(firebaseUser.uid, email);

        return userData;
      }

      return null;
    } catch (e) {
      if (e is firebase_auth.FirebaseAuthException && e.code == 'email-already-in-use') {
        if (kDebugMode) {
          print('Email already in use. Please use a different email or sign in.');
        }
      } else {
        if (kDebugMode) {
          print('Registration error: $e');
        }
      }
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
      _currentUser = null;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_logged_in', false);
      await prefs.remove('user_id');
      await prefs.remove('user_email');

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error signing out: $e');
      }
    }
  }

  Future<SeniorCitizen?> createSeniorProfile(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'userType': 'senior',
      });

      await _firestore.collection('seniors').doc(userId).set({
        'userId': userId,
        'connectedFamilyIds': [],
        'emergencyModeActive': false,
        'lastLocationUpdate': FieldValue.serverTimestamp(),
      });

      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(userId)
          .get();

      DocumentSnapshot seniorDoc = await _firestore
          .collection('seniors')
          .doc(userId)
          .get();

      if (userDoc.exists && seniorDoc.exists) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        Map<String, dynamic> seniorData = seniorDoc.data() as Map<String, dynamic>;
        Map<String, dynamic> mergedData = {...userData, ...seniorData};

        final senior = SeniorCitizen.fromMap(mergedData, userId);
        _currentUser = senior;
        notifyListeners();

        // Save OneSignal ID after profile creation
        // In methods like signIn, register, createSeniorProfile, etc.
NotificationService().onUserLogin(_currentUser!.id);

        return senior;
      }

      return null;
    } catch (e) {
      if (e is FirebaseException && e.code == 'permission-denied') {
        if (kDebugMode) {
          print('Permission denied: Please check Firebase security rules');
        }
      } else {
        if (kDebugMode) {
          print('Error creating senior profile: $e');
        }
      }
      return null;
    }
  }

  Future<FamilyMember?> createFamilyProfile(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'userType': 'family',
      });

      await _firestore.collection('family_member').doc(userId).set({
        'userId': userId,
        'connectedSeniorIds': [],
      });

      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(userId)
          .get();

      DocumentSnapshot familyDoc = await _firestore
          .collection('family_member')
          .doc(userId)
          .get();

      if (userDoc.exists && familyDoc.exists) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        Map<String, dynamic> familyData = familyDoc.data() as Map<String, dynamic>;
        Map<String, dynamic> mergedData = {...userData, ...familyData};

        final family = FamilyMember.fromMap(mergedData, userId);
        _currentUser = family;
        notifyListeners();

        // Save OneSignal ID after profile creation
        // In methods like signIn, register, createSeniorProfile, etc.
NotificationService().onUserLogin(_currentUser!.id);

        return family;
      }

      return null;
    } catch (e) {
      if (e is FirebaseException && e.code == 'permission-denied') {
        if (kDebugMode) {
          print('Permission denied: Please check Firebase security rules');
        }
      } else {
        if (kDebugMode) {
          print('Error creating family profile: $e');
        }
      }
      return null;
    }
  }

  Future<Volunteer?> createVolunteerProfile(String userId) async {
    try {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        if (kDebugMode) {
          print('User document does not exist. Creating user first...');
        }
        await _firestore.collection('users').doc(userId).set({
          'userType': 'volunteer',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await _firestore.collection('users').doc(userId).update({
        'userType': 'volunteer',
      });

      await _firestore.collection('volunteers').doc(userId).set({
        'userId': userId,
        'availability': {},
        'totalHoursVolunteered': 0,
      });

      userDoc = await _firestore
          .collection('users')
          .doc(userId)
          .get();

      DocumentSnapshot volunteerDoc = await _firestore
          .collection('volunteers')
          .doc(userId)
          .get();

      if (userDoc.exists && volunteerDoc.exists) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        Map<String, dynamic> volunteerData = volunteerDoc.data() as Map<String, dynamic>;
        Map<String, dynamic> mergedData = {...userData, ...volunteerData};

        final volunteer = Volunteer.fromMap(mergedData, userId);
        _currentUser = volunteer;
        notifyListeners();

        // Save OneSignal ID after profile creation
        // In methods like signIn, register, createSeniorProfile, etc.
NotificationService().onUserLogin(_currentUser!.id);

        return volunteer;
      }

      return null;
    } catch (e) {
      if (e is FirebaseException && e.code == 'permission-denied') {
        if (kDebugMode) {
          print('Permission denied: Please check Firebase security rules');
        }
      } else {
        if (kDebugMode) {
          print('Error creating volunteer profile: $e');
        }
      }
      return null;
    }
  }

  Future<bool> connectSeniorWithEmail(String seniorEmail) async {
    if (_currentUser == null || _currentUser!.userType != UserType.family) {
      return false;
    }

    try {
      final QuerySnapshot seniorQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: seniorEmail)
          .where('userType', isEqualTo: 'senior')
          .limit(1)
          .get();

      if (seniorQuery.docs.isEmpty) {
        return false;
      }

      final String seniorId = seniorQuery.docs.first.id;

      final FamilyMember family = _currentUser as FamilyMember;
      if (!family.connectedSeniorIds.contains(seniorId)) {
        await _firestore.collection('family_member').doc(family.id).update({
          'connectedSeniorIds': FieldValue.arrayUnion([seniorId]),
        });
      }

      await _firestore.collection('seniors').doc(seniorId).update({
        'connectedFamilyIds': FieldValue.arrayUnion([family.id]),
      });

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error connecting with senior: $e');
      }
      return false;
    }
  }

  Future<bool> handleRoleSelection(UserType userType, String userId) async {
    try {
      switch (userType) {
        case UserType.senior:
          final senior = await createSeniorProfile(userId);
          return senior != null;
        case UserType.family:
          final family = await createFamilyProfile(userId);
          return family != null;
        case UserType.volunteer:
          final volunteer = await createVolunteerProfile(userId);
          return volunteer != null;
        default:
          return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error selecting role: $e');
      }
      return false;
    }
  }

  Future<void> initializeAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool('is_logged_in') ?? false;

      if (isLoggedIn) {
        final firebaseUser = _auth.currentUser;
        if (firebaseUser != null) {
          await _fetchUserData(firebaseUser);
          // In methods like signIn, register, createSeniorProfile, etc.
NotificationService().onUserLogin(_currentUser!.id); // Save OneSignal ID on init
        } else {
          await prefs.setBool('is_logged_in', false);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing auth: $e');
      }
    }
  }
}