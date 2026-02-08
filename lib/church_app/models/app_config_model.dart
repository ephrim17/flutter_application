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
    required this.bibleSwipeFetchEnabled,
    required this.bibleSwipeFetchVersion
  });

  factory AppConfig.fromMap(Map<String, dynamic> data) {
    final features = data['features'] as Map<String, dynamic>? ?? {};
    return AppConfig(
      admins: List<String>.from(data['admins'] ?? []),
      dailyVerseRef:DailyVerseRef.fromMap(data['dailyVerse'] ?? {}),
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
