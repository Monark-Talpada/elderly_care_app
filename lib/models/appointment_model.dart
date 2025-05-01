import 'package:cloud_firestore/cloud_firestore.dart';

enum AppointmentStatus {
  scheduled,        // Initial state
  waitingToStart,   // Volunteer requested to start
  inProgress,       // Senior confirmed start
  waitingToEnd,     // Volunteer requested to end
  completed,        // Senior confirmed end
  cancelled         // Cancelled appointment
}

extension AppointmentStatusExtension on AppointmentStatus {
  String get name => toString().split('.').last;

  static AppointmentStatus fromString(String status) {
    return AppointmentStatus.values.firstWhere(
      (e) => e.name == status,
      orElse: () => AppointmentStatus.scheduled,
    );
  }
}

class Appointment {
  final String id;
  final String seniorId;
  final String volunteerId;
  final String? needId;
  final DateTime startTime;
  final DateTime endTime;
  final AppointmentStatus status;
  final String notes;
  final DateTime createdAt;
  final DateTime? completedAt;
  final int? rating;
  final String? feedback;
  
  // New fields for time tracking and confirmation
  final DateTime? actualStartTime;    // When volunteer actually started
  final DateTime? actualEndTime;      // When volunteer actually ended
  final bool? seniorConfirmedStart;   // Senior confirmed start
  final bool? seniorConfirmedEnd;     // Senior confirmed end
  final int? actualDurationMinutes;   // Actual duration in minutes

  Appointment({
    required this.id,
    required this.seniorId,
    required this.volunteerId,
    this.needId,
    required this.startTime,
    required this.endTime,
    this.status = AppointmentStatus.scheduled,
    this.notes = '',
    required this.createdAt,
    this.completedAt,
    this.rating,
    this.feedback,
    this.actualStartTime,
    this.actualEndTime,
    this.seniorConfirmedStart,
    this.seniorConfirmedEnd,
    this.actualDurationMinutes,
  });

  Appointment copyWith({
    String? id,
    String? seniorId,
    String? volunteerId,
    String? needId,
    DateTime? startTime,
    DateTime? endTime,
    AppointmentStatus? status,
    String? notes,
    DateTime? createdAt,
    DateTime? completedAt,
    int? rating,
    String? feedback,
    DateTime? actualStartTime,
    DateTime? actualEndTime,
    bool? seniorConfirmedStart,
    bool? seniorConfirmedEnd,
    int? actualDurationMinutes,
  }) {
    return Appointment(
      id: id ?? this.id,
      seniorId: seniorId ?? this.seniorId,
      volunteerId: volunteerId ?? this.volunteerId,
      needId: needId ?? this.needId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      rating: rating ?? this.rating,
      feedback: feedback ?? this.feedback,
      actualStartTime: actualStartTime ?? this.actualStartTime,
      actualEndTime: actualEndTime ?? this.actualEndTime,
      seniorConfirmedStart: seniorConfirmedStart ?? this.seniorConfirmedStart,
      seniorConfirmedEnd: seniorConfirmedEnd ?? this.seniorConfirmedEnd,
      actualDurationMinutes: actualDurationMinutes ?? this.actualDurationMinutes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'seniorId': seniorId,
      'volunteerId': volunteerId,
      'needId': needId,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'status': status.name,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'rating': rating,
      'feedback': feedback,
      'actualStartTime': actualStartTime != null ? Timestamp.fromDate(actualStartTime!) : null,
      'actualEndTime': actualEndTime != null ? Timestamp.fromDate(actualEndTime!) : null,
      'seniorConfirmedStart': seniorConfirmedStart,
      'seniorConfirmedEnd': seniorConfirmedEnd,
      'actualDurationMinutes': actualDurationMinutes,
    };
  }

  factory Appointment.fromMap(Map<String, dynamic> map, String id) {
    return Appointment(
      id: id,
      seniorId: map['seniorId'] ?? '',
      volunteerId: map['volunteerId'] ?? '',
      needId: map['needId'],
      startTime: map['startTime'] is Timestamp
          ? (map['startTime'] as Timestamp).toDate()
          : DateTime.parse(map['startTime'].toString()),
      endTime: map['endTime'] is Timestamp
          ? (map['endTime'] as Timestamp).toDate()
          : DateTime.parse(map['endTime'].toString()),
      status: map['status'] is String
          ? AppointmentStatusExtension.fromString(map['status'])
          : AppointmentStatus.scheduled,
      notes: map['notes'] ?? '',
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.parse(map['createdAt'].toString()),
      completedAt: map['completedAt'] != null
          ? (map['completedAt'] is Timestamp
              ? (map['completedAt'] as Timestamp).toDate()
              : DateTime.parse(map['completedAt'].toString()))
          : null,
      rating: map['rating'],
      feedback: map['feedback'],
      actualStartTime: map['actualStartTime'] != null
          ? (map['actualStartTime'] is Timestamp
              ? (map['actualStartTime'] as Timestamp).toDate()
              : DateTime.parse(map['actualStartTime'].toString()))
          : null,
      actualEndTime: map['actualEndTime'] != null
          ? (map['actualEndTime'] is Timestamp
              ? (map['actualEndTime'] as Timestamp).toDate()
              : DateTime.parse(map['actualEndTime'].toString()))
          : null,
      seniorConfirmedStart: map['seniorConfirmedStart'],
      seniorConfirmedEnd: map['seniorConfirmedEnd'],
      actualDurationMinutes: map['actualDurationMinutes'],
    );
  }

  factory Appointment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Appointment.fromMap(data, doc.id);
  }

  // Calculate duration in hours (from scheduled times)
  double get durationInHours {
    return endTime.difference(startTime).inMinutes / 60;
  }

  // Calculate actual duration in hours
  double? get actualDurationInHours {
    if (actualStartTime != null && actualEndTime != null) {
      return actualEndTime!.difference(actualStartTime!).inMinutes / 60;
    }
    return actualDurationMinutes != null ? actualDurationMinutes! / 60 : null;
  }

  // Check if appointment is happening now
  bool get isHappeningNow {
    final now = DateTime.now();
    return now.isAfter(startTime) && now.isBefore(endTime);
  }

  // Check if appointment is in the future
  bool get isUpcoming {
    return DateTime.now().isBefore(startTime);
  }

  // Check if appointment is in the past
  bool get isPast {
    return DateTime.now().isAfter(endTime);
  }
}