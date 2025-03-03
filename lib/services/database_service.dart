import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elderly_care_app/models/need_model.dart';
import 'package:elderly_care_app/models/family_model.dart';
import 'package:elderly_care_app/models/senior_model.dart';
import 'package:elderly_care_app/models/volunteer_model.dart';
import 'package:elderly_care_app/models/appointment_model.dart';
import 'package:firebase_auth/firebase_auth.dart' hide User;
import 'package:flutter/foundation.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String? userId;
  
  DatabaseService({this.userId});
  
  // Collection references
  CollectionReference get _usersCollection => _firestore.collection('users');
  CollectionReference get _needsCollection => _firestore.collection('needs');
  CollectionReference get _appointmentsCollection => 
      _firestore.collection('appointments');
  
  // Get user-specific needs
  Future<List<DailyNeed>> getSeniorNeeds(String seniorId) async {
  try {
    final snapshot = await _needsCollection
        .where('seniorId', isEqualTo: seniorId)
        .orderBy('dueDate')
        .get();
        
    return snapshot.docs
        .map((doc) => DailyNeed.fromFirestore(doc))
        .toList();
  } catch (e) {
    if (kDebugMode) {
      print('Error getting senior needs: $e');
    }
    return [];
  }
}
  
  // Get needs assigned to a specific user
  Stream<List<DailyNeed>> getAssignedNeeds(String userId) {
    return _needsCollection
        .where('assignedToId', isEqualTo: userId)
        .orderBy('dueDate')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DailyNeed.fromFirestore(doc))
            .toList());
  }
  
  // Add a new need
  Future<String?> addNeed(DailyNeed need) async {
    try {
      DocumentReference docRef = await _needsCollection.add(need.toMap());
      return docRef.id;
    } catch (e) {
      if (kDebugMode) {
        print('Error adding need: $e');
      }
      return null;
    }
  }
  
  // Update a need
  Future<bool> updateNeed(DailyNeed need) async {
    try {
      await _needsCollection.doc(need.id).update(need.toMap());
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error updating need: $e');
      }
      return false;
    }
  }
  
  // Delete a need
  Future<bool> deleteNeed(String needId) async {
    try {
      await _needsCollection.doc(needId).delete();
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting need: $e');
      }
      return false;
    }
  }
  
  // Update user location
  Future<bool> updateUserLocation(String userId, GeoPoint location) async {
    try {
      await _usersCollection.doc(userId).update({
        'lastKnownLocation': location,
        'lastLocationUpdate': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error updating location: $e');
      }
      return false;
    }
  }
  
  // Toggle emergency mode
  Future<bool> toggleEmergencyMode(String seniorId, bool isActive) async {
    try {
      await _usersCollection.doc(seniorId).update({
        'emergencyModeActive': isActive,
      });
      
      if (isActive) {
        // Get all connected family members
        DocumentSnapshot seniorDoc = await _usersCollection.doc(seniorId).get();
        List<String> familyIds = List<String>.from(
            (seniorDoc.data() as Map<String, dynamic>)['connectedFamilyIds'] ?? []);
            
        // TODO: Send notifications to family members
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error toggling emergency mode: $e');
      }
      return false;
    }
  }
  
  // Get all connected seniors for a family member
  // Modify getConnectedSeniors to return List<SeniorCitizen> instead of List<DocumentSnapshot>
Future<List<SeniorCitizen>> getConnectedSeniors(String familyId) async {
  try {
    DocumentSnapshot familyDoc = await _usersCollection.doc(familyId).get();
    List<String> seniorIds = List<String>.from(
        (familyDoc.data() as Map<String, dynamic>)['connectedSeniorIds'] ?? []);
        
    if (seniorIds.isEmpty) {
      return [];
    }
    
    List<SeniorCitizen> seniors = [];
    for (String id in seniorIds) {
      DocumentSnapshot seniorDoc = await _usersCollection.doc(id).get();
      if (seniorDoc.exists) {
        seniors.add(SeniorCitizen.fromFirestore(seniorDoc));
      }
    }
    
    return seniors;
  } catch (e) {
    if (kDebugMode) {
      print('Error getting connected seniors: $e');
    }
    return [];
  }
}

  
  // Get all connected family members for a senior
  Future<List<DocumentSnapshot>> getConnectedFamilyMembers(String seniorId) async {
    try {
      DocumentSnapshot seniorDoc = await _usersCollection.doc(seniorId).get();
      List<String> familyIds = List<String>.from(
          (seniorDoc.data() as Map<String, dynamic>)['connectedFamilyIds'] ?? []);
          
      if (familyIds.isEmpty) {
        return [];
      }
      
      List<DocumentSnapshot> familyMembers = [];
      for (String id in familyIds) {
        DocumentSnapshot familyDoc = await _usersCollection.doc(id).get();
        if (familyDoc.exists) {
          familyMembers.add(familyDoc);
        }
      }
      
      return familyMembers;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting connected family members: $e');
      }
      return [];
    }
  }
  
  // Volunteer methods
  Future<Volunteer?> getVolunteer(String volunteerId) async {
  try {
    DocumentSnapshot doc = await _usersCollection.doc(volunteerId).get();
    if (!doc.exists) {
      return null;
    }
    return Volunteer.fromFirestore(doc);
  } catch (e) {
    if (kDebugMode) {
      print('Error getting volunteer: $e');
    }
    return null;
  }
}
  
Future<bool> updateVolunteerTimeSlot(
  String volunteerId,
  String day,
  TimeSlot timeSlot,
  bool isBooked,
  String? bookedById,
) async {
  try {
    // First get the volunteer to update their availability map
    Volunteer? volunteer = await getVolunteer(volunteerId);
    if (volunteer == null) {
      return false;
    }
    
    // Find the time slot in the volunteer's availability
    if (!volunteer.availability.containsKey(day)) {
      return false;
    }
    
    List<TimeSlot> daySlots = volunteer.availability[day]!;
    int slotIndex = daySlots.indexWhere((slot) => 
      slot.startTime == timeSlot.startTime && slot.endTime == timeSlot.endTime);
    
    if (slotIndex == -1) {
      return false;
    }
    
    // Update the time slot
    TimeSlot updatedSlot = daySlots[slotIndex].copyWith(
      isBooked: isBooked,
      bookedById: bookedById,
    );
    
    // Replace the slot in the list
    List<TimeSlot> updatedSlots = List.from(daySlots);
    updatedSlots[slotIndex] = updatedSlot;
    
    // Create a new availability map
    Map<String, List<TimeSlot>> updatedAvailability = Map.from(volunteer.availability);
    updatedAvailability[day] = updatedSlots;
    
    // Update the volunteer with the new availability
    Volunteer updatedVolunteer = volunteer.copyWith(
      availability: updatedAvailability,
    );
    
    // Convert the updated availability to the format expected by Firestore
    Map<String, List<Map<String, dynamic>>> firestoreAvailability = {};
    updatedAvailability.forEach((day, slots) {
      firestoreAvailability[day] = slots.map((slot) => slot.toJson()).toList();
    });
    
    // Update only the availability field in Firestore
    await _usersCollection.doc(volunteerId).update({
      'availability': firestoreAvailability,
    });
    
    return true;
  } catch (e) {
    if (kDebugMode) {
      print('Error updating volunteer time slot: $e');
    }
    return false;
  }
}

  // Update volunteer availability
Future<void> updateVolunteerAvailability(String volunteerId, Map<String, List<TimeSlot>> availability) async {
  try {
    // Convert availability to the format Firestore can store
    Map<String, List<Map<String, dynamic>>> availabilityMap = {};
    availability.forEach((day, slots) {
      availabilityMap[day] = slots.map((slot) => slot.toJson()).toList();
    });
    
    await FirebaseFirestore.instance
        .collection('users')
        .doc(volunteerId)
        .update({'availability': availabilityMap});
  } catch (e) {
    throw e;
  }
}
  // Get available volunteers
  Future<List<DocumentSnapshot>> getAvailableVolunteers(
    String day, 
    String timeSlot
  ) async {
    try {
      final QuerySnapshot volunteerQuery = await _usersCollection
          .where('userType', isEqualTo: 'volunteer')
          .where('availability.$day', arrayContains: timeSlot)
          .get();
          
      return volunteerQuery.docs;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting available volunteers: $e');
      }
      return [];
    }
  }
  
  // Book an appointment with a volunteer
  Future<String?> bookAppointment({
    required String seniorId,
    required String volunteerId,
    required DateTime appointmentDate,
    required String description,
  }) async {
    try {
      DocumentReference docRef = await _appointmentsCollection.add({
        'seniorId': seniorId,
        'volunteerId': volunteerId,
        'appointmentDate': Timestamp.fromDate(appointmentDate),
        'description': description,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      // TODO: Send notification to volunteer
      
      return docRef.id;
    } catch (e) {
      if (kDebugMode) {
        print('Error booking appointment: $e');
      }
      return null;
    }
  }

  // Add this to database_service.dart
Future<SeniorCitizen?> getSeniorById(String seniorId) async {
  try {
    DocumentSnapshot doc = await _usersCollection.doc(seniorId).get();
    if (!doc.exists) {
      return null;
    }
    return SeniorCitizen.fromFirestore(doc);
  } catch (e) {
    if (kDebugMode) {
      print('Error getting senior by ID: $e');
    }
    return null;
  }
}

  Future<SeniorCitizen?> getCurrentSenior() async {
  try {
    if (userId == null) {
      return null;
    }
    DocumentSnapshot doc = await _usersCollection.doc(userId).get();
    if (!doc.exists) {
      return null;
    }
    return SeniorCitizen.fromFirestore(doc);
  } catch (e) {
    if (kDebugMode) {
      print('Error getting current senior: $e');
    }
    return null;
  }
}
  
  // Get appointments for a senior
  Stream<QuerySnapshot> getSeniorAppointments(String seniorId) {
    return _appointmentsCollection
        .where('seniorId', isEqualTo: seniorId)
        .orderBy('appointmentDate')
        .snapshots();
  }
  
  // Get appointments for a volunteer
 Future<List<Appointment>> getVolunteerAppointments(String volunteerId) async {
  try {
    QuerySnapshot snapshot = await _appointmentsCollection
        .where('volunteerId', isEqualTo: volunteerId)
        .orderBy('startTime')
        .get();
        
    return snapshot.docs.map((doc) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      return Appointment(
        id: doc.id,
        seniorId: data['seniorId'],
        volunteerId: data['volunteerId'],
        needId: data['needId'],
        startTime: (data['startTime'] as Timestamp).toDate(),
        endTime: (data['endTime'] as Timestamp).toDate(),
        status: _stringToAppointmentStatus(data['status']),
        notes: data['notes'],
        createdAt: (data['createdAt'] as Timestamp).toDate(),
        completedAt: data['completedAt'] != null 
            ? (data['completedAt'] as Timestamp).toDate() 
            : null,
        rating: data['rating'],
        feedback: data['feedback'],
      );
    }).toList();
  } catch (e) {
    if (kDebugMode) {
      print('Error getting volunteer appointments: $e');
    }
    return [];
  }
}

// Helper method to convert string to enum
AppointmentStatus _stringToAppointmentStatus(String status) {
  switch (status) {
    case 'scheduled':
      return AppointmentStatus.scheduled;
    case 'inProgress':
      return AppointmentStatus.inProgress;
    case 'completed':
      return AppointmentStatus.completed;
    case 'cancelled':
      return AppointmentStatus.cancelled;
    default:
      return AppointmentStatus.scheduled;
  }
}
  
  // Update appointment status
 Future<bool> updateAppointmentStatus(
  String appointmentId, 
  AppointmentStatus newStatus
) async {
  try {
    await _appointmentsCollection.doc(appointmentId).update({
      'status': newStatus.toString().split('.').last,
    });
    return true;
  } catch (e) {
    if (kDebugMode) {
      print('Error updating appointment status: $e');
    }
    return false;
  }
}

  
  // [MISSING METHOD 1] Get senior by email
  Future<SeniorCitizen?> getSeniorByEmail(String email) async {
    try {
      final querySnapshot = await _usersCollection
          .where('email', isEqualTo: email)
          .where('userType', isEqualTo: 'senior')
          .limit(1)
          .get();
          
      if (querySnapshot.docs.isEmpty) {
        return null;
      }
      
      final doc = querySnapshot.docs.first;
      return SeniorCitizen.fromFirestore(doc);
    } catch (e) {
      if (kDebugMode) {
        print('Error getting senior by email: $e');
      }
      return null;
    }
  }
  
  // [MISSING METHOD 2] Update family member
  Future<bool> updateFamilyMember(FamilyMember familyMember) async {
    try {
      await _usersCollection.doc(familyMember.id).update(familyMember.toMap());
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error updating family member: $e');
      }
      return false;
    }
  }
  
  // [MISSING METHOD 3] Update senior
  Future<bool> updateSenior(SeniorCitizen senior) async {
    try {
      await _usersCollection.doc(senior.id).update(senior.toMap());
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error updating senior: $e');
      }
      return false;
    }
  }

  Future<String?> createAppointment(Appointment appointment) async {
  try {
    final Map<String, dynamic> appointmentData = {
      'seniorId': appointment.seniorId,
      'volunteerId': appointment.volunteerId,
      'needId': appointment.needId,
      'startTime': Timestamp.fromDate(appointment.startTime),
      'endTime': Timestamp.fromDate(appointment.endTime),
      'status': appointment.status.toString().split('.').last,
      'notes': appointment.notes,
      'createdAt': Timestamp.fromDate(appointment.createdAt),
      'completedAt': appointment.completedAt != null ? 
          Timestamp.fromDate(appointment.completedAt!) : null,
      'rating': appointment.rating,
      'feedback': appointment.feedback,
    };
    
    DocumentReference docRef = await _appointmentsCollection.add(appointmentData);
    return docRef.id;
  } catch (e) {
    if (kDebugMode) {
      print('Error creating appointment: $e');
    }
    return null;
  }
}

Future<bool> completeAppointment(
  String appointmentId, 
  DateTime completionTime
) async {
  try {
    await _appointmentsCollection.doc(appointmentId).update({
      'completedAt': Timestamp.fromDate(completionTime),
      'status': 'completed',
    });
    return true;
  } catch (e) {
    if (kDebugMode) {
      print('Error completing appointment: $e');
    }
    return false;
  }
}

Future<bool> updateVolunteerHours(
  String volunteerId,
  int totalHours
) async {
  try {
    await _usersCollection.doc(volunteerId).update({
      'totalHoursVolunteered': totalHours,
    });
    return true;
  } catch (e) {
    if (kDebugMode) {
      print('Error updating volunteer hours: $e');
    }
    return false;
  }
}

}