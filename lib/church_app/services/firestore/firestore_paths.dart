import 'package:cloud_firestore/cloud_firestore.dart';

class FirestorePaths {
  //Home Section paths
  static const homeSections = 'home_sections';
  static const announcements = 'announcements';
  static const events = 'events';
  static const config = 'config';
  static const main = 'main';

  static String userPath(String uid) => 'users/$uid';

  // Footer support paths
  static const footerSupport = 'footerSupport';
  static const contactsDoc = 'contacts';
  static const contactItemsCollection = 'contactItems';
  static const socialDoc = 'social';
  static const socialItemsCollection = 'socialItems';
  static CollectionReference contactItems(FirebaseFirestore firestore) =>
      firestore
          .collection(FirestorePaths.footerSupport)
          .doc(FirestorePaths.contactsDoc)
          .collection(FirestorePaths.contactItemsCollection);
  static CollectionReference socialItems(FirebaseFirestore firestore) =>
      firestore
          .collection(FirestorePaths.footerSupport)
          .doc(FirestorePaths.socialDoc)
          .collection(FirestorePaths.socialItemsCollection);

  // For You Section paths
  static const forYouSection = 'for_you_section';
  static const articles = 'articles';
  static const bibleRandomSwipeVerses = 'bibleRandomSwipeVerses';
  static const swipeVersesDoc = 'swipeVerses';
  static DocumentReference bibleRandomSwipeDoc(FirebaseFirestore firestore) {
    return firestore
        .collection(FirestorePaths.bibleRandomSwipeVerses)
        .doc(FirestorePaths.swipeVersesDoc);
  }
  // User readingPlans subcollection
  static const readingPlans = 'readingPlans';
  static CollectionReference userReadingPlans(
      FirebaseFirestore firestore, String uid) {
    return userDoc(firestore, uid).collection(readingPlans);
  }

  // Side drawer paths
  static const about = 'about';
  static const pastor = 'pastor';
  static const prayerRequests = 'prayer_requests';
  static DocumentReference aboutDoc(FirebaseFirestore firestore) {
    return firestore.collection(FirestorePaths.about).doc(FirestorePaths.main);
  }

  /// Users collection
  static const users = 'users';
  static CollectionReference usersCollection(FirebaseFirestore firestore) {
    return firestore.collection(users);
  }

  /// Single user document
  static DocumentReference userDoc(FirebaseFirestore firestore, String uid) {
    return usersCollection(firestore).doc(uid);
  }
}
