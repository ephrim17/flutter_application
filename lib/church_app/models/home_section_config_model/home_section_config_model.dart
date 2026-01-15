import 'package:cloud_firestore/cloud_firestore.dart';


class HomeSectionConfigModel {
  const HomeSectionConfigModel({
    required this.id,
    required this.enabled,
    required this.order,
  });

  final String id;
  final bool enabled;
  final int order;

  factory HomeSectionConfigModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return HomeSectionConfigModel(
      id: doc.id,
      enabled: data['enabled'] ?? false,
      order: data['order'] ?? 100,
    );
  }
}
