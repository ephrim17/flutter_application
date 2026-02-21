import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application/church_app/models/onboarding_model.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final onboardingProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('onboarding_completed') ?? false;
});

final onboardingPagesProvider =
    StreamProvider<List<OnboardingModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('onBoarding')
      //.where('isActive', isEqualTo: true)
      .snapshots()
      .map((snapshot) {
        print("🔥 Docs length: ${snapshot.docs.length}");
        return snapshot.docs
            .map((doc) => OnboardingModel.fromFirestore(doc))
            .toList();
      });
});