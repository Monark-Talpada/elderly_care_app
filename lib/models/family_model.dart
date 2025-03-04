import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elderly_care_app/models/user_model.dart';

class FamilyMember extends User {
  final List<String> connectedSeniorIds;
  final bool notificationsEnabled;
  final String? relationship;
  final Map<String, bool> notificationPreferences;
  
  FamilyMember({
    required super.id,
    required super.email,
    required super.name,
    super.photoUrl,
    super.phoneNumber,
    required super.createdAt,
    this.connectedSeniorIds = const [],
    this.notificationsEnabled = true,
    this.relationship,
    this.notificationPreferences = const {},
  }) : super(userType: UserType.family);
  
  factory FamilyMember.fromFirestore(DocumentSnapshot doc) {
    User baseUser = User.fromFirestore(doc);
    Map data = doc.data() as Map;
    
    return FamilyMember(
      id: baseUser.id,
      email: baseUser.email,
      name: baseUser.name,
      photoUrl: baseUser.photoUrl,
      phoneNumber: baseUser.phoneNumber,
      createdAt: baseUser.createdAt,
      connectedSeniorIds: List<String>.from(data['connectedSeniorIds'] ?? []),
      notificationsEnabled: data['notificationsEnabled'] ?? true,
      relationship: data['relationship'],
      notificationPreferences: data['notificationPreferences'] != null 
          ? Map<String, bool>.from(data['notificationPreferences']) 
          : {},
    );
  }
  
  factory FamilyMember.fromMap(Map<String, dynamic> data, String id) {
    return FamilyMember(
      id: id,
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      photoUrl: data['photoUrl'],
      phoneNumber: data['phoneNumber'],
      createdAt: data['createdAt'] != null 
          ? (data['createdAt'] as Timestamp).toDate() 
          : DateTime.now(),
      relationship: data['relationship'],
      connectedSeniorIds: List<String>.from(data['connectedSeniorIds'] ?? []),
      notificationPreferences: data['notificationPreferences'] != null 
          ? Map<String, bool>.from(data['notificationPreferences']) 
          : {},
      notificationsEnabled: data['notificationsEnabled'] ?? true,
    );
  }
  
  @override
  Map<String, dynamic> toMap() {
    final Map<String, dynamic> data = super.toMap();
    data.addAll({
      'connectedSeniorIds': connectedSeniorIds,
      'notificationsEnabled': notificationsEnabled,
      'relationship': relationship,
      'notificationPreferences': notificationPreferences,
    });
    return data;
  }
  
  FamilyMember copyWith({
    List<String>? connectedSeniorIds,
    bool? notificationsEnabled,
    String? relationship,
    Map<String, bool>? notificationPreferences,
  }) {
    return FamilyMember(
      id: id,
      email: email,
      name: name,
      photoUrl: photoUrl,
      phoneNumber: phoneNumber,
      createdAt: createdAt,
      connectedSeniorIds: connectedSeniorIds ?? this.connectedSeniorIds,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      relationship: relationship ?? this.relationship,
      notificationPreferences: notificationPreferences ?? this.notificationPreferences,
    );
  }
}