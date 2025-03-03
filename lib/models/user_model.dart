import 'package:cloud_firestore/cloud_firestore.dart';

enum UserType { senior, family, volunteer }

class User {
  final String id;
  final String email;
  final String name;
  final String? photoUrl;
  final UserType userType;
  final String? phoneNumber;
  final DateTime createdAt;
  
  User({
    required this.id,
    required this.email,
    required this.name,
    this.photoUrl,
    required this.userType,
    this.phoneNumber,
    required this.createdAt,
  });
  
  factory User.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return User(
      id: doc.id,
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      photoUrl: data['photoUrl'],
      userType: UserType.values.firstWhere(
        (e) => e.toString() == 'UserType.${data['userType']}',
        orElse: () => UserType.senior,
      ),
      phoneNumber: data['phoneNumber'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'name': name,
      'photoUrl': photoUrl,
      'userType': userType.toString().split('.').last,
      'phoneNumber': phoneNumber,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}