import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elderly_care_app/models/family_model.dart';
import 'package:elderly_care_app/models/senior_model.dart';
import 'package:elderly_care_app/models/volunteer_model.dart';
import 'package:elderly_care_app/models/user_model.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';

class AuthService extends ChangeNotifier {
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  User? _currentUser;
  
  User? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  
  AuthService() {
    _auth.authStateChanges().listen(_onAuthStateChanged);
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
        
        if (userType == 'senior') {
          // Get additional data from seniors collection if needed
          DocumentSnapshot seniorDoc = await _firestore
              .collection('seniors')
              .doc(firebaseUser.uid)
              .get();
              
          if (seniorDoc.exists) {
            // Merge data from both documents if needed
            Map<String, dynamic> seniorData = seniorDoc.data() as Map<String, dynamic>;
            Map<String, dynamic> mergedData = {...data, ...seniorData};
            _currentUser = SeniorCitizen.fromMap(mergedData, userDoc.id);
          } else {
            _currentUser = SeniorCitizen.fromFirestore(userDoc);
          }
        } else if (userType == 'family') {
          // Get additional data from family_member collection if needed
          DocumentSnapshot familyDoc = await _firestore
              .collection('family_member')
              .doc(firebaseUser.uid)
              .get();
              
          if (familyDoc.exists) {
            // Merge data from both documents if needed
            Map<String, dynamic> familyData = familyDoc.data() as Map<String, dynamic>;
            Map<String, dynamic> mergedData = {...data, ...familyData};
            _currentUser = FamilyMember.fromMap(mergedData, userDoc.id);
          } else {
            _currentUser = FamilyMember.fromFirestore(userDoc);
          }
        } else if (userType == 'volunteer') {
          // Get additional data from volunteers collection if needed
          DocumentSnapshot volunteerDoc = await _firestore
              .collection('volunteers')
              .doc(firebaseUser.uid)
              .get();
              
          if (volunteerDoc.exists) {
            // Merge data from both documents if needed
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
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching user data: $e');
      }
      _currentUser = null;
      notifyListeners();
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
        // Get additional data from seniors collection if needed
        DocumentSnapshot seniorDoc = await _firestore
            .collection('seniors')
            .doc(firebaseUser.uid)
            .get();
            
        if (seniorDoc.exists) {
          // Merge data from both documents if needed
          Map<String, dynamic> seniorData = seniorDoc.data() as Map<String, dynamic>;
          Map<String, dynamic> mergedData = {...data, ...seniorData};
          _currentUser = SeniorCitizen.fromMap(mergedData, userDoc.id);
        } else {
          _currentUser = SeniorCitizen.fromFirestore(userDoc);
        }
      } else if (userType == 'family') {
        // Get additional data from family_member collection if needed
        DocumentSnapshot familyDoc = await _firestore
            .collection('family_member')
            .doc(firebaseUser.uid)
            .get();
            
        if (familyDoc.exists) {
          // Merge data from both documents if needed
          Map<String, dynamic> familyData = familyDoc.data() as Map<String, dynamic>;
          Map<String, dynamic> mergedData = {...data, ...familyData};
          _currentUser = FamilyMember.fromMap(mergedData, userDoc.id);
        } else {
          _currentUser = FamilyMember.fromFirestore(userDoc);
        }
      } else if (userType == 'volunteer') {
        // Get additional data from volunteers collection if needed
        DocumentSnapshot volunteerDoc = await _firestore
            .collection('volunteers')
            .doc(firebaseUser.uid)
            .get();
            
        if (volunteerDoc.exists) {
          // Merge data from both documents if needed
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
  } catch (e) {
    if (kDebugMode) {
      print('Error fetching user data: $e');
    }
    _currentUser = null;
    notifyListeners();
  }
}
  
  Future<User?> signIn(String email, String password) async {
  try {
    // Clear current user state first
    _currentUser = null;
    
    // Sign in with Firebase Auth
    final userCredential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    
    // Get the Firebase user
    final firebaseUser = userCredential.user;
    if (firebaseUser == null) {
      return null;
    }
    
    // Manually fetch user data rather than waiting for the listener
    await _fetchUserData(firebaseUser);
    
    // Return the now-populated _currentUser
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
        // Create the user document
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
        
        // Update the current user
        _currentUser = userData;
        notifyListeners();
        
        return userData;
      }
      
      return null;
    } catch (e) {
      if (e is firebase_auth.FirebaseAuthException && e.code == 'email-already-in-use') {
      // Display user-friendly message
      if (kDebugMode) {
        print('Email already in use. Please use a different email or sign in.');
      }
    }else{
      if (kDebugMode) {
        print('Registration error: $e');
      }
      return null;
    }
    }
  }
  
  Future<void> signOut() async {
    await _auth.signOut();
    _currentUser = null;
    notifyListeners();
  }

  Future<SeniorCitizen?> createSeniorProfile(String userId) async {
    try {
      // Update the user type in users collection
      await _firestore.collection('users').doc(userId).update({
        'userType': 'senior',
      });
      
      // Create entry in seniors collection
      await _firestore.collection('seniors').doc(userId).set({
        'userId': userId,
        'connectedFamilyIds': [],
        'emergencyModeActive': false,
        'lastLocationUpdate': FieldValue.serverTimestamp(),
      });
      
      // Fetch the updated user data
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
      // Update the user type in users collection
      await _firestore.collection('users').doc(userId).update({
        'userType': 'family',
      });
      
      // Create entry in family_member collection
      await _firestore.collection('family_member').doc(userId).set({
        'userId': userId,
        'connectedSeniorIds': [],
      });
      
      // Fetch the updated user data
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
        print('Error creating senior profile: $e');
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
      // Create a basic user document if it doesn't exist
      await _firestore.collection('users').doc(userId).set({
        'userType': 'volunteer',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
      
      // Update the user type in users collection
      await _firestore.collection('users').doc(userId).update({
        'userType': 'volunteer',
      });
      
      // Create entry in volunteers collection
      await _firestore.collection('volunteers').doc(userId).set({
        'userId': userId,
        'availability': {},
        'totalHoursVolunteered': 0,
      });
      
      // Fetch the updated user data
    
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
        print('Error creating senior profile: $e');
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
      // Find the senior with the provided email
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
      
      // Update the family member's connected seniors in family_member collection
      final FamilyMember family = _currentUser as FamilyMember;
      if (!family.connectedSeniorIds.contains(seniorId)) {
        await _firestore.collection('family_member').doc(family.id).update({
          'connectedSeniorIds': FieldValue.arrayUnion([seniorId]),
        });
      }
      
      // Update the senior's connected family members in seniors collection
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
}