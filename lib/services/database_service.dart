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
  CollectionReference get _appointmentsCollection => _firestore.collection('appointments');
  CollectionReference get _seniorsCollection => _firestore.collection('seniors');
  CollectionReference get _familyCollection => _firestore.collection('family_member');
  CollectionReference get _volunteersCollection => _firestore.collection('volunteers');
  
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
      // Update in both users and seniors collections
      await _usersCollection.doc(userId).update({
        'lastKnownLocation': location,
      });
      
      await _seniorsCollection.doc(userId).update({
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
      await _seniorsCollection.doc(seniorId).update({
        'emergencyModeActive': isActive,
      });
      
      if (isActive) {
        // Get all connected family members
        DocumentSnapshot seniorDoc = await _seniorsCollection.doc(seniorId).get();
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
  Future<List<SeniorCitizen>> getConnectedSeniors(String familyId) async {
    try {
      DocumentSnapshot familyDoc = await _familyCollection.doc(familyId).get();

      if (!familyDoc.exists || familyDoc.data() == null) {
      return [];
    }

      List<String> seniorIds = List<String>.from(
          (familyDoc.data() as Map<String, dynamic>)['connectedSeniorIds'] ?? []);
          
      if (seniorIds.isEmpty) {
        return [];
      }
      
      List<SeniorCitizen> seniors = [];
      for (String id in seniorIds) {
        // Get data from both users and seniors collections
        DocumentSnapshot userDoc = await _usersCollection.doc(id).get();
        DocumentSnapshot seniorDoc = await _seniorsCollection.doc(id).get();
        
        if (userDoc.exists && seniorDoc.exists) {
          Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
          Map<String, dynamic> seniorData = seniorDoc.data() as Map<String, dynamic>;
          Map<String, dynamic> mergedData = {...userData, ...seniorData};
          
          seniors.add(SeniorCitizen.fromMap(mergedData, id));
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
  Future<List<FamilyMember>> getConnectedFamilyMembers(String seniorId) async {
    try {
      DocumentSnapshot seniorDoc = await _seniorsCollection.doc(seniorId).get();
      List<String> familyIds = List<String>.from(
          (seniorDoc.data() as Map<String, dynamic>)['connectedFamilyIds'] ?? []);
          
      if (familyIds.isEmpty) {
        return [];
      }
      
      List<FamilyMember> familyMembers = [];
      for (String id in familyIds) {
        // Get data from both users and family_member collections
        DocumentSnapshot userDoc = await _usersCollection.doc(id).get();
        DocumentSnapshot familyDoc = await _familyCollection.doc(id).get();
        
        if (userDoc.exists && familyDoc.exists) {
          Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
          Map<String, dynamic> familyData = familyDoc.data() as Map<String, dynamic>;
          Map<String, dynamic> mergedData = {...userData, ...familyData};
          
          familyMembers.add(FamilyMember.fromMap(mergedData, id));
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
      // Get data from both users and volunteers collections
      DocumentSnapshot userDoc = await _usersCollection.doc(volunteerId).get();
      DocumentSnapshot volunteerDoc = await _volunteersCollection.doc(volunteerId).get();
      
      if (!userDoc.exists || !volunteerDoc.exists) {
        return null;
      }
      
      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
      Map<String, dynamic> volunteerData = volunteerDoc.data() as Map<String, dynamic>;
      Map<String, dynamic> mergedData = {...userData, ...volunteerData};
      
      return Volunteer.fromMap(mergedData, volunteerId);
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
      
      // Convert the updated availability to the format expected by Firestore
      Map<String, List<Map<String, dynamic>>> firestoreAvailability = {};
      updatedAvailability.forEach((day, slots) {
        firestoreAvailability[day] = slots.map((slot) => slot.toMap()).toList();
      });
      
      // Update only the availability field in Firestore
      await _volunteersCollection.doc(volunteerId).update({
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
        availabilityMap[day] = slots.map((slot) => slot.toMap()).toList();
      });
      
      await _volunteersCollection.doc(volunteerId).update({'availability': availabilityMap});
    } catch (e) {
      throw e;
    }
  }
  
  // Get available volunteers
  Future<List<Volunteer>> getAvailableVolunteers(String day, TimeSlot timeSlot) async {
    try {
      // Need to query both users and volunteers collections
      final QuerySnapshot volunteersQuery = await _volunteersCollection.get();
      
      List<Volunteer> availableVolunteers = [];
      
      for (var doc in volunteersQuery.docs) {
        String volunteerId = doc.id;
        DocumentSnapshot userDoc = await _usersCollection.doc(volunteerId).get();
        
        if (userDoc.exists) {
          Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
          Map<String, dynamic> volunteerData = doc.data() as Map<String, dynamic>;
          Map<String, dynamic> mergedData = {...userData, ...volunteerData};
          
          Volunteer volunteer = Volunteer.fromMap(mergedData, volunteerId);
          
          // Check if volunteer is available at the requested time
          if (volunteer.availability.containsKey(day)) {
            bool isAvailable = volunteer.availability[day]!.any((slot) => 
              slot.startTime == timeSlot.startTime && 
              slot.endTime == timeSlot.endTime && 
              !slot.isBooked);
              
            if (isAvailable) {
              availableVolunteers.add(volunteer);
            }
          }
        }
      }
      
      return availableVolunteers;
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

  Future<SeniorCitizen?> getSeniorById(String seniorId) async {
    try {
      // Get data from both users and seniors collections
      DocumentSnapshot userDoc = await _usersCollection.doc(seniorId).get();
      DocumentSnapshot seniorDoc = await _seniorsCollection.doc(seniorId).get();
      
      if (!userDoc.exists || !seniorDoc.exists) {
        return null;
      }
      
      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
      Map<String, dynamic> seniorData = seniorDoc.data() as Map<String, dynamic>;
      Map<String, dynamic> mergedData = {...userData, ...seniorData};
      
      return SeniorCitizen.fromMap(mergedData, seniorId);
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
      
      return await getSeniorById(userId!);
    } catch (e) {
      if (kDebugMode) {
        print('Error getting current senior: $e');
      }
      return null;
    }
  }
  
  // Get appointments for a senior
  Stream<List<Appointment>> getSeniorAppointments(String seniorId) {
    return _appointmentsCollection
        .where('seniorId', isEqualTo: seniorId)
        .orderBy('appointmentDate')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
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
        }).toList());
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
  
  // Get senior by email
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
      
      String seniorId = querySnapshot.docs.first.id;
      return await getSeniorById(seniorId);
    } catch (e) {
      if (kDebugMode) {
        print('Error getting senior by email: $e');
      }
      return null;
    }
  }
  
  // Update family member
  Future<bool> updateFamilyMember(FamilyMember familyMember) async {
    try {
      DocumentSnapshot docSnapshot = await _familyCollection.doc(familyMember.id).get();

      if (!docSnapshot.exists) {
      // Document doesn't exist, create it
      await _familyCollection.doc(familyMember.id).set(familyMember.toMap());
    } else {
      // Document exists, update it
      await _familyCollection.doc(familyMember.id).update(familyMember.toMap());
    }
    
    return true;
  }catch (e) {
      if (kDebugMode) {
        print('Error updating family member: $e');
      }
      return false;
    }
  }
  
  // Update senior
  Future<bool> updateSenior(SeniorCitizen senior) async {
    try {
      // Update in both users and seniors collections
      Map<String, dynamic> seniorData = senior.toMap();
      
      // Split the data between the two collections if needed
      // This is a simplified approach, you may need to customize this based on your schema
      await _usersCollection.doc(senior.id).update(seniorData);
      await _seniorsCollection.doc(senior.id).update(seniorData);
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error updating senior: $e');
      }
      return false;
    }
  }
  
  // Create a new appointment
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
  
  // Complete an appointment
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
  
  // Update volunteer hours
  Future<bool> updateVolunteerHours(
    String volunteerId,
    int totalHours
  ) async {
    try {
      await _volunteersCollection.doc(volunteerId).update({
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