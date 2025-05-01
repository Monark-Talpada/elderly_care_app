import 'package:cloud_firestore/cloud_firestore.dart';

class Review {
  final String id;
  final String appointmentId;
  final String volunteerId;
  final String seniorId;
  final double rating;
  final String feedback;
  final DateTime createdAt;

  Review({
    required this.id,
    required this.appointmentId,
    required this.volunteerId,
    required this.seniorId,
    required this.rating,
    required this.feedback,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'appointmentId': appointmentId,
      'volunteerId': volunteerId,
      'seniorId': seniorId,
      'rating': rating,
      'feedback': feedback,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory Review.fromMap(Map<String, dynamic> map) {
    return Review(
      id: map['id'] as String,
      appointmentId: map['appointmentId'] as String,
      volunteerId: map['volunteerId'] as String,
      seniorId: map['seniorId'] as String,
      rating: (map['rating'] as num).toDouble(),
      feedback: map['feedback'] as String,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  Review copyWith({
    String? id,
    String? appointmentId,
    String? volunteerId,
    String? seniorId,
    double? rating,
    String? feedback,
    DateTime? createdAt,
  }) {
    return Review(
      id: id ?? this.id,
      appointmentId: appointmentId ?? this.appointmentId,
      volunteerId: volunteerId ?? this.volunteerId,
      seniorId: seniorId ?? this.seniorId,
      rating: rating ?? this.rating,
      feedback: feedback ?? this.feedback,
      createdAt: createdAt ?? this.createdAt,
    );
  }
} 