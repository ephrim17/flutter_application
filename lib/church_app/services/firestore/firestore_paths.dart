import 'package:cloud_firestore/cloud_firestore.dart';

class FirestorePaths {
  // Root collections
  static const config = 'config';
  static const main = 'main';
  static const churches = 'churches';
  static const users = 'users';

  //Section paths
  static const homeSections = 'home_sections';
  static CollectionReference<Map<String, dynamic>> churchHomeSections(
    FirebaseFirestore firestore,
    String churchId,
  ) {
    return firestore
        .collection('churches')
        .doc(churchId)
        .collection('home_sections');
  }

  static const forYouSection = 'for_you_section';
  static CollectionReference<Map<String, dynamic>> churchForYouSections(
    FirebaseFirestore firestore,
    String churchId,
  ) {
    return firestore
        .collection('churches')
        .doc(churchId)
        .collection(forYouSection);
  }

  // Footer support paths
  static const footerSupport = 'footerSupport';
  static const contactsDoc = 'contacts';
  static const contactItemsCollection = 'contactItems';
  static const socialDoc = 'social';
  static const socialItemsCollection = 'socialItems';

  static const about = 'about';
  static const prayerRequests = 'prayer_requests';
  static const articles = 'articles';
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
          .collection(about)
          .doc(main);

  // church based footer support
  static CollectionReference<Map<String, dynamic>> churchContactItems(
    FirebaseFirestore firestore,
    String churchId,
  ) {
    return firestore
        .collection('churches')
        .doc(churchId)
        .collection(FirestorePaths.footerSupport)
        .doc(FirestorePaths.contactsDoc)
        .collection(FirestorePaths.contactItemsCollection);
  }

  static CollectionReference<Map<String, dynamic>> churchSocialItems(
    FirebaseFirestore firestore,
    String churchId,
  ) {
    return firestore
        .collection('churches')
        .doc(churchId)
        .collection(FirestorePaths.footerSupport)
        .doc(FirestorePaths.socialDoc)
        .collection(FirestorePaths.socialItemsCollection);
  }

  static CollectionReference<Map<String, dynamic>> churchUserReadingPlans(
    FirebaseFirestore firestore,
    String churchId,
    String uid,
  ) {
    return firestore
        .collection('churches')
        .doc(churchId)
        .collection(users)
        .doc(uid)
        .collection(readingPlans);
  }

  // User readingPlans subcollection
  static const readingPlans = 'readingPlans';
  static CollectionReference userReadingPlans(
      FirebaseFirestore firestore, String uid) {
    return userDoc(firestore, uid).collection(readingPlans);
  }

  static CollectionReference usersCollection(FirebaseFirestore firestore) {
    return firestore.collection(users);
  }

  /// Single user document
  static DocumentReference userDoc(FirebaseFirestore firestore, String uid) {
    return usersCollection(firestore).doc(uid);
  }

  /// Bible swipe
  static const bibleRandomSwipeVerses = 'bibleRandomSwipeVerses';
  static const swipeVersesDoc = 'swipeVerses';
  static DocumentReference<Map<String, dynamic>> churchBibleRandomSwipeDoc(
    FirebaseFirestore firestore,
    String churchId,
  ) {
    return firestore
        .collection('churches')
        .doc(churchId)
        .collection(bibleRandomSwipeVerses)
        .doc(swipeVersesDoc);
  }

  /// Single user document under church
  static DocumentReference churchUserDoc(
    FirebaseFirestore firestore,
    String churchId,
    String uid,
  ) {
    return churchUsers(firestore, churchId).doc(uid);
  }

  /// feeds under church
  static CollectionReference feedCollection(
    FirebaseFirestore firestore,
    String churchId,
  ) {
    return firestore
        .collection('churches')
        .doc(churchId)
        .collection('feeds');
  } 
}
