  import 'package:cloud_firestore/cloud_firestore.dart';
  import 'package:elderly_care_app/models/user_model.dart';

  class SeniorCitizen extends User {
    final List<String> connectedFamilyIds;
    final bool emergencyModeActive;
    final GeoPoint? lastKnownLocation;
    final DateTime? lastLocationUpdate;
 
    
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
       
      });
      return data;
    }
    
    SeniorCitizen copyWith({
      String? name,
      List<String>? connectedFamilyIds,
      bool? emergencyModeActive,
      GeoPoint? lastKnownLocation,
      DateTime? lastLocationUpdate,
    }) {
      return SeniorCitizen(
        id: id,
        email: email,
        name: name ?? this.name, // Add this line
        photoUrl: photoUrl,
        phoneNumber: phoneNumber,
        createdAt: createdAt,
        connectedFamilyIds: connectedFamilyIds ?? this.connectedFamilyIds,
        emergencyModeActive: emergencyModeActive ?? this.emergencyModeActive,
        lastKnownLocation: lastKnownLocation ?? this.lastKnownLocation,
        lastLocationUpdate: lastLocationUpdate ?? this.lastLocationUpdate,
      );
    }

  }