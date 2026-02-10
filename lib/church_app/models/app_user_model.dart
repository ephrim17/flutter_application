import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final String role;
  final String authToken;
  final DateTime? dob;
  final bool approved;

  AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.approved,
    required this.phone,
    required this.authToken,
    required this.dob,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    final dobRaw = json['dob'];
    
    return AppUser(
      uid: json['uid'] ?? '',
      phone: json['phone'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      authToken: json['authToken'] ?? '',
      dob: dobRaw is Timestamp
          ? dobRaw.toDate()
          : dobRaw is DateTime
              ? dobRaw
              : null,
      role: json['role'] ?? 'user',
      approved: json['approved'] ?? false,
    );
  }
}
