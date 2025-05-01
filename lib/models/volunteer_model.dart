import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elderly_care_app/models/user_model.dart';

class Volunteer extends User {
  final List<String> skills;
  final bool isVerified;
  final String? bio;
  final Map<String, List<TimeSlot>> availability;
  final int totalHoursVolunteered;
  final List<String> servingAreas;
  final double? rating;
  final int? ratingCount;
  final int experienceYears;

  Volunteer({
    required super.id,
    required super.email,
    required super.name,
    super.photoUrl,
    super.phoneNumber,
    required super.createdAt,
    this.skills = const [],
    this.isVerified = false,
    this.bio,
    this.availability = const {},
    this.totalHoursVolunteered = 0,
    this.servingAreas = const [],
    this.rating,
    this.ratingCount,
    this.experienceYears = 0,
  }) : super(userType: UserType.volunteer);

  factory Volunteer.fromFirestore(DocumentSnapshot doc) {
    User baseUser = User.fromFirestore(doc);
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    Map<String, List<TimeSlot>> availabilityMap = {};
    if (data['availability'] != null) {
      Map<String, dynamic> rawAvailability = data['availability'];
      rawAvailability.forEach((day, slots) {
        availabilityMap[day] = (slots as List)
            .map((slot) => TimeSlot.fromMap(slot))
            .toList();
      });
    }

    return Volunteer(
      id: baseUser.id,
      email: baseUser.email,
      name: baseUser.name,
      photoUrl: baseUser.photoUrl,
      phoneNumber: baseUser.phoneNumber,
      createdAt: baseUser.createdAt,
      skills: List<String>.from(data['skills'] ?? []),
      isVerified: data['isVerified'] ?? false,
      bio: data['bio'],
      availability: availabilityMap,
      totalHoursVolunteered: data['totalHoursVolunteered'] ?? 0,
      servingAreas: List<String>.from(data['servingAreas'] ?? []),
      rating: data['rating']?.toDouble(),
      ratingCount: data['ratingCount'],
      experienceYears: data['experienceYears'] ?? 0,
    );
  }

  factory Volunteer.fromMap(Map<String, dynamic> data, String id) {
    Map<String, List<TimeSlot>> availabilityMap = {};
    if (data['availability'] != null) {
      Map<String, dynamic> rawAvailability = data['availability'];
      rawAvailability.forEach((day, slots) {
        availabilityMap[day] = (slots as List)
            .map((slot) => TimeSlot.fromMap(slot))
            .toList();
      });
    }

    return Volunteer(
      id: id,
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      photoUrl: data['photoUrl'],
      phoneNumber: data['phoneNumber'] ?? data['phone'],
      createdAt: data['createdAt'] != null 
          ? (data['createdAt'] is Timestamp 
              ? (data['createdAt'] as Timestamp).toDate() 
              : data['createdAt']) 
          : DateTime.now(),
      skills: List<String>.from(data['skills'] ?? []),
      isVerified: data['isVerified'] ?? false,
      bio: data['bio'],
      availability: availabilityMap,
      totalHoursVolunteered: data['totalHoursVolunteered'] ?? 0,
      servingAreas: List<String>.from(data['servingAreas'] ?? []),
      rating: data['rating']?.toDouble(),
      ratingCount: data['ratingCount'],
      experienceYears: data['experienceYears'] ?? 0,
    );
  }

  @override
  Map<String, dynamic> toMap() {
    final Map<String, dynamic> data = super.toMap();
    
    Map<String, List<Map<String, dynamic>>> availabilityMap = {};
    availability.forEach((day, slots) {
      availabilityMap[day] = slots.map((slot) => slot.toMap()).toList();
    });
    
    data.addAll({
      'skills': skills,
      'isVerified': isVerified,
      'bio': bio,
      'availability': availabilityMap,
      'totalHoursVolunteered': totalHoursVolunteered,
      'servingAreas': servingAreas,
      'rating': rating,
      'ratingCount': ratingCount,
      'experienceYears': experienceYears,
    });
    return data;
  }

  Volunteer copyWith({
    List<String>? skills,
    bool? isVerified,
    String? bio,
    String? name,
    String? phoneNumber,
    Map<String, List<TimeSlot>>? availability,
    int? totalHoursVolunteered,
    List<String>? servingAreas,
    double? rating,
    int? ratingCount,
    int? experienceYears,
  }) {
    return Volunteer(
      id: id,
      email: email,
      name: name ?? this.name,
      photoUrl: photoUrl,
      phoneNumber: phoneNumber,
      createdAt: createdAt,
      skills: skills ?? this.skills,
      isVerified: isVerified ?? this.isVerified,
      bio: bio ?? this.bio,
      availability: availability ?? this.availability,
      totalHoursVolunteered: totalHoursVolunteered ?? this.totalHoursVolunteered,
      servingAreas: servingAreas ?? this.servingAreas,
      rating: rating ?? this.rating,
      ratingCount: ratingCount ?? this.ratingCount,
      experienceYears: experienceYears ?? this.experienceYears,
    );
  }
}

class TimeSlot {
  final DateTime startTime;
  final DateTime endTime;
  final bool isBooked;
  final String? bookedById;
  final String? location;

  TimeSlot({
    required this.startTime,
    required this.endTime,
    this.isBooked = false,
    this.bookedById,
    this.location,
  });

  factory TimeSlot.fromMap(Map<String, dynamic> map) {
    // Handle both DateTime and String time formats
    DateTime parseStartTime;
    DateTime parseEndTime;

    if (map['startTime'] is Timestamp) {
      parseStartTime = (map['startTime'] as Timestamp).toDate();
      parseEndTime = (map['endTime'] as Timestamp).toDate();
    } else if (map['startTime'] is String) {
      // Parse from HH:MM format
      final startTimeParts = (map['startTime'] as String).split(':');
      final endTimeParts = (map['endTime'] as String).split(':');
      
      final now = DateTime.now();
      parseStartTime = DateTime(
        now.year,
        now.month,
        now.day,
        int.parse(startTimeParts[0]),
        int.parse(startTimeParts[1]),
      );
      
      parseEndTime = DateTime(
        now.year,
        now.month,
        now.day,
        int.parse(endTimeParts[0]),
        int.parse(endTimeParts[1]),
      );
    } else {
      // Default to current time if format is unknown
      parseStartTime = DateTime.now();
      parseEndTime = DateTime.now().add(const Duration(hours: 1));
    }

    return TimeSlot(
      startTime: parseStartTime,
      endTime: parseEndTime,
      isBooked: map['isBooked'] ?? false,
      bookedById: map['bookedById'],
      location: map['location'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'isBooked': isBooked,
      'bookedById': bookedById,
      'location': location,
    };
  }

  // Get hours and minutes as strings for UI display
  String get startTimeString => 
      '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';

  String get endTimeString => 
      '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';

  TimeSlot copyWith({
    DateTime? startTime,
    DateTime? endTime,
    bool? isBooked,
    String? bookedById,
    String? location,
  }) {
    return TimeSlot(
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isBooked: isBooked ?? this.isBooked,
      bookedById: bookedById ?? this.bookedById,
      location: location ?? this.location,
    );
  }

  // Create a TimeSlot from hour and minute values
  factory TimeSlot.fromHourMinute({
    required int startHour,
    required int startMinute,
    required int endHour,
    required int endMinute,
    bool isBooked = false,
    String? bookedById,
    String? location,
  }) {
    final now = DateTime.now();
    return TimeSlot(
      startTime: DateTime(
        now.year,
        now.month,
        now.day,
        startHour,
        startMinute,
      ),
      endTime: DateTime(
        now.year,
        now.month,
        now.day,
        endHour,
        endMinute,
      ),
      isBooked: isBooked,
      bookedById: bookedById,
      location: location,
    );
  }
}