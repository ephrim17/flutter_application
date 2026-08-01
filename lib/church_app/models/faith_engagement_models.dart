import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? _date(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

String _text(dynamic value) => value?.toString().trim() ?? '';

int _integer(dynamic value) =>
    value is num ? value.toInt() : int.tryParse(_text(value)) ?? 0;

({String book, int chapter, int startVerse, int endVerse})?
    _parseScriptureReference(String value) {
  final match = RegExp(r'^(.+?)\s+(\d+):(\d+)(?:-(\d+))?$').firstMatch(value);
  if (match == null) return null;
  final chapter = int.tryParse(match.group(2) ?? '');
  final start = int.tryParse(match.group(3) ?? '');
  final end = int.tryParse(match.group(4) ?? '') ?? start;
  if (chapter == null || start == null || end == null) return null;
  return (
    book: match.group(1)?.trim() ?? '',
    chapter: chapter,
    startVerse: start,
    endVerse: end,
  );
}

class YouthCircle {
  const YouthCircle({
    required this.id,
    required this.title,
    required this.description,
    required this.audienceGroupId,
    required this.enabled,
    required this.order,
  });

  final String id;
  final String title;
  final String description;
  final String audienceGroupId;
  final bool enabled;
  final int order;

  bool isVisibleTo(Iterable<String> groupIds) =>
      audienceGroupId.isNotEmpty && groupIds.contains(audienceGroupId);

  factory YouthCircle.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return YouthCircle(
      id: doc.id,
      title: _text(data['title']),
      description: _text(data['description']),
      audienceGroupId: _text(data['audienceGroupId']),
      enabled: data['enabled'] != false,
      order: data['order'] is num
          ? (data['order'] as num).toInt()
          : int.tryParse(_text(data['order'])) ?? 100,
    );
  }
}

class QuizQuestion {
  const QuizQuestion({
    required this.prompt,
    required this.options,
    required this.correctOptionIndex,
  });

  final String prompt;
  final List<String> options;
  final int correctOptionIndex;

  bool get isValid =>
      prompt.isNotEmpty &&
      options.length >= 2 &&
      options.every((option) => option.isNotEmpty) &&
      correctOptionIndex >= 0 &&
      correctOptionIndex < options.length;

  factory QuizQuestion.fromMap(Map<String, dynamic> data) => QuizQuestion(
        prompt: _text(data['prompt']),
        options: data['options'] is Iterable
            ? (data['options'] as Iterable)
                .map(_text)
                .where((option) => option.isNotEmpty)
                .toList(growable: false)
            : const [],
        correctOptionIndex: _integer(data['correctOptionIndex']),
      );
}

class QuizChallenge {
  const QuizChallenge({
    required this.id,
    required this.title,
    required this.description,
    required this.questions,
    required this.startAt,
    required this.endAt,
    required this.enabled,
  });

  final String id;
  final String title;
  final String description;
  final List<QuizQuestion> questions;
  final DateTime? startAt;
  final DateTime? endAt;
  final bool enabled;

  bool get isConfigured =>
      title.isNotEmpty &&
      questions.isNotEmpty &&
      questions.every((q) => q.isValid);

  bool isActiveAt(DateTime now) {
    if (!enabled) return false;
    if (startAt != null && startAt!.isAfter(now)) return false;
    if (endAt != null && endAt!.isBefore(now)) return false;
    return true;
  }

  factory QuizChallenge.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final rawQuestions = data['questions'];
    return QuizChallenge(
      id: doc.id,
      title: _text(data['title']),
      description: _text(data['description']),
      questions: rawQuestions is Iterable
          ? rawQuestions
              .whereType<Map>()
              .map(
                (question) => QuizQuestion.fromMap(
                  Map<String, dynamic>.from(question),
                ),
              )
              .where((question) => question.isValid)
              .toList(growable: false)
          : const [],
      startAt: _date(data['startAt']),
      endAt: _date(data['endAt']),
      enabled: data['enabled'] != false,
    );
  }
}

class QuizAttempt {
  const QuizAttempt({
    required this.answers,
    required this.score,
    required this.total,
  });

  final List<int> answers;
  final int score;
  final int total;

  bool get isValid => total > 0 && answers.length == total;

  factory QuizAttempt.fromMap(Map<String, dynamic>? data) => QuizAttempt(
        answers: data?['answers'] is Iterable
            ? (data!['answers'] as Iterable)
                .map(_integer)
                .toList(growable: false)
            : const [],
        score: _integer(data?['score']),
        total: _integer(data?['total']),
      );
}

class FaithReflection {
  const FaithReflection({
    required this.id,
    required this.title,
    required this.body,
    this.scriptureBook = '',
    this.scriptureChapter = 0,
    this.scriptureStartVerse = 0,
    this.scriptureEndVerse = 0,
    this.prayerPoints = const [],
    this.liveItOut = '',
    required this.activeDate,
    required this.enabled,
  });

  final String id;
  final String title;
  final String body;
  final String scriptureBook;
  final int scriptureChapter;
  final int scriptureStartVerse;
  final int scriptureEndVerse;
  final List<String> prayerPoints;
  final String liveItOut;
  final DateTime? activeDate;
  final bool enabled;

  bool get hasScripture =>
      scriptureBook.isNotEmpty &&
      scriptureChapter > 0 &&
      scriptureStartVerse > 0 &&
      scriptureEndVerse >= scriptureStartVerse;

  String get scriptureReference {
    if (!hasScripture) return '';
    final verses = scriptureStartVerse == scriptureEndVerse
        ? '$scriptureStartVerse'
        : '$scriptureStartVerse-$scriptureEndVerse';
    return '$scriptureBook $scriptureChapter:$verses';
  }

  bool isForDay(DateTime day) {
    if (!enabled || activeDate == null) return false;
    return activeDate!.year == day.year &&
        activeDate!.month == day.month &&
        activeDate!.day == day.day;
  }

  factory FaithReflection.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final legacy = _parseScriptureReference(
      _text(data['scriptureReference']),
    );
    final scriptureBook = _text(data['scriptureBook']);
    final scriptureChapter = _integer(data['scriptureChapter']);
    final scriptureStartVerse = _integer(data['scriptureStartVerse']);
    final scriptureEndVerse = _integer(data['scriptureEndVerse']);
    return FaithReflection(
      id: doc.id,
      title: _text(data['title']),
      body: _text(data['body']),
      scriptureBook:
          scriptureBook.isNotEmpty ? scriptureBook : legacy?.book ?? '',
      scriptureChapter:
          scriptureChapter > 0 ? scriptureChapter : legacy?.chapter ?? 0,
      scriptureStartVerse: scriptureStartVerse > 0
          ? scriptureStartVerse
          : legacy?.startVerse ?? 0,
      scriptureEndVerse:
          scriptureEndVerse > 0 ? scriptureEndVerse : legacy?.endVerse ?? 0,
      prayerPoints: switch (data['prayerPoints']) {
        final Iterable values => values
            .map(_text)
            .where((item) => item.isNotEmpty)
            .toList(growable: false),
        final String value => value
            .split('\n')
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList(growable: false),
        _ => const [],
      },
      liveItOut: _text(data['liveItOut']),
      activeDate: _date(data['activeDate']),
      enabled: data['enabled'] != false,
    );
  }
}

class CircleResponse {
  const CircleResponse({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userPhotoUrl,
    required this.message,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String userName;
  final String userPhotoUrl;
  final String message;
  final DateTime? createdAt;

  factory CircleResponse.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return CircleResponse(
      id: doc.id,
      userId: _text(data['userId']),
      userName: _text(data['userName']),
      userPhotoUrl: _text(data['userPhotoUrl']),
      message: _text(data['message']),
      createdAt: _date(data['createdAt']),
    );
  }
}

class DailyFaithProgress {
  const DailyFaithProgress({required this.completedSteps});

  final Set<String> completedSteps;

  bool get isComplete =>
      const {'reflect', 'pray', 'challenge'}.every(completedSteps.contains);

  factory DailyFaithProgress.fromMap(Map<String, dynamic>? data) {
    final raw = data?['completedSteps'];
    return DailyFaithProgress(
      completedSteps: raw is Iterable
          ? raw.map((item) => item.toString()).toSet()
          : <String>{},
    );
  }
}
