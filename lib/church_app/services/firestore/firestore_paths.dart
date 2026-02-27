import 'package:cloud_firestore/cloud_firestore.dart';

class FirestorePaths {
  //Home Section paths
  static const homeSections = 'home_sections';
  //static const announcements = 'announcements';
  // static const events = 'events';
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
  // static const pastor = 'pastor';
  static const prayerRequests = 'prayer_requests';
  static DocumentReference aboutDoc(FirebaseFirestore firestore) {
    return firestore.collection(FirestorePaths.about).doc(FirestorePaths.main);
  }

  /// Users collection
  //static const users = 'users';
  static CollectionReference usersCollection(FirebaseFirestore firestore) {
    return firestore.collection(users);
  }

  /// Single user document
  static DocumentReference userDoc(FirebaseFirestore firestore, String uid) {
    return usersCollection(firestore).doc(uid);
  }

  // Root collections
  static const churches = 'churches';
  static const users = 'users';
  static const announcements = 'announcements';
  static const events = 'events';
  static const pastor = 'pastor';

  /// Church document
  static DocumentReference churchDoc(
      FirebaseFirestore firestore, String churchId) {
    return firestore.collection(churches).doc(churchId);
  }

  /// Users subcollection under church
  static CollectionReference churchUsers(
      FirebaseFirestore firestore, String churchId) {
    return churchDoc(firestore, churchId).collection(users);
  }

  /// announcements subcollection under church
  static CollectionReference churchAnnouncements(
      FirebaseFirestore firestore, String churchId) {
    return churchDoc(firestore, churchId).collection(announcements);
  }

  /// events subcollection under church
  static CollectionReference churchEvents(
      FirebaseFirestore firestore, String churchId) {
    return churchDoc(firestore, churchId).collection(events);
  }

  /// pastors subcollection under church
  static CollectionReference churchPastors(
      FirebaseFirestore firestore, String churchId) {
    return churchDoc(firestore, churchId).collection(pastor);
  }

  /// daily Article subcollection under church
  static CollectionReference churchDailyArticles(
      FirebaseFirestore firestore, String churchId) {
    return churchDoc(firestore, churchId).collection(articles);
  }

  /// church based config
  static DocumentReference<Map<String, dynamic>> churchAppConfig(
    FirebaseFirestore firestore,
    String churchId,
  ) {
    return firestore
        .collection('churches')
        .doc(churchId)
        .collection(config)
        .doc('app');
  }

  /// church based prayer
  static CollectionReference<Map<String, dynamic>> churchPrayerRequests(
    FirebaseFirestore firestore,
    String churchId,
  ) {
    return firestore
        .collection('churches')
        .doc(churchId)
        .collection(prayerRequests);
  }

  // church based about
  static DocumentReference<Map<String, dynamic>> churchAboutDoc(
    FirebaseFirestore firestore,
    String churchId,
  ) =>
      firestore
          .collection('churches')
          .doc(churchId)
          .collection('about')
          .doc('main');

  /// Single user document under church
  static DocumentReference churchUserDoc(
    FirebaseFirestore firestore,
    String churchId,
    String uid,
  ) {
    return churchUsers(firestore, churchId).doc(uid);
  }
}
