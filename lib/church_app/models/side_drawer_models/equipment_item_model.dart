import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application/church_app/models/picked_image_data.dart';

class EquipmentItem {
  const EquipmentItem({
    required this.id,
    required this.name,
    required this.category,
    required this.condition,
    required this.location,
    required this.description,
    required this.purchaseDate,
    required this.amount,
    required this.billUrl,
    required this.billFileName,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String category;
  final String condition;
  final String location;
  final String description;
  final DateTime purchaseDate;
  final double amount;
  final String billUrl;
  final String billFileName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory EquipmentItem.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    return EquipmentItem(
      id: id,
      name: (data['name'] ?? '').toString(),
      category: (data['category'] ?? '').toString(),
      condition: (data['condition'] ?? 'Excellent').toString(),
      location: (data['location'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      purchaseDate: (data['purchaseDate'] as Timestamp?)?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      billUrl: (data['billUrl'] ?? '').toString(),
      billFileName: (data['billFileName'] ?? '').toString(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name.trim(),
      'category': category.trim(),
      'condition': condition.trim(),
      'location': location.trim(),
      'description': description.trim(),
      'purchaseDate': Timestamp.fromDate(purchaseDate),
      'amount': amount,
      'billUrl': billUrl.trim(),
      'billFileName': billFileName.trim(),
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  EquipmentItem copyWith({
    String? id,
    String? name,
    String? category,
    String? condition,
    String? location,
    String? description,
    DateTime? purchaseDate,
    double? amount,
    String? billUrl,
    String? billFileName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EquipmentItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      condition: condition ?? this.condition,
      location: location ?? this.location,
      description: description ?? this.description,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      amount: amount ?? this.amount,
      billUrl: billUrl ?? this.billUrl,
      billFileName: billFileName ?? this.billFileName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class EquipmentFormData {
  const EquipmentFormData({
    this.id,
    required this.name,
    required this.category,
    required this.condition,
    required this.location,
    required this.description,
    required this.purchaseDate,
    required this.amount,
    this.billImage,
    this.existingBillUrl = '',
    this.existingBillFileName = '',
  });

  final String? id;
  final String name;
  final String category;
  final String condition;
  final String location;
  final String description;
  final DateTime purchaseDate;
  final double amount;
  final PickedImageData? billImage;
  final String existingBillUrl;
  final String existingBillFileName;
}
