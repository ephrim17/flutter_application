import 'package:flutter_application/church_app/models/text_content_defaults.dart';

class AppConfig {
  final List<String> admins;
  final bool membersEnabled;
  final bool eventsEnabled;
  final bool dashboardEnabled;
  final bool financialDashboardEnabled;
  final bool equipmentEnabled;
  final bool studioEnabled;
  final bool globalFeedEnabled;
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
  final AdminModeModel adminMode;
  final bool superAdminDisabled;
  final TextContent textContent;
  final String churchLogo;
  final String youtubeLink;

  const AppConfig(
      {required this.admins,
      required this.membersEnabled,
      required this.eventsEnabled,
      required this.dashboardEnabled,
      required this.financialDashboardEnabled,
      required this.equipmentEnabled,
      required this.studioEnabled,
      required this.globalFeedEnabled,
      required this.onboardingTitle,
      required this.onboardingSubtitle,
      required this.primaryColorHex,
      required this.secondaryColorHex,
      required this.backgroundColorHex,
      required this.cardColorHex,
      required this.dailyVerseRef,
      required this.promptSheet,
      required this.adminMode,
      required this.superAdminDisabled,
      required this.bibleSwipeFetchEnabled,
      required this.bibleSwipeFetchVersion,
      required this.promiseVerseRef,
      required this.textContent,
      required this.churchLogo,
      required this.youtubeLink});

  factory AppConfig.fallback() {
    return AppConfig(
      admins: const [],
      membersEnabled: false,
      eventsEnabled: false,
      dashboardEnabled: false,
      financialDashboardEnabled: false,
      equipmentEnabled: false,
      studioEnabled: false,
      globalFeedEnabled: false,
      onboardingTitle: '',
      onboardingSubtitle: '',
      primaryColorHex: '#000000',
      secondaryColorHex: '#000000',
      backgroundColorHex: '#FFFFFF',
      cardColorHex: '#FFFFFF',
      dailyVerseRef: DailyVerseRef.empty(),
      promptSheet: PromptSheetModel.empty(),
      adminMode: AdminModeModel.empty(),
      superAdminDisabled: false,
      bibleSwipeFetchEnabled: false,
      bibleSwipeFetchVersion: 0,
      promiseVerseRef: PromiseVerseRef.empty(),
      textContent: TextContent.fromMap(null),
      churchLogo: '',
      youtubeLink: '',
    );
  }

  factory AppConfig.fromFirestore(Map<String, dynamic> data) {
    final features = data['features'] as Map<String, dynamic>? ?? {};
    return AppConfig(
      admins: List<String>.from(data['admins'] ?? []),
      dailyVerseRef: DailyVerseRef.fromMap(data['dailyVerse'] ?? {}),
      promiseVerseRef: PromiseVerseRef.fromMap(data['promiseWord'] ?? {}),
      promptSheet: PromptSheetModel.fromMap(data['promptSheet'] ?? {}),
      adminMode: AdminModeModel.fromMap(data['adminMode'] ?? {}),
      superAdminDisabled: data['superAdminDisabled'] as bool? ?? false,
      membersEnabled: data['features']?['membersEnabled'] ?? false,
      dashboardEnabled: data['features']?['dashboardEnabled'] ?? false,
      financialDashboardEnabled:
          features['financialDashboardEnabled'] as bool? ?? false,
      equipmentEnabled: features['equipmentEnabled'] as bool? ?? false,
      studioEnabled: features['studioEnabled'] as bool? ?? true,
      globalFeedEnabled: data['features']?['globalFeedEnabled'] ?? false,
      bibleSwipeFetchEnabled:
          data['features']?['bibleSwipeFetchEnabled'] ?? false,
      bibleSwipeFetchVersion:
          (features['bibleSwipeVersion'] as num?)?.toInt() ?? 0,
      eventsEnabled: data['features']?['eventsEnabled'] ?? false,
      onboardingTitle: data['onboarding']?['title'] ?? '',
      onboardingSubtitle: data['onboarding']?['subtitle'] ?? '',
      textContent:
          TextContent.fromMap(data['textContent'] as Map<String, dynamic>?),
      primaryColorHex: data['theme']?['primaryColor'] ?? '#000000',
      secondaryColorHex: data['theme']?['secondaryColor'] ?? '#000000',
      backgroundColorHex: data['theme']?['backgroundColor'] ?? '#000000',
      cardColorHex: data['theme']?['cardBackgroundColor'] ?? '#000000',
      churchLogo: data['churchLogo'] ?? "",
      youtubeLink: data['youtubeLink'] ?? "",
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

  factory DailyVerseRef.empty() {
    return DailyVerseRef(
      book: '',
      chapter: 0,
      verse: 0,
    );
  }

  factory DailyVerseRef.fromMap(Map<String, dynamic> map) {
    return DailyVerseRef(
      book: (map['book'] ?? '') as String,
      chapter: (map['chapter'] as num?)?.toInt() ?? 0,
      verse: (map['verse'] as num?)?.toInt() ?? 0,
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

  factory PromiseVerseRef.empty() {
    return PromiseVerseRef(
      book: '',
      chapter: 0,
      verse: 0,
    );
  }

  factory PromiseVerseRef.fromMap(Map<String, dynamic> map) {
    return PromiseVerseRef(
      book: (map['book'] ?? '') as String,
      chapter: (map['chapter'] as num?)?.toInt() ?? 0,
      verse: (map['verse'] as num?)?.toInt() ?? 0,
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

  factory PromptSheetModel.empty() {
    return PromptSheetModel(
      title: '',
      desc: '',
      enabled: false,
    );
  }

  factory PromptSheetModel.fromMap(Map<String, dynamic> map) {
    return PromptSheetModel(
      title: (map['title'] ?? '') as String,
      desc: (map['desc'] ?? '') as String,
      enabled: map['enabled'] as bool? ?? false,
    );
  }
}

class AdminModeModel {
  final bool enabled;

  const AdminModeModel({
    required this.enabled,
  });

  factory AdminModeModel.empty() {
    return const AdminModeModel(
      enabled: false,
    );
  }

  factory AdminModeModel.fromMap(Map<String, dynamic> map) {
    return AdminModeModel(
      enabled: map['enabled'] as bool? ?? false,
    );
  }
}

class TextContent {
  final Map<String, String> _values;

  const TextContent(this._values);

  factory TextContent.fromMap(Map<String, dynamic>? map) {
    final values = <String, String>{
      ...preAuthDefaultTextContents,
      ...defaultChurchTextContents,
    };
    if (map != null) {
      map.forEach((key, value) {
        if (value is String && value.trim().isNotEmpty) {
          values[key] = value;
        }
      });
    }
    return TextContent(values);
  }

  String get(String key, {required String fallback}) {
    return _values[key] ?? fallback;
  }
}
