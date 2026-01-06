import 'package:cloud_firestore/cloud_firestore.dart';

class HttpsService {
  // Define your HTTPS service methods and properties here

  Future<void> fetchData() async {
    // Implement your data fetching logic here
    final db = FirebaseFirestore.instance;
    final docRef = db.collection("announcements").doc("RZoeyaObV56F5Ka0pZLT");
    docRef.get().then(
      (DocumentSnapshot doc) {
        final data = doc.data() as Map<String, dynamic>;
        print("<<object>> Data: ${data['name']}");
      },
      onError: (e) => print("Error getting document: $e"),
    );
  }
}
