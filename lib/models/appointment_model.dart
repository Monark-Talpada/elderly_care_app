import 'package:cloud_firestore/cloud_firestore.dart';

enum AppointmentStatus {
  scheduled,
  inProgress,
  completed,
  cancelled,
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
    );
  }

  factory Appointment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Appointment.fromMap(data, doc.id);
  }

  // Calculate duration in hours
  double get durationInHours {
    return endTime.difference(startTime).inMinutes / 60;
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