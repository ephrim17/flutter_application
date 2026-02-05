class AppConfig {
  final List<String> admins;
  final bool membersEnabled;
  final bool eventsEnabled;
  final String onboardingTitle;
  final String onboardingSubtitle;
  final String primaryColorHex;
  final DailyVerseRef dailyVerseRef;
  //final String logoUrl;

  const AppConfig({
    required this.admins,
    required this.membersEnabled,
    required this.eventsEnabled,
    required this.onboardingTitle,
    required this.onboardingSubtitle,
    required this.primaryColorHex,
    required this.dailyVerseRef,
    //required this.logoUrl,
  });

  factory AppConfig.fromMap(Map<String, dynamic> data) {
    return AppConfig(
      admins: List<String>.from(data['admins'] ?? []),
      dailyVerseRef:DailyVerseRef.fromMap(data['dailyVerse'] ?? {}),
      membersEnabled: data['features']?['membersEnabled'] ?? false,
      eventsEnabled: data['features']?['eventsEnabled'] ?? false,
      onboardingTitle: data['onboarding']?['title'] ?? '',
      onboardingSubtitle: data['onboarding']?['subtitle'] ?? '',
      primaryColorHex: data['theme']?['primaryColor'] ?? '#000000',
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
