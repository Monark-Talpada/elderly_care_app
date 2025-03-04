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
      phoneNumber: data['phoneNumber'],
      createdAt: data['createdAt'] != null 
          ? (data['createdAt'] as Timestamp).toDate() 
          : DateTime.now(),
      skills: List<String>.from(data['skills'] ?? []),
      isVerified: data['isVerified'] ?? false,
      bio: data['bio'],
      availability: availabilityMap,
      totalHoursVolunteered: data['totalHoursVolunteered'] ?? 0,
      servingAreas: List<String>.from(data['servingAreas'] ?? []),
      rating: data['rating']?.toDouble(),
      ratingCount: data['ratingCount'],
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
    });
    return data;
  }

  Volunteer copyWith({
    List<String>? skills,
    bool? isVerified,
    String? bio,
    Map<String, List<TimeSlot>>? availability,
    int? totalHoursVolunteered,
    List<String>? servingAreas,
    double? rating,
    int? ratingCount,
  }) {
    return Volunteer(
      id: id,
      email: email,
      name: name,
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
    );
  }
}

class TimeSlot {
  final DateTime startTime;
  final DateTime endTime;
  final bool isBooked;
  final String? bookedById;

  TimeSlot({
    required this.startTime,
    required this.endTime,
    this.isBooked = false,
    this.bookedById,
  });

  factory TimeSlot.fromMap(Map<String, dynamic> map) {
    return TimeSlot(
      startTime: (map['startTime'] as Timestamp).toDate(),
      endTime: (map['endTime'] as Timestamp).toDate(),
      isBooked: map['isBooked'] ?? false,
      bookedById: map['bookedById'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'isBooked': isBooked,
      'bookedById': bookedById,
    };
  }

  TimeSlot copyWith({
    DateTime? startTime,
    DateTime? endTime,
    bool? isBooked,
    String? bookedById,
  }) {
    return TimeSlot(
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isBooked: isBooked ?? this.isBooked,
      bookedById: bookedById ?? this.bookedById,
    );
  }
}