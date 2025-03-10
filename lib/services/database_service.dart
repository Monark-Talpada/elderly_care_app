import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elderly_care_app/models/need_model.dart';
import 'package:elderly_care_app/models/family_model.dart';
import 'package:elderly_care_app/models/senior_model.dart';
import 'package:elderly_care_app/models/volunteer_model.dart';
import 'package:elderly_care_app/models/appointment_model.dart';
import 'package:firebase_auth/firebase_auth.dart' hide User;
import 'package:intl/intl.dart';
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
  
  // Get upcoming needs for notifications
// Get daily needs for notification
Stream<List<DailyNeed>> getDailyNeedsForNotification(String seniorId) {
  final DateTime today = DateTime.now();
  final DateTime startOfDay = DateTime(today.year, today.month, today.day);
  final DateTime endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);
  
  return _needsCollection
      .where('seniorId', isEqualTo: seniorId)
      .where('dueDate', isGreaterThanOrEqualTo: startOfDay)
      .where('dueDate', isLessThanOrEqualTo: endOfDay)
      .where('status', isNotEqualTo: 'completed')
      .orderBy('dueDate')
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => DailyNeed.fromFirestore(doc))
          .toList());
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
  String dateString,
  TimeSlot timeSlot,
  bool isBooked,
  String? bookedById,
) async {
  try {
    // Use the date from the timeSlot for consistency
    final formattedDate = DateFormat('yyyy-MM-dd').format(timeSlot.startTime);
    
    print('Attempting to update slot for date: $formattedDate');
    print('Looking for slot around: ${timeSlot.startTime.hour}:${timeSlot.startTime.minute} - ${timeSlot.endTime.hour}:${timeSlot.endTime.minute}');
    
    // Get current volunteer data
    DocumentSnapshot volunteerDoc = await _volunteersCollection.doc(volunteerId).get();
    if (!volunteerDoc.exists) {
      print('Volunteer document does not exist: $volunteerId');
      return false;
    }
    
    Map<String, dynamic> data = volunteerDoc.data() as Map<String, dynamic>;
    
    // Debug the availability structure
    if (data['availability'] == null) {
      print('No availability data for volunteer: $volunteerId');
      return false;
    }
    
    print('Available dates: ${(data['availability'] as Map).keys.join(', ')}');
    
    // Try all possible date formats the data might be stored under
    List<dynamic>? slots;
    
    // Try formatted date first
    slots = data['availability'][formattedDate];
    
    // If not found, try day of week
    if (slots == null) {
      final dayOfWeek = DateFormat('EEEE').format(timeSlot.startTime).toLowerCase();
      slots = data['availability'][dayOfWeek];
      print('Trying day of week: $dayOfWeek, found slots: ${slots != null}');
    }
    
    // If still not found, try original dateString
    if (slots == null && dateString != formattedDate) {
      slots = data['availability'][dateString];
      print('Trying original dateString: $dateString, found slots: ${slots != null}');
    }
    
    if (slots == null) {
      print('No slots found for any date format. Available dates/days: ${(data['availability'] as Map).keys.join(', ')}');
      return false;
    }
    
    print('Found ${slots.length} time slots for the day');
    
    // More flexible matching - Find closest matching slot
    bool foundSlot = false;
    int closestSlotIndex = -1;
    int smallestTimeDifference = 9999; // Large number of minutes
    
    for (int i = 0; i < slots.length; i++) {
      var slot = slots[i];
      
      print('Examining slot $i: ${slot.toString()}');
      
      // Convert slot times to DateTime for comparison
      DateTime slotStartTime;
      if (slot['startTime'] is Timestamp) {
        slotStartTime = (slot['startTime'] as Timestamp).toDate();
      } else if (slot['startTime'] is String) {
        slotStartTime = DateTime.parse(slot['startTime']);
      } else {
        // If it's an hour/minute structure, create a DateTime from it
        final Map<String, dynamic> startTimeMap = slot['startTime'];
        slotStartTime = DateTime(
          timeSlot.startTime.year,
          timeSlot.startTime.month,
          timeSlot.startTime.day,
          startTimeMap['hour'],
          startTimeMap['minute'],
        );
      }
      
      // Calculate time difference in minutes
      final startTimeDiff = (slotStartTime.hour * 60 + slotStartTime.minute) - 
                            (timeSlot.startTime.hour * 60 + timeSlot.startTime.minute);
      
      print('Time difference: $startTimeDiff minutes');
      
      if (startTimeDiff.abs() < smallestTimeDifference) {
        smallestTimeDifference = startTimeDiff.abs();
        closestSlotIndex = i;
      }
      
      // If an exact match (or very close match within 10 minutes) is found, use it immediately
      if (startTimeDiff.abs() <= 10) {
        foundSlot = true;
        slots[i]['isBooked'] = isBooked;
        slots[i]['bookedById'] = bookedById;
        break;
      }
    }
    
    // If no exact match was found but we have a closest slot, use that
    if (!foundSlot && closestSlotIndex >= 0 && smallestTimeDifference <= 60) {
      print('Using closest slot with time difference of $smallestTimeDifference minutes');
      slots[closestSlotIndex]['isBooked'] = isBooked;
      slots[closestSlotIndex]['bookedById'] = bookedById;
      foundSlot = true;
    }
    
    if (!foundSlot) {
      print('Could not find a suitable time slot. Closest was $smallestTimeDifference minutes away.');
      // DEBUG: Print all available slots for debugging
      for (int i = 0; i < slots.length; i++) {
        print('Available slot $i: ${slots[i]}');
      }
      return false;
    }
    
    // Determine which key to use for the update (formattedDate, day of week, or original)
    String keyToUse = formattedDate;
    if (!data['availability'].containsKey(formattedDate)) {
      final dayOfWeek = DateFormat('EEEE').format(timeSlot.startTime).toLowerCase();
      if (data['availability'].containsKey(dayOfWeek)) {
        keyToUse = dayOfWeek;
      } else if (data['availability'].containsKey(dateString)) {
        keyToUse = dateString;
      }
    }
    
    print('Updating availability using key: $keyToUse');
    
    // Update the volunteer document with the correct date key
    await _volunteersCollection.doc(volunteerId).update({
      'availability.$keyToUse': slots
    });
    
    return true;
  } catch (e) {
    print('Error updating volunteer time slot: $e');
    if (e is FirebaseException) {
      print('Firebase error code: ${e.code}, message: ${e.message}');
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
    // Format date as YYYY-MM-DD to match database structure
    final String formattedDate = DateFormat('yyyy-MM-dd').format(timeSlot.startTime);
    
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
        
        // First check if volunteer has availability for the requested date
        if (volunteer.availability.containsKey(formattedDate)) {
          // Check for overlapping time slots
          bool isAvailable = volunteer.availability[formattedDate]!.any((slot) {
            // Check if the slot's time range overlaps with requested time
            bool timeOverlaps = 
              slot.startTime.isBefore(timeSlot.endTime) && 
              slot.endTime.isAfter(timeSlot.startTime);
            
            // Check if the slot is not already booked
            bool notBooked = !slot.isBooked;
            
            return timeOverlaps && notBooked;
          });
              
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
  // Fix for the bookAppointment function
Future<String?> bookAppointment({
  required String seniorId,
  required String volunteerId,
  required DateTime appointmentDate,
  required String description,
}) async {
  try {
    // Create a proper end time (1 hour after start)
    final DateTime endTime = appointmentDate.add(const Duration(hours: 1));

    // Ensure consistent status format
    final status = AppointmentStatus.scheduled.name;

    DocumentReference docRef = await _appointmentsCollection.add({
      'seniorId': seniorId,
      'volunteerId': volunteerId,
      'startTime': Timestamp.fromDate(appointmentDate),
      'endTime': Timestamp.fromDate(endTime),
      'notes': description,
      'status': status,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  } catch (e) {
    if (kDebugMode) {
      print('Error booking appointment: $e');
      // Print more details about the error
      if (e is FirebaseException) {
        print('Firebase error code: ${e.code}, message: ${e.message}');
      }
    }
    return null;
  }
}

Future<bool> bookVolunteerWithAppointment({
  required String seniorId,
  required String volunteerId,
  required DateTime appointmentDate,
  required String description,
  required TimeSlot timeSlot,
  required String formattedDate,
}) async {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  
  try {
    bool success = false;
    String? appointmentId;
    
    await firestore.runTransaction((transaction) async {
      // 1. Create the appointment document
      final appointmentData = {
        'seniorId': seniorId,
        'volunteerId': volunteerId,
        'startTime': Timestamp.fromDate(appointmentDate),
        'endTime': Timestamp.fromDate(appointmentDate.add(const Duration(hours: 1))),
        'notes': description,
        'status': AppointmentStatus.scheduled.name,
        'createdAt': Timestamp.fromDate(DateTime.now()),
        'needId': null,
        'completedAt': null,
        'rating': null,
        'feedback': null,
      };
      
      DocumentReference appointmentRef = _appointmentsCollection.doc();
      transaction.set(appointmentRef, appointmentData);
      appointmentId = appointmentRef.id;
      
      // 2. Update the volunteer's time slot
      // Adjust this to match your actual data structure
      DocumentReference volunteerTimeSlotRef = firestore.collection('volunteers')
          .doc(volunteerId)
          .collection('availability')
          .doc(formattedDate);
      
      // Update the time slot as booked
      // This will need to be adjusted to your actual data structure
      transaction.update(volunteerTimeSlotRef, {
        'timeSlots': FieldValue.arrayRemove([timeSlot.toMap()]),
        'bookedTimeSlots': FieldValue.arrayUnion([
          {...timeSlot.toMap(), 'isBooked': true, 'bookedById': seniorId}
        ]),
      });
    });
    
    return appointmentId != null;
  } catch (e) {
    print('Transaction error: $e');
    if (e is FirebaseException) {
      print('Firebase error code: ${e.code}, message: ${e.message}');
    }
    return false;
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