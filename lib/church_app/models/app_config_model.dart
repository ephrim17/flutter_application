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
    final features = _stringMap(data['features']);
    final onboarding = _stringMap(data['onboarding']);
    final theme = _stringMap(data['theme']);
    return AppConfig(
      admins: (data['admins'] as Iterable? ?? const [])
          .map((value) => value.toString().trim().toLowerCase())
          .where((value) => value.isNotEmpty)
          .toList(growable: false),
      dailyVerseRef: DailyVerseRef.fromMap(_stringMap(data['dailyVerse'])),
      promiseVerseRef: PromiseVerseRef.fromMap(_stringMap(data['promiseWord'])),
      promptSheet: PromptSheetModel.fromMap(_stringMap(data['promptSheet'])),
      adminMode: AdminModeModel.fromMap(_stringMap(data['adminMode'])),
      superAdminDisabled: data['superAdminDisabled'] == true,
      membersEnabled: features['membersEnabled'] == true,
      dashboardEnabled: features['dashboardEnabled'] == true,
      // Retain the field for stored-config compatibility, but keep the
      // unfinished dashboard disabled until a future release.
      financialDashboardEnabled: false,
      equipmentEnabled: features['equipmentEnabled'] == true,
      studioEnabled: features['studioEnabled'] != false,
      globalFeedEnabled: features['globalFeedEnabled'] == true,
      bibleSwipeFetchEnabled: features['bibleSwipeFetchEnabled'] == true,
      bibleSwipeFetchVersion:
          (features['bibleSwipeVersion'] as num?)?.toInt() ?? 0,
      eventsEnabled: features['eventsEnabled'] == true,
      onboardingTitle: _string(onboarding['title']),
      onboardingSubtitle: _string(onboarding['subtitle']),
      textContent: TextContent.fromMap(_stringMapOrNull(data['textContent'])),
      primaryColorHex: _string(theme['primaryColor'], fallback: '#000000'),
      secondaryColorHex: _string(theme['secondaryColor'], fallback: '#000000'),
      backgroundColorHex:
          _string(theme['backgroundColor'], fallback: '#FFFFFF'),
      cardColorHex: _string(theme['cardBackgroundColor'], fallback: '#FFFFFF'),
      churchLogo: _string(data['churchLogo']),
      youtubeLink: _string(data['youtubeLink']),
      //logoUrl: data['theme']?['logoUrl'] ?? '',
    );
  }

  bool isAdmin(String email) => admins.contains(email);
}

Map<String, dynamic> _stringMap(dynamic value) {
  if (value is! Map) return <String, dynamic>{};
  return value.map((key, item) => MapEntry(key.toString(), item));
}

Map<String, dynamic>? _stringMapOrNull(dynamic value) {
  if (value is! Map) return null;
  return _stringMap(value);
}

String _string(dynamic value, {String fallback = ''}) {
  final result = value?.toString().trim() ?? '';
  return result.isEmpty ? fallback : result;
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
      book: _string(map['book']),
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
      book: _string(map['book']),
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
      title: _string(map['title']),
      desc: _string(map['desc']),
      enabled: map['enabled'] == true,
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
      enabled: map['enabled'] == true,
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

  String get(
    String key, {
    String? fallback,
    Map<String, Object?> parameters = const {},
  }) {
    var value = _values[key] ?? fallback ?? key;
    parameters.forEach((name, replacement) {
      value = value.replaceAll('{$name}', replacement?.toString() ?? '');
    });
    return value;
  }
}
