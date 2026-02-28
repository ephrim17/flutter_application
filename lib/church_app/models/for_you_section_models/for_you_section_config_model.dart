import 'package:cloud_firestore/cloud_firestore.dart';


class ForYouSectionConfigModel {
  const ForYouSectionConfigModel({
    required this.id,
    required this.enabled,
    required this.order,
  });

  final String id;
  final bool enabled;
  final int order;

  factory ForYouSectionConfigModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ForYouSectionConfigModel(
      id: doc.id,
      enabled: data['enabled'] ?? false,
      order: data['order'] ?? 100,
    );
  }

   Map<String, dynamic> toMap() => {
        'enabled': enabled,
        'order': order,
      };


}
