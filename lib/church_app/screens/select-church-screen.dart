// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_application/church_app/screens/entry/login_entry_screen.dart';

// class SelectChurchScreen extends StatelessWidget {
//   const SelectChurchScreen({super.key});

//   @override
//   Widget build(BuildContext context) {
//     final churchesStream = FirebaseFirestore.instance
//         .collection('churches')
//         .where('enabled', isEqualTo: true)
//         .snapshots();

//     return Scaffold(
//       appBar: AppBar(title: const Text("Select Church")),
//       body: StreamBuilder<QuerySnapshot>(
//         stream: churchesStream,
//         builder: (context, snapshot) {
//           if (snapshot.connectionState == ConnectionState.waiting) {
//             return const Center(child: CircularProgressIndicator());
//           }

//           if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
//             return const Center(child: Text("No churches available"));
//           }

//           final churches = snapshot.data!.docs;

//           return ListView.builder(
//             padding: const EdgeInsets.all(16),
//             itemCount: churches.length,
//             itemBuilder: (context, index) {
//               final doc = churches[index];
//               final churchName = doc['name'];
//               final churchId = doc.id;

//               return Card(
//                 child: ListTile(
//                   leading: const Icon(Icons.church),
//                   title: Text(churchName),
//                   trailing: const Icon(Icons.arrow_forward_ios, size: 16),
//                   onTap: () {
//                     Navigator.push(
//                       context,
//                       MaterialPageRoute(
//                         builder: (_) => LoginScreen(
//                           churchId: churchId,
//                           churchName: churchName,
//                         ),
//                       ),
//                     );
//                   },
//                 ),
//               );
//             },
//           );
//         },
//       ),
//     );
//   }
// }