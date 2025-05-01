import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elderly_care_app/models/need_model.dart';
import 'package:elderly_care_app/models/family_model.dart';
import 'package:elderly_care_app/models/senior_model.dart';
import 'package:elderly_care_app/models/volunteer_model.dart';
import 'package:elderly_care_app/models/appointment_model.dart';
import 'package:elderly_care_app/models/review_model.dart';
import 'package:elderly_care_app/services/notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart' hide User;
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';

class DatabaseService extends ChangeNotifier {
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


    Stream<List<DailyNeed>> streamSeniorNeeds(String seniorId) {
    return _needsCollection
        .where('seniorId', isEqualTo: seniorId)
        .orderBy('dueDate')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DailyNeed.fromFirestore(doc))
            .toList());
  }
  
  // Get user-specific needs
    // Get needs for a senior (one-time fetch)
  // Get needs for a senior (one-time fetch)
Future<List<DailyNeed>> getSeniorNeeds(String seniorId) async {
  try {
    // Try the indexed query first
    try {
      final snapshot = await _needsCollection
          .where('seniorId', isEqualTo: seniorId)
          .orderBy('dueDate')
          .get();
      
      if (kDebugMode) {
        print('Fetched ${snapshot.docs.length} needs for senior $seniorId');
      }
          
      return snapshot.docs
          .map((doc) => DailyNeed.fromFirestore(doc))
          .toList();
    } catch (e) {
      // If it fails due to missing index, fallback to a non-ordered query
      if (e.toString().contains('requires an index')) {
        if (kDebugMode) {
          print('Index error detected, falling back to unordered query');
        }
        
        // Get the data without ordering
        final snapshot = await _needsCollection
            .where('seniorId', isEqualTo: seniorId)
            .get();
            
        // Process and sort the data in memory
        final needs = snapshot.docs
            .map((doc) => DailyNeed.fromFirestore(doc))
            .toList();
            
        // Sort in memory
        needs.sort((a, b) => a.dueDate.compareTo(b.dueDate));
        
        return needs;
      } else {
        // Re-throw if it's a different error
        rethrow;
      }
    }
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
  
  Future<String?> addNeed(DailyNeed need) async {
  try {
    final needMap = need.toMap();
    if (kDebugMode) {
      print('Adding need with data: $needMap');
    }
    DocumentReference docRef = await _needsCollection.add(needMap);
    String needId = docRef.id;

    // Fetch connected family members
    List<FamilyMember> familyMembers = await getConnectedFamilyMembers(need.seniorId);

    // Send notification to each family member
    for (var family in familyMembers) {
      if (family.notificationsEnabled && (family.notificationPreferences['newNeed'] ?? true)) {
        await NotificationService().sendNotification(
          userId: family.id,
          title: 'New Need Created',
          message: '${need.title} has been created for the senior.',
          additionalData: {
            'needId': needId,
            'seniorId': need.seniorId,
            'action': 'view_need',
          },
        );
      }
    }

    return needId;
  } catch (e) {
    if (kDebugMode) {
      print('Error adding need: $e');
    }
    return null;
  }
}
  
  Future<bool> updateNeed(DailyNeed need) async {
    try {
      final needMap = need.toMap();
      if (kDebugMode) {
        print('Updating need with data: $needMap');
      }
      await _needsCollection.doc(need.id).update(needMap);

      // Fetch the original need to compare changes
      final originalNeedSnapshot = await _needsCollection.doc(need.id).get();
      final originalNeed = DailyNeed.fromFirestore(originalNeedSnapshot);

      // Fetch connected family members (for update, complete, or other notifications)
      List<FamilyMember> familyMembers = await getConnectedFamilyMembers(need.seniorId);

      // Determine notification type
      String title = '';
      String message = '';
      String action = '';

      if (need.status != originalNeed.status) {
        if (need.status == NeedStatus.inProgress && need.assignedToId != null) {
          // Accept notification: Send only to the senior
          title = 'Need Accepted';
          message = '${need.title} has been accepted by a family member or volunteer.';
          action = 'view_accepted_need';

          final senior = await getSeniorById(need.seniorId);
          if (senior != null) {
            await NotificationService().sendNotification(
              userId: senior.id,
              title: title,
              message: message,
              additionalData: {
                'needId': need.id,
                'seniorId': need.seniorId,
                'action': action,
              },
            );
          }
        } else if (need.status == NeedStatus.completed) {
          // Complete notification: Send to family members and senior
          title = 'Need Completed';
          message = '${need.title} has been marked as completed.';
          action = 'view_completed_need';

          // Send to family members
          for (var family in familyMembers) {
            if (family.notificationsEnabled && (family.notificationPreferences[action] ?? true)) {
              await NotificationService().sendNotification(
                userId: family.id,
                title: title,
                message: message,
                additionalData: {
                  'needId': need.id,
                  'seniorId': need.seniorId,
                  'action': action,
                },
              );
            }
          }

          // Send to senior
          final senior = await getSeniorById(need.seniorId);
          if (senior != null) {
            await NotificationService().sendNotification(
              userId: senior.id,
              title: title,
              message: message,
              additionalData: {
                'needId': need.id,
                'seniorId': need.seniorId,
                'action': action,
              },
            );
          }
        }
      } else {
        // General update: Send to family members only
        title = 'Need Updated';
        message = '${need.title} has been updated.';
        action = 'view_updated_need';

        for (var family in familyMembers) {
          if (family.notificationsEnabled && (family.notificationPreferences[action] ?? true)) {
            await NotificationService().sendNotification(
              userId: family.id,
              title: title,
              message: message,
              additionalData: {
                'needId': need.id,
                'seniorId': need.seniorId,
                'action': action,
              },
            );
          }
        }
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error updating need: $e');
      }
      return false;
    }
  }

  Future<bool> deleteNeed(String needId, String seniorId) async {
    try {
      if (kDebugMode) {
        print('Deleting need with ID: $needId');
      }
      await _needsCollection.doc(needId).delete();

      // Fetch connected family members
      List<FamilyMember> familyMembers = await getConnectedFamilyMembers(seniorId);

      // Send deletion notification
      for (var family in familyMembers) {
        if (family.notificationsEnabled && (family.notificationPreferences['view_deleted_need'] ?? true)) {
          await NotificationService().sendNotification(
            userId: family.id,
            title: 'Need Deleted',
            message: 'A need for the senior has been deleted.',
            additionalData: {
              'needId': needId,
              'seniorId': seniorId,
              'action': 'view_deleted_need',
            },
          );
        }
      }

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

Future<List<FamilyMember>> getEmergencyContacts(String seniorId) async {
  try {
    // Fetch the senior document
    final seniorDoc = await _firestore.collection('users').doc(seniorId).get();
    
    if (!seniorDoc.exists) {
      return [];
    }

    // Get emergency contact IDs
    final emergencyContactIds = List<String>.from(
      seniorDoc.data()?['emergencyContactIds'] ?? []
    );

    if (emergencyContactIds.isEmpty) {
      return [];
    }

    // Fetch emergency contact details from multiple collections
    final emergencyContactsFutures = emergencyContactIds.map((contactId) async {
      final userDoc = await _firestore.collection('users').doc(contactId).get();
      final familyDoc = await _firestore.collection('family_members').doc(contactId).get();
      
      if (userDoc.exists && familyDoc.exists) {
        // Merge data from both collections
        final mergedData = {
          ...?userDoc.data(),
          ...?familyDoc.data(),
          'id': contactId
        };
        
        return FamilyMember.fromMap(mergedData, contactId);
      }
      
      return null;
    });

    // Filter out null results and return only valid emergency contacts
    final emergencyContacts = await Future.wait(emergencyContactsFutures);
    return emergencyContacts.whereType<FamilyMember>().toList();
  } catch (e) {
    if (kDebugMode) {
      print('Error fetching emergency contacts: $e');
    }
    return [];
  }
}

// Optional: Method to add an emergency contact
Future<bool> addEmergencyContact(String seniorId, String contactId) async {
  try {
    // Get the current senior's document
    final seniorDocRef = _firestore.collection('users').doc(seniorId);
    
    // Update the emergency contact IDs array
    await seniorDocRef.update({
      'emergencyContactIds': FieldValue.arrayUnion([contactId])
    });
    
    return true;
  } catch (e) {
    if (kDebugMode) {
      print('Error adding emergency contact: $e');
    }
    return false;
  }
}

// Optional: Method to remove an emergency contact
Future<bool> removeEmergencyContact(String seniorId, String contactId) async {
  try {
    // Get the current senior's document
    final seniorDocRef = _firestore.collection('users').doc(seniorId);
    
    // Remove the contact ID from the emergency contact IDs array
    await seniorDocRef.update({
      'emergencyContactIds': FieldValue.arrayRemove([contactId])
    });
    
    return true;
  } catch (e) {
    if (kDebugMode) {
      print('Error removing emergency contact: $e');
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
  
// get family members profile 
 Future<FamilyMember?> getFamilyById(String id) async {
  try {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(id)
        .get();

    if (doc.exists) {
      return FamilyMember.fromFirestore(doc);
    } else {
      return null;
    }
  } catch (e) {
    print("Error in getFamilyById: $e");
    return null;
  }
}



// update family member profile 
Future<bool> updateFamily(FamilyMember member) async {
  try {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(member.id)
        .update(member.toMap());
    return true;
  } catch (e) {
    print('Error updating family member: $e');
    return false;
  }
}



// Add this method to your DatabaseService class

Future<void> updateVolunteer(Volunteer volunteer) async {
  try {
    print('Updating volunteer in Firebase with ID: ${volunteer.id}');
    print('Skills to be updated: ${volunteer.skills}');
    
    // Update the basic user info
    await _firestore.collection('users').doc(volunteer.id).update({
      'name': volunteer.name,
      'phoneNumber': volunteer.phoneNumber,
    });
    print('Updated user collection');
    
    // Update volunteer-specific info
    await _firestore.collection('volunteers').doc(volunteer.id).update({
      'bio': volunteer.bio,
      'skills': volunteer.skills,
      'servingAreas': volunteer.servingAreas,
      'experienceYears': volunteer.experienceYears,
    });
    print('Updated volunteers collection with skills: ${volunteer.skills}');
  } catch (e) {
    print('Error updating volunteer in Firebase: $e');
    rethrow; // Rethrow to handle in the UI
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
    
    // Try formatted date first
    List<dynamic>? slots = data['availability'][formattedDate];
    
    // If not found, try day of week
    if (slots == null) {
      final dayOfWeek = DateFormat('EEEE').format(timeSlot.startTime).toLowerCase();
      slots = data['availability'][dayOfWeek];
    }
    
    // If still not found, try original dateString
    if (slots == null && dateString != formattedDate) {
      slots = data['availability'][dateString];
    }
    
    if (slots == null) {
      print('No slots found for any date format.');
      return false;
    }
    
    // SOLUTION: Increase the acceptable time difference to match any available slot for the day
    // This ensures a slot is found if there's any availability on that day
    bool foundSlot = false;
    int closestSlotIndex = -1;
    int smallestTimeDifference = 9999;
    
    for (int i = 0; i < slots.length; i++) {
      var slot = slots[i];
      
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
      
      // Track the closest slot regardless of time difference
      if (startTimeDiff.abs() < smallestTimeDifference) {
        smallestTimeDifference = startTimeDiff.abs();
        closestSlotIndex = i;
      }
    }
    
    // Use the closest slot regardless of time difference
    // The volunteer is available on that day, so use the slot
    if (closestSlotIndex >= 0) {
      slots[closestSlotIndex]['isBooked'] = isBooked;
      slots[closestSlotIndex]['bookedById'] = bookedById;
      foundSlot = true;
    }
    
    if (!foundSlot) {
      print('Could not find any time slot for booking.');
      return false;
    }
    
    // Determine which key to use for the update
    String keyToUse = formattedDate;
    if (!data['availability'].containsKey(formattedDate)) {
      final dayOfWeek = DateFormat('EEEE').format(timeSlot.startTime).toLowerCase();
      if (data['availability'].containsKey(dayOfWeek)) {
        keyToUse = dayOfWeek;
      } else if (data['availability'].containsKey(dateString)) {
        keyToUse = dateString;
      }
    }
    
    // Update the volunteer document with the correct date key
    await _volunteersCollection.doc(volunteerId).update({
      'availability.$keyToUse': slots
    });
    
    return true;
  } catch (e) {
    print('Error updating volunteer time slot: $e');
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
  
 // Update the existing method to handle the modified Appointment class
Stream<List<Appointment>> getSeniorAppointments(String seniorId) {
  return _appointmentsCollection
      .where('seniorId', isEqualTo: seniorId)
      .orderBy('startTime')
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
          // Add new fields
          actualStartTime: data['actualStartTime'] != null
              ? (data['actualStartTime'] as Timestamp).toDate()
              : null,
          actualEndTime: data['actualEndTime'] != null
              ? (data['actualEndTime'] as Timestamp).toDate()
              : null,
          seniorConfirmedStart: data['seniorConfirmedStart'],
          seniorConfirmedEnd: data['seniorConfirmedEnd'],
          actualDurationMinutes: data['actualDurationMinutes'],
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

  // Add these methods to your DatabaseService class

// Request to start an appointment (volunteer initiates)
  Future<bool> requestStartAppointment(String appointmentId) async {
    try {
      await _appointmentsCollection.doc(appointmentId).update({
        'status': AppointmentStatus.waitingToStart.name,
        'actualStartTimeRequested': FieldValue.serverTimestamp(),
      });
      
      // Get appointment to send notification
      DocumentSnapshot appointmentDoc = await _appointmentsCollection.doc(appointmentId).get();
      Map<String, dynamic> appointmentData = appointmentDoc.data() as Map<String, dynamic>;
      String seniorId = appointmentData['seniorId'];
      
      // Send notification to senior using NotificationService
      await NotificationService().sendNotification(
        userId: seniorId,
        title: 'Appointment Start Request',
        message: 'The volunteer has requested to start your appointment. Please confirm.',
        additionalData: {
          'appointmentId': appointmentId,
          'action': 'start',
        },
      );
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error requesting to start appointment: $e');
      }
      return false;
    }
  }

  // Request to end an appointment (volunteer initiates)
  Future<bool> requestEndAppointment(String appointmentId) async {
    try {
      await _appointmentsCollection.doc(appointmentId).update({
        'status': AppointmentStatus.waitingToEnd.name,
        'actualEndTimeRequested': FieldValue.serverTimestamp(),
      });
      
      // Get appointment to send notification
      DocumentSnapshot appointmentDoc = await _appointmentsCollection.doc(appointmentId).get();
      Map<String, dynamic> appointmentData = appointmentDoc.data() as Map<String, dynamic>;
      String seniorId = appointmentData['seniorId'];
      
      // Send notification to senior using NotificationService
      await NotificationService().sendNotification(
        userId: seniorId,
        title: 'Appointment End Request',
        message: 'The volunteer has requested to end your appointment. Please confirm.',
        additionalData: {
          'appointmentId': appointmentId,
          'action': 'end',
        },
      );
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error requesting to end appointment: $e');
      }
      return false;
    }
  }

  // Senior confirms appointment start
  Future<bool> confirmAppointmentStart(String appointmentId) async {
    try {
      await _appointmentsCollection.doc(appointmentId).update({
        'status': AppointmentStatus.inProgress.name,
        'actualStartTime': FieldValue.serverTimestamp(),
        'seniorConfirmedStart': true,
      });
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error confirming appointment start: $e');
      }
      return false;
    }
  }

  // Senior confirms appointment end and calculates actual duration
  Future<bool> confirmAppointmentEnd(String appointmentId) async {
    try {
      DocumentSnapshot appointmentDoc = await _appointmentsCollection.doc(appointmentId).get();
      Map<String, dynamic> data = appointmentDoc.data() as Map<String, dynamic>;
      
      Timestamp? actualStartTimestamp = data['actualStartTime'] as Timestamp?;
      
      if (actualStartTimestamp == null) {
        return false;
      }
      
      DateTime actualStartTime = actualStartTimestamp.toDate();
      DateTime actualEndTime = DateTime.now();
      
      int actualDurationMinutes = actualEndTime.difference(actualStartTime).inMinutes;
      
      await _appointmentsCollection.doc(appointmentId).update({
        'status': AppointmentStatus.completed.name,
        'actualEndTime': Timestamp.fromDate(actualEndTime),
        'seniorConfirmedEnd': true,
        'completedAt': Timestamp.fromDate(actualEndTime),
        'actualDurationMinutes': actualDurationMinutes,
      });
      
      String volunteerId = data['volunteerId'];
      await updateVolunteerActualHours(volunteerId, actualDurationMinutes);
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error confirming appointment end: $e');
      }
      return false;
    }
  }

  // Update volunteer hours based on actual minutes worked
  Future<bool> updateVolunteerActualHours(String volunteerId, int additionalMinutes) async {
    try {
      DocumentSnapshot volunteerDoc = await _volunteersCollection.doc(volunteerId).get();
      Map<String, dynamic> data = volunteerDoc.data() as Map<String, dynamic>;
      
      int currentHours = data['totalHoursVolunteered'] ?? 0;
      int currentMinutes = data['totalMinutesVolunteered'] ?? 0;
      
      int totalMinutes = (currentHours * 60) + currentMinutes + additionalMinutes;
      
      int newHours = totalMinutes ~/ 60;
      int remainingMinutes = totalMinutes % 60;
      
      await _volunteersCollection.doc(volunteerId).update({
        'totalHoursVolunteered': newHours,
        'totalMinutesVolunteered': remainingMinutes,
      });
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error updating volunteer hours: $e');
      }
      return false;
    }
  }

   AppointmentStatus _stringToAppointmentStatus(String status) {
    switch (status) {
      case 'scheduled':
        return AppointmentStatus.scheduled;
      case 'waitingToStart':
        return AppointmentStatus.waitingToStart;
      case 'inProgress':
        return AppointmentStatus.inProgress;
      case 'waitingToEnd':
        return AppointmentStatus.waitingToEnd;
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
      'status': newStatus.name,
    });
    // Verify update
    DocumentSnapshot doc = await _appointmentsCollection.doc(appointmentId).get();
    print('Updated appointment $appointmentId status: ${(doc.data() as Map<String, dynamic>)['status']}');
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
    // Check if document already exists
    QuerySnapshot querySnapshot = await _appointmentsCollection
        .where('seniorId', isEqualTo: appointment.seniorId)
        .where('volunteerId', isEqualTo: appointment.volunteerId)
        .where('startTime', isEqualTo: Timestamp.fromDate(appointment.startTime))
        .limit(1)
        .get();
    
    // If document doesn't exist, add it
    if (querySnapshot.docs.isEmpty) {
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
    } else {
      // Document already exists
      return querySnapshot.docs.first.id;
    }
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

  Future<bool> submitReview(Review review) async {
    try {
      await _firestore.collection('reviews').doc(review.id).set(review.toMap());
      
      // Update volunteer's average rating
      final volunteerRef = _firestore.collection('volunteers').doc(review.volunteerId);
      final volunteerDoc = await volunteerRef.get();
      
      if (volunteerDoc.exists) {
        final currentRating = volunteerDoc.data()?['rating'] as double? ?? 0.0;
        final totalReviews = volunteerDoc.data()?['totalReviews'] as int? ?? 0;
        
        final newTotalReviews = totalReviews + 1;
        final newRating = ((currentRating * totalReviews) + review.rating) / newTotalReviews;
        
        await volunteerRef.update({
          'rating': newRating,
          'totalReviews': newTotalReviews,
        });
      }
      
      return true;
    } catch (e) {
      print('Error submitting review: $e');
      return false;
    }
  }

  Future<List<Review>> getVolunteerReviews(String volunteerId) async {
    try {
      final snapshot = await _firestore
          .collection('reviews')
          .where('volunteerId', isEqualTo: volunteerId)
          .orderBy('createdAt', descending: true)
          .get();
      
      return snapshot.docs
          .map((doc) => Review.fromMap(doc.data()))
          .toList();
    } catch (e) {
      print('Error getting volunteer reviews: $e');
      return [];
    }
  }

  Future<Review?> getAppointmentReview(String appointmentId) async {
    try {
      final snapshot = await _firestore
          .collection('reviews')
          .where('appointmentId', isEqualTo: appointmentId)
          .get();
      
      if (snapshot.docs.isEmpty) {
        return null;
      }
      
      return Review.fromMap(snapshot.docs.first.data());
    } catch (e) {
      print('Error getting appointment review: $e');
      return null;
    }
  }

  // Find available volunteers based on location and time slot
  Future<List<Volunteer>> findAvailableVolunteers({
    required String seniorLocation,
    required TimeSlot timeSlot,
  }) async {
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
          
          // Check if volunteer serves the senior's location
          bool servesLocation = volunteer.servingAreas.any((area) => 
            area.toLowerCase().contains(seniorLocation.toLowerCase()) ||
            seniorLocation.toLowerCase().contains(area.toLowerCase())
          );
          
          if (servesLocation) {
            // Check if volunteer has availability for the requested date
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
      }
      
      return availableVolunteers;
    } catch (e) {
      if (kDebugMode) {
        print('Error finding available volunteers: $e');
      }
      return [];
    }
  }
}