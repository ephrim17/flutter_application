import 'package:cloud_firestore/cloud_firestore.dart';

class Pastor {
  final String id; // docId
  final String title;
  final String contact;

  const Pastor({
    required this.id,
    required this.title,
    required this.contact,
  });

  Pastor copyWith({
    String? id,
    String? title,
    String? contact,
  }) {
    return Pastor(
      id: id ?? this.id,
      title: title ?? this.title,
      contact: contact ?? this.contact,
    );
  }

  /// For writing to Firestore (id is not stored inside fields)
  Map<String, dynamic> toMap() => {
        'title': title,
        'contact': contact
      };

  /// For reading from Firestore
  static Pastor fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};

    return Pastor(
      id: doc.id,
      title: (data['title'] ?? '') as String,
      contact: (data['contact'] ?? '') as String,
    );
  }
}
