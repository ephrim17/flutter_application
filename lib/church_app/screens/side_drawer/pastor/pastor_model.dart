import 'package:cloud_firestore/cloud_firestore.dart';

class Pastor {
  final String id; // docId
  final String title;
  final String contact;
  final String imageUrl;
  final bool primary;

  const Pastor({
    required this.id,
    required this.title,
    required this.contact,
    required this.imageUrl,
    required this.primary,
  });

  Pastor copyWith({
    String? id,
    String? title,
    String? contact,
    String? imageUrl,
    bool? primary,
  }) {
    return Pastor(
      id: id ?? this.id,
      title: title ?? this.title,
      contact: contact ?? this.contact,
      imageUrl: imageUrl ?? this.imageUrl,
      primary: primary ?? this.primary,
    );
  }

  /// For writing to Firestore (id is not stored inside fields)
  Map<String, dynamic> toMap() => {
        'title': title,
        'contact': contact,
        'imageUrl': imageUrl,
        'primary': primary,
      };

  /// For reading from Firestore
  static Pastor fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};

    return Pastor(
      id: doc.id,
      title: (data['title'] ?? '') as String,
      contact: (data['contact'] ?? '') as String,
      imageUrl: (data['imageUrl'] ?? '') as String,
      primary: data['primary'] as bool? ?? false,
    );
  }
}
