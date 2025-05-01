import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elderly_care_app/models/user_model.dart';

class SeniorCitizen extends User {
  final List<String> connectedFamilyIds;
  final bool emergencyModeActive;
  final GeoPoint? lastKnownLocation;
  final DateTime? lastLocationUpdate;
  // Physical and health details
  final double? height; // in cm
  final double? weight; // in kg
  final String? bloodGroup;
  final List<String>? allergies;
  final List<String>? medications;
  final List<String>? medicalConditions;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final String? primaryPhysicianName;
  final String? primaryPhysicianPhone;

  SeniorCitizen({
    required super.id,
    required super.email,
    required super.name,
    super.photoUrl,
    super.phoneNumber,
    required super.createdAt,
    this.connectedFamilyIds = const [],
    this.emergencyModeActive = false,
    this.lastKnownLocation,
    this.lastLocationUpdate,
    this.height,
    this.weight,
    this.bloodGroup,
    this.allergies,
    this.medications,
    this.medicalConditions,
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.primaryPhysicianName,
    this.primaryPhysicianPhone,
  }) : super(userType: UserType.senior);
  
  factory SeniorCitizen.fromFirestore(DocumentSnapshot doc) {
    User baseUser = User.fromFirestore(doc);
    Map data = doc.data() as Map;
    
    return SeniorCitizen(
      id: baseUser.id,
      email: baseUser.email,
      name: baseUser.name,
      photoUrl: baseUser.photoUrl,
      phoneNumber: baseUser.phoneNumber,
      createdAt: baseUser.createdAt,
      connectedFamilyIds: List<String>.from(data['connectedFamilyIds'] ?? []),
      emergencyModeActive: data['emergencyModeActive'] ?? false,
      lastKnownLocation: data['lastKnownLocation'],
      lastLocationUpdate: data['lastLocationUpdate'] != null 
          ? (data['lastLocationUpdate'] as Timestamp).toDate()
          : null,
      height: data['height']?.toDouble(),
      weight: data['weight']?.toDouble(),
      bloodGroup: data['bloodGroup'],
      allergies: List<String>.from(data['allergies'] ?? []),
      medications: List<String>.from(data['medications'] ?? []),
      medicalConditions: List<String>.from(data['medicalConditions'] ?? []),
      emergencyContactName: data['emergencyContactName'],
      emergencyContactPhone: data['emergencyContactPhone'],
      primaryPhysicianName: data['primaryPhysicianName'],
      primaryPhysicianPhone: data['primaryPhysicianPhone'],
    );
  }
  
  factory SeniorCitizen.fromMap(Map<String, dynamic> data, String id) {
    return SeniorCitizen(
      id: id,
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      photoUrl: data['photoUrl'],
      phoneNumber: data['phoneNumber'],
      createdAt: data['createdAt'] != null 
          ? (data['createdAt'] as Timestamp).toDate() 
          : DateTime.now(),
      connectedFamilyIds: List<String>.from(data['connectedFamilyIds'] ?? []),
      emergencyModeActive: data['emergencyModeActive'] ?? false,
      lastKnownLocation: data['lastKnownLocation'],
      lastLocationUpdate: data['lastLocationUpdate'] != null 
          ? (data['lastLocationUpdate'] as Timestamp).toDate()
          : null,
      height: data['height']?.toDouble(),
      weight: data['weight']?.toDouble(),
      bloodGroup: data['bloodGroup'],
      allergies: List<String>.from(data['allergies'] ?? []),
      medications: List<String>.from(data['medications'] ?? []),
      medicalConditions: List<String>.from(data['medicalConditions'] ?? []),
      emergencyContactName: data['emergencyContactName'],
      emergencyContactPhone: data['emergencyContactPhone'],
      primaryPhysicianName: data['primaryPhysicianName'],
      primaryPhysicianPhone: data['primaryPhysicianPhone'],
    );
  }
  
  @override
  Map<String, dynamic> toMap() {
    final Map<String, dynamic> data = super.toMap();
    data.addAll({
      'connectedFamilyIds': connectedFamilyIds,
      'emergencyModeActive': emergencyModeActive,
      'lastKnownLocation': lastKnownLocation,
      'lastLocationUpdate': lastLocationUpdate != null 
          ? Timestamp.fromDate(lastLocationUpdate!) 
          : null,
      'height': height,
      'weight': weight,
      'bloodGroup': bloodGroup,
      'allergies': allergies,
      'medications': medications,
      'medicalConditions': medicalConditions,
      'emergencyContactName': emergencyContactName,
      'emergencyContactPhone': emergencyContactPhone,
      'primaryPhysicianName': primaryPhysicianName,
      'primaryPhysicianPhone': primaryPhysicianPhone,
    });
    return data;
  }
  
  SeniorCitizen copyWith({
    String? name,
    List<String>? connectedFamilyIds,
    bool? emergencyModeActive,
    GeoPoint? lastKnownLocation,
    DateTime? lastLocationUpdate,
    double? height,
    double? weight,
    String? bloodGroup,
    List<String>? allergies,
    List<String>? medications,
    List<String>? medicalConditions,
    String? emergencyContactName,
    String? emergencyContactPhone,
    String? primaryPhysicianName,
    String? primaryPhysicianPhone,
  }) {
    return SeniorCitizen(
      id: id,
      email: email,
      name: name ?? this.name,
      photoUrl: photoUrl,
      phoneNumber: phoneNumber,
      createdAt: createdAt,
      connectedFamilyIds: connectedFamilyIds ?? this.connectedFamilyIds,
      emergencyModeActive: emergencyModeActive ?? this.emergencyModeActive,
      lastKnownLocation: lastKnownLocation ?? this.lastKnownLocation,
      lastLocationUpdate: lastLocationUpdate ?? this.lastLocationUpdate,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      allergies: allergies ?? this.allergies,
      medications: medications ?? this.medications,
      medicalConditions: medicalConditions ?? this.medicalConditions,
      emergencyContactName: emergencyContactName ?? this.emergencyContactName,
      emergencyContactPhone: emergencyContactPhone ?? this.emergencyContactPhone,
      primaryPhysicianName: primaryPhysicianName ?? this.primaryPhysicianName,
      primaryPhysicianPhone: primaryPhysicianPhone ?? this.primaryPhysicianPhone,
    );
  }
}