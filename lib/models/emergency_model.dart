import 'package:cloud_firestore/cloud_firestore.dart';

class EmergencyContact {
  final String? id;
  final String name;
  final String phoneNumber;
  final String? relationship;
  final String seniorId;

  const EmergencyContact({
    this.id,
    required this.name,
    required this.phoneNumber,
    this.relationship,
    required this.seniorId,
  });

  // Convert the model to a map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phoneNumber': phoneNumber,
      'relationship': relationship,
      'seniorId': seniorId,
    };
  }

  // Create an EmergencyContact from a Firestore document
  factory EmergencyContact.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return EmergencyContact(
      id: doc.id,
      name: data['name'] as String? ?? '',
      phoneNumber: data['phoneNumber'] as String? ?? '',
      relationship: data['relationship'] as String?,
      seniorId: data['seniorId'] as String? ?? '',
    );
  }

  // Optional: Add equality and hashCode for comparison
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EmergencyContact &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          phoneNumber == other.phoneNumber &&
          relationship == other.relationship &&
          seniorId == other.seniorId;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      phoneNumber.hashCode ^
      relationship.hashCode ^
      seniorId.hashCode;
}