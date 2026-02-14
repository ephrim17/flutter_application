import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_authentication.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


Future<void> updateUserTokenIfNeeded(WidgetRef ref) async {
  final alreadyUpdated = ref.read(tokenUpdatedProvider);
  if (alreadyUpdated) return;

  ref.read(tokenUpdatedProvider.notifier).state = true;

  final token = "";
  if (token == null) return;

  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final doc = await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .get();

  final currentToken = doc.data()?['authToken'];

  if (currentToken != token) {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .update({'authToken': token});
  }
}
