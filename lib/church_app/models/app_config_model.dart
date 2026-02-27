class AppConfig {
  final List<String> admins;
  final bool membersEnabled;
  final bool eventsEnabled;
  final bool bibleSwipeFetchEnabled;
  final int bibleSwipeFetchVersion;
  final String onboardingTitle;
  final String onboardingSubtitle;
  final String primaryColorHex;
  final String secondaryColorHex;
  final String backgroundColorHex;
  final String cardColorHex;
  final DailyVerseRef dailyVerseRef;
  final PromiseVerseRef promiseVerseRef;
  final PromptSheetModel promptSheet;

  const AppConfig({
    required this.admins,
    required this.membersEnabled,
    required this.eventsEnabled,
    required this.onboardingTitle,
    required this.onboardingSubtitle,
    required this.primaryColorHex,
    required this.secondaryColorHex,
    required this.backgroundColorHex,
    required this.cardColorHex,
    required this.dailyVerseRef,
    required this.promptSheet,
    required this.bibleSwipeFetchEnabled,
    required this.bibleSwipeFetchVersion,
    required this.promiseVerseRef
  });

  factory AppConfig.fromFirestore(Map<String, dynamic> data) {
    final features = data['features'] as Map<String, dynamic>? ?? {};
    return AppConfig(
      admins: List<String>.from(data['admins'] ?? []),
      dailyVerseRef:DailyVerseRef.fromMap(data['dailyVerse'] ?? {}),
      promiseVerseRef:PromiseVerseRef.fromMap(data['promiseWord'] ?? {}),
      promptSheet:PromptSheetModel.fromMap(data['promptSheet'] ?? {}),
      membersEnabled: data['features']?['membersEnabled'] ?? false,
      bibleSwipeFetchEnabled: data['features']?['bibleSwipeFetchEnabled'] ?? false,
      bibleSwipeFetchVersion: (features['bibleSwipeVersion'] as num?)?.toInt() ?? 0,
      eventsEnabled: data['features']?['eventsEnabled'] ?? false,
      onboardingTitle: data['onboarding']?['title'] ?? '',
      onboardingSubtitle: data['onboarding']?['subtitle'] ?? '',
      primaryColorHex: data['theme']?['primaryColor'] ?? '#000000',
      secondaryColorHex: data['theme']?['secondaryColor'] ?? '#000000',
      backgroundColorHex: data['theme']?['backgroundColor'] ?? '#000000',
      cardColorHex: data['theme']?['cardBackgroundColor'] ?? '#000000',
      //logoUrl: data['theme']?['logoUrl'] ?? '',
    );
  }

  bool isAdmin(String email) => admins.contains(email);
}


class DailyVerseRef {
  final String book;
  final int chapter;
  final int verse;

  DailyVerseRef({
    required this.book,
    required this.chapter,
    required this.verse,
  });

   factory DailyVerseRef.fromMap(Map<String, dynamic> map) {
    return DailyVerseRef(
      book: map['book'] as String,
      chapter: map['chapter'] as int,
      verse: map['verse'] as int,
    );
  }
}

class PromiseVerseRef {
  final String book;
  final int chapter;
  final int verse;

  PromiseVerseRef({
    required this.book,
    required this.chapter,
    required this.verse,
  });

   factory PromiseVerseRef.fromMap(Map<String, dynamic> map) {
    return PromiseVerseRef(
      book: map['book'] as String,
      chapter: map['chapter'] as int,
      verse: map['verse'] as int,
    );
  }
}

class PromptSheetModel {
  final String title;
  final String desc;
  final bool enabled;

  PromptSheetModel({
    required this.title,
    required this.desc,
    required this.enabled,
  });

   factory PromptSheetModel.fromMap(Map<String, dynamic> map) {
    return PromptSheetModel(
      title: map['title'] as String,
      desc: map['desc'] as String,
      enabled: map['enabled'] as bool,
    );
  }
}
