import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elderly_care_app/models/user_model.dart';

class FamilyMember extends User {
  final List<String> connectedSeniorIds;
  final bool notificationsEnabled;
  
  FamilyMember({
    required super.id,
    required super.email,
    required super.name,
    super.photoUrl,
    super.phoneNumber,
    required super.createdAt,
    this.connectedSeniorIds = const [],
    this.notificationsEnabled = true,
  }) : super(userType: UserType.family);
  
  factory FamilyMember.fromFirestore(DocumentSnapshot doc) {
    User baseUser = User.fromFirestore(doc);
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return FamilyMember(
      id: baseUser.id,
      email: baseUser.email,
      name: baseUser.name,
      photoUrl: baseUser.photoUrl,
      phoneNumber: baseUser.phoneNumber,
      createdAt: baseUser.createdAt,
      connectedSeniorIds: List<String>.from(data['connectedSeniorIds'] ?? []),
      notificationsEnabled: data['notificationsEnabled'] ?? true,
    );
  }
  
  @override
  Map<String, dynamic> toMap() {
    final Map<String, dynamic> data = super.toMap();
    data.addAll({
      'connectedSeniorIds': connectedSeniorIds,
      'notificationsEnabled': notificationsEnabled,
    });
    return data;
  }
  
  FamilyMember copyWith({
    List<String>? connectedSeniorIds,
    bool? notificationsEnabled,
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
    );
  }
}