import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elderly_care_app/models/family_model.dart';
import 'package:elderly_care_app/models/senior_model.dart';
import 'package:elderly_care_app/models/volunteer_model.dart';
import 'package:elderly_care_app/models/senior_model.dart';
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
          _currentUser = SeniorCitizen.fromFirestore(userDoc);
        } else if (userType == 'family') {
          _currentUser = FamilyMember.fromFirestore(userDoc);
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
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
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
      if (kDebugMode) {
        print('Registration error: $e');
      }
      return null;
    }
  }
  
  Future<void> signOut() async {
    await _auth.signOut();
    _currentUser = null;
    notifyListeners();
  }

  Future<SeniorCitizen?> createSeniorProfile(String userId) async {
  try {
    // Update the user type in Firestore
    await _firestore.collection('users').doc(userId).update({
      'userType': 'senior',
    });
    
    // Fetch the updated user data
    DocumentSnapshot userDoc = await _firestore
        .collection('users')
        .doc(userId)
        .get();
    
    if (userDoc.exists) {
      final senior = SeniorCitizen.fromFirestore(userDoc);
      _currentUser = senior;
      notifyListeners();
      return senior;
    }
    
    return null;
  } catch (e) {
    if (kDebugMode) {
      print('Error creating senior profile: $e');
    }
    return null;
  }
}

Future<FamilyMember?> createFamilyProfile(String userId) async {
  try {
    // Update the user type in Firestore
    await _firestore.collection('users').doc(userId).update({
      'userType': 'family',
      'connectedSeniorIds': [],
    });
    
    // Fetch the updated user data
    DocumentSnapshot userDoc = await _firestore
        .collection('users')
        .doc(userId)
        .get();
    
    if (userDoc.exists) {
      final family = FamilyMember.fromFirestore(userDoc);
      _currentUser = family;
      notifyListeners();
      return family;
    }
    
    return null;
  } catch (e) {
    if (kDebugMode) {
      print('Error creating family profile: $e');
    }
    return null;
  }
}

Future<Volunteer?> createVolunteerProfile(String userId) async {
  try {
    // Update the user type in Firestore
    await _firestore.collection('users').doc(userId).update({
      'userType': 'volunteer',
      // Add any volunteer-specific fields here
    });
    
    // Fetch the updated user data
    DocumentSnapshot userDoc = await _firestore
        .collection('users')
        .doc(userId)
        .get();
    
    if (userDoc.exists) {
      final volunteer = Volunteer.fromFirestore(userDoc);
      _currentUser = volunteer;
      notifyListeners();
      return volunteer;
    }
    
    return null;
  } catch (e) {
    if (kDebugMode) {
      print('Error creating volunteer profile: $e');
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
      
      // Update the family member's connected seniors
      final FamilyMember family = _currentUser as FamilyMember;
      if (!family.connectedSeniorIds.contains(seniorId)) {
        await _firestore.collection('users').doc(family.id).update({
          'connectedSeniorIds': FieldValue.arrayUnion([seniorId]),
        });
      }
      
      // Update the senior's connected family members
      await _firestore.collection('users').doc(seniorId).update({
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
  
}