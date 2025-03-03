class Appointment {
  final String id;
  final String seniorId;
  final String volunteerId;
  final String? needId;
  final DateTime startTime;
  final DateTime endTime;
  final AppointmentStatus status;
  final String? notes;
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
    required this.status,
    this.notes,
    required this.createdAt,
    this.completedAt,
    this.rating,
    this.feedback,
  });
}

enum AppointmentStatus {
  scheduled,
  inProgress,
  completed,
  cancelled,
}