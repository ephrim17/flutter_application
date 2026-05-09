import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_application/church_app/models/onboarding_model.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final onboardingProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('onboarding_completed') ?? false;
});

final onboardingPagesProvider =
    FutureProvider<List<OnboardingModel>>((ref) async {
  try {
    final snapshot =
        await FirebaseFirestore.instance.collection('onBoarding').get();
    final pages = snapshot.docs
        .map((doc) => OnboardingModel.fromFirestore(doc))
        .where((page) => page.isActive)
        .toList();

    return pages.isEmpty ? _defaultOnboardingPages : pages;
  } on FirebaseException catch (error) {
    if (error.code != 'permission-denied') rethrow;
    debugPrint('Using default onboarding pages: ${error.message}');
    return _defaultOnboardingPages;
  }
});

final _defaultOnboardingPages = [
  OnboardingModel(
    id: 'daily-word',
    title: 'Daily Word',
    description:
        'Begin each day with scripture, reflections, and encouragement from your church.',
    imageUrl: '',
    isActive: true,
  ),
  OnboardingModel(
    id: 'church-events',
    title: 'Church Events',
    description:
        'Stay connected with services, gatherings, announcements, and upcoming events.',
    imageUrl: '',
    isActive: true,
  ),
  OnboardingModel(
    id: 'community',
    title: 'Church Community',
    description:
        'Find your church family, prayer updates, groups, and ways to grow together.',
    imageUrl: '',
    isActive: true,
  ),
];
