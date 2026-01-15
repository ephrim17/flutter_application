import 'package:cloud_firestore/cloud_firestore.dart';

class ServiceModel {
  final String id; // docId
  final String title;
  final String description;

  // Optional scalable fields (add later easily)
  final bool isActive;

  const ServiceModel({
    required this.id,
    required this.title,
    required this.description,
    required this.isActive,
  });

  ServiceModel copyWith({
    String? id,
    String? title,
    String? description,
    bool? isActive,
  }) {
    return ServiceModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive
    );
  }

  /// For writing to Firestore (id is not stored inside fields)
  Map<String, dynamic> toMap() => {
        'title': title,
        'description': description,
        'isActive': isActive,
      };

  /// For reading from Firestore
  static ServiceModel fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};

    return ServiceModel(
      id: doc.id,
      title: (data['title'] ?? '') as String,
      description: (data['description'] ?? '') as String,
      isActive: (data['isActive'] ?? true) as bool,
    );
  }
}
