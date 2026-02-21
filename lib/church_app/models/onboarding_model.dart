import 'package:cloud_firestore/cloud_firestore.dart';

class OnboardingModel {
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final bool isActive;

  OnboardingModel({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.isActive,
  });

  factory OnboardingModel.fromFirestore(
      DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return OnboardingModel(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      isActive: data['isActive'] ?? true,
    );
  }
}