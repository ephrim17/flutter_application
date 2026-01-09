import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application/shopping_list_app/model/categories_data.dart';
import 'package:flutter_application/shopping_list_app/model/grocery_model.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class HttpsService {
  // Define your HTTPS service methods and properties here

  Future<void> fetchData() async {
    // Implement your data fetching logic here
    final db = FirebaseFirestore.instance;
    final docRef = db.collection("announcements").doc("RZoeyaObV56F5Ka0pZLT");
    docRef.get().then(
      (DocumentSnapshot doc) {
        final data = doc.data() as Map<String, dynamic>;
        print("<<object>> Data: ${data['body']}");
      },
      onError: (e) => print("Error getting document: $e"),
    );
  }

  Future<void> postSample() async {

  const url =
      'https://firestore.googleapis.com/v1/projects/flutterlearning-c9f6c/databases/(default)/documents/announcements';

  final response = await http.post(
    Uri.parse(url),
    headers: {
      'Content-Type': 'application/json',
      // Uncomment if auth is required
      // 'Authorization': 'Bearer YOUR_FIREBASE_ID_TOKEN',
    },
    body: jsonEncode({
      "fields": {
        "title": {"stringValue": "Sunday Service"},
        "body": {"stringValue": "Service starts at 9 AM"},
        "priority": {"integerValue": "5"}, // must be string
        "isPinned": {"booleanValue": true},
        "isActive": {"booleanValue": true},
        "startAt": {"timestampValue": "2025-01-01T04:00:00Z"},
        "endAt": {"timestampValue": "2100-01-01T00:00:00Z"},
        "createdAt": {"timestampValue": "2025-01-01T04:00:00Z"},
        "updatedAt": {"timestampValue": "2025-01-01T04:00:00Z"}
      }
    }),
  );

  print('Status: ${response.statusCode}');
  print('Response: ${response.body}');

  if (response.statusCode == 200) {
    print("Posted Successfully");
  } else {
    throw Exception('Post failed');
  }
}

  Future<List<Map<String, dynamic>>> getSample() async {
    const url =
        'https://firestore.googleapis.com/v1/projects/flutterlearning-c9f6c/databases/(default)/documents/announcements';

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        // Uncomment if auth is required
        // 'Authorization': 'Bearer YOUR_FIREBASE_ID_TOKEN',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to fetch announcements: ${response.statusCode} ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final documents = decoded['documents'] as List<dynamic>? ?? [];

    // Convert Firestore typed fields → simple map
    return documents.map<Map<String, dynamic>>((doc) {
      final fields = doc['fields'] as Map<String, dynamic>;

      dynamic parseValue(Map<String, dynamic> value) {
        if (value.containsKey('stringValue')) return value['stringValue'];
        if (value.containsKey('booleanValue')) return value['booleanValue'];
        if (value.containsKey('integerValue')) {
          return int.parse(value['integerValue']);
        }
        if (value.containsKey('timestampValue')) {
          return DateTime.parse(value['timestampValue']);
        }
        return null;
      }

      return {
        'id': (doc['name'] as String).split('/').last,
        for (final entry in fields.entries) entry.key: parseValue(entry.value),
      };
    }).toList();
  }

  Future<void> addShoppingList(GroceryItem newItem) async {
    const url =
        'https://firestore.googleapis.com/v1/projects/flutterlearning-c9f6c/databases/(default)/documents/shoppingList';

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        // Uncomment if auth is required
        // 'Authorization': 'Bearer YOUR_FIREBASE_ID_TOKEN',
      },
      body: jsonEncode({
        "fields": {
          "id": {"stringValue": newItem.id},
          "item": {"stringValue": newItem.name},
          "quantity": {"stringValue": newItem.quantity.toString()},
          "category": {"stringValue": newItem.category.name}
        }
      }),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      print("Added Item Successfull");
    } else {
      throw Exception('Post failed');
    }
  }

  Future<List<GroceryItem>> getGroceryItems() async {
  const url =
      'https://firestore.googleapis.com/v1/projects/flutterlearning-c9f6c/databases/(default)/documents/shoppingList';

  final response = await http.get(
    Uri.parse(url),
    headers: {'Content-Type': 'application/json'},
  );

  if (response.statusCode != 200) {
    throw Exception('Failed: ${response.statusCode}');
  }

  final decoded = jsonDecode(response.body) as Map<String, dynamic>;
  final documents = decoded['documents'] as List<dynamic>? ?? [];

  //helper function for string
  String? string(dynamic v) =>
      v is Map<String, dynamic> ? v['stringValue']?.toString() : null;

  //helper function for int
  int? _int(dynamic v) {
    if (v is! Map<String, dynamic>) return null;
    if (v.containsKey('integerValue')) {
      return int.tryParse(v['integerValue'].toString());
    }
    if (v.containsKey('stringValue')) {
      return int.tryParse(v['stringValue'].toString());
    }
    return null;
  }

  final List<GroceryItem> items = [];

  for (final d in documents) {
    if (d is! Map<String, dynamic>) continue;

    final fields = d['fields'];
    if (fields is! Map<String, dynamic>) continue;

    final id = (d['name'] as String).split('/').last;

    final name = string(fields['item']);          //via helper functions
    final quantity = _int(fields['quantity']);     //via helper functions
    final categoryName = string(fields['category']);

    if (name == null || quantity == null || categoryName == null) {
      continue;
    }

    final category = categories.entries
        .firstWhere((e) => e.value.name == categoryName)
        .value;

    items.add(GroceryItem(
      id: id,
      name: name,
      quantity: quantity,
      category: category,
    ));
  }

  return items;
}

}