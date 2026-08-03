import 'package:cloud_firestore/cloud_firestore.dart';

String _learningText(Object? value) => value?.toString().trim() ?? '';

int _learningInt(Object? value, [int fallback = 0]) => value is num
    ? value.toInt()
    : int.tryParse(_learningText(value)) ?? fallback;

bool learningQuizPasses({
  required int score,
  required int total,
  required int passingPercentage,
}) =>
    total > 0 && score / total * 100 >= passingPercentage;

enum LearningResourceType { pdf, image, youtube, externalLink }

class LearningResource {
  const LearningResource({
    required this.name,
    required this.downloadUrl,
    required this.storagePath,
    this.type = LearningResourceType.pdf,
    this.order = 100,
  });

  final String name;
  final String downloadUrl;
  final String storagePath;
  final LearningResourceType type;
  final int order;

  LearningResource withOrder(int value) => LearningResource(
        name: name,
        downloadUrl: downloadUrl,
        storagePath: storagePath,
        type: type,
        order: value,
      );

  factory LearningResource.fromMap(Map<String, dynamic> data) =>
      LearningResource(
        name: _learningText(data['name']),
        downloadUrl: _learningText(data['downloadUrl']),
        storagePath: _learningText(data['storagePath']),
        type: LearningResourceType.values.firstWhere(
          (type) => type.name == _learningText(data['type']),
          orElse: () => LearningResourceType.pdf,
        ),
        order: _learningInt(data['order'], 100),
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'downloadUrl': downloadUrl,
        'storagePath': storagePath,
        'type': type.name,
        'order': order,
      };
}

class LearningPassage {
  const LearningPassage({
    required this.book,
    required this.chapter,
    required this.startVerse,
    required this.endVerse,
    this.order = 100,
  });

  final String book;
  final int chapter;
  final int startVerse;
  final int endVerse;
  final int order;

  bool get isValid =>
      book.isNotEmpty &&
      chapter > 0 &&
      startVerse > 0 &&
      endVerse >= startVerse;

  String get reference {
    if (!isValid) return '';
    final verses =
        startVerse == endVerse ? '$startVerse' : '$startVerse-$endVerse';
    return '$book $chapter:$verses';
  }

  factory LearningPassage.fromMap(Map<String, dynamic> data) => LearningPassage(
        book: _learningText(data['book']),
        chapter: _learningInt(data['chapter']),
        startVerse: _learningInt(data['startVerse']),
        endVerse: _learningInt(data['endVerse']),
        order: _learningInt(data['order'], 100),
      );

  Map<String, dynamic> toMap() => {
        'book': book,
        'chapter': chapter,
        'startVerse': startVerse,
        'endVerse': endVerse,
        'order': order,
      };
}

class LearningQuizQuestion {
  const LearningQuizQuestion({
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

  factory LearningQuizQuestion.fromMap(Map<String, dynamic> data) =>
      LearningQuizQuestion(
        prompt: _learningText(data['prompt']),
        options: data['options'] is Iterable
            ? (data['options'] as Iterable)
                .map(_learningText)
                .where((option) => option.isNotEmpty)
                .toList(growable: false)
            : const [],
        correctOptionIndex: _learningInt(data['correctOptionIndex']),
      );

  Map<String, dynamic> toMap() => {
        'prompt': prompt,
        'options': options,
        'correctOptionIndex': correctOptionIndex,
      };
}

class LearningSection {
  const LearningSection({
    required this.id,
    required this.title,
    required this.description,
    required this.scriptureBook,
    required this.scriptureChapter,
    required this.scriptureStartVerse,
    required this.scriptureEndVerse,
    required this.resources,
    required this.questions,
    required this.order,
    required this.passingPercentage,
    this.passages = const [],
  });

  final String id;
  final String title;
  final String description;
  final String scriptureBook;
  final int scriptureChapter;
  final int scriptureStartVerse;
  final int scriptureEndVerse;
  final List<LearningResource> resources;
  final List<LearningQuizQuestion> questions;
  final int order;
  final int passingPercentage;
  final List<LearningPassage> passages;

  List<LearningPassage> get effectivePassages {
    if (passages.isNotEmpty) return passages;
    if (!hasScripture) return const [];
    return [
      LearningPassage(
        book: scriptureBook,
        chapter: scriptureChapter,
        startVerse: scriptureStartVerse,
        endVerse: scriptureEndVerse,
        order: 10,
      ),
    ];
  }

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

  bool get isConfigured =>
      id.isNotEmpty &&
      title.isNotEmpty &&
      effectivePassages.isNotEmpty &&
      effectivePassages.every((passage) => passage.isValid);

  factory LearningSection.fromMap(Map<String, dynamic> data) => LearningSection(
        id: _learningText(data['id']),
        title: _learningText(data['title']),
        description: _learningText(data['description']),
        scriptureBook: _learningText(data['scriptureBook']),
        scriptureChapter: _learningInt(data['scriptureChapter']),
        scriptureStartVerse: _learningInt(data['scriptureStartVerse']),
        scriptureEndVerse: _learningInt(data['scriptureEndVerse']),
        resources: data['resources'] is Iterable
            ? (data['resources'] as Iterable)
                .whereType<Map>()
                .map((item) => LearningResource.fromMap(
                      Map<String, dynamic>.from(item),
                    ))
                .where((item) =>
                    item.name.isNotEmpty && item.downloadUrl.isNotEmpty)
                .toList(growable: false)
            : const [],
        passages: data['passages'] is Iterable
            ? (data['passages'] as Iterable)
                .whereType<Map>()
                .map((item) => LearningPassage.fromMap(
                      Map<String, dynamic>.from(item),
                    ))
                .where((item) => item.isValid)
                .toList(growable: false)
            : const [],
        questions: data['questions'] is Iterable
            ? (data['questions'] as Iterable)
                .whereType<Map>()
                .map((item) => LearningQuizQuestion.fromMap(
                      Map<String, dynamic>.from(item),
                    ))
                .where((item) => item.isValid)
                .toList(growable: false)
            : const [],
        order: _learningInt(data['order'], 100),
        passingPercentage:
            _learningInt(data['passingPercentage'], 70).clamp(1, 100),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'scriptureBook': scriptureBook,
        'scriptureChapter': scriptureChapter,
        'scriptureStartVerse': scriptureStartVerse,
        'scriptureEndVerse': scriptureEndVerse,
        'resources': resources.map((item) => item.toMap()).toList(),
        'passages': effectivePassages.map((item) => item.toMap()).toList(),
        'questions': questions.map((item) => item.toMap()).toList(),
        'order': order,
        'passingPercentage': passingPercentage,
      };
}

class LearningModule {
  const LearningModule({
    required this.id,
    required this.title,
    required this.description,
    required this.sections,
    required this.order,
    required this.enabled,
    this.sourceModuleId = '',
    this.finalExamQuestions = const [],
    this.passingPercentage = 70,
  });

  final String id;
  final String title;
  final String description;
  final List<LearningSection> sections;
  final int order;
  final bool enabled;
  final String sourceModuleId;
  final List<LearningQuizQuestion> finalExamQuestions;
  final int passingPercentage;

  List<LearningQuizQuestion> get effectiveFinalExamQuestions =>
      finalExamQuestions.isNotEmpty
          ? finalExamQuestions
          : sections.expand((section) => section.questions).toList();

  bool get isChurchCustomization => sourceModuleId.isNotEmpty;

  bool get isConfigured =>
      title.isNotEmpty &&
      description.isNotEmpty &&
      sections.isNotEmpty &&
      sections.every((section) => section.isConfigured) &&
      effectiveFinalExamQuestions.isNotEmpty &&
      effectiveFinalExamQuestions.every((question) => question.isValid);

  factory LearningModule.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final sections = data['sections'] is Iterable
        ? (data['sections'] as Iterable)
            .whereType<Map>()
            .map((item) => LearningSection.fromMap(
                  Map<String, dynamic>.from(item),
                ))
            .toList()
        : <LearningSection>[];
    sections.sort((left, right) => left.order.compareTo(right.order));
    return LearningModule(
      id: doc.id,
      title: _learningText(data['title']),
      description: _learningText(data['description']),
      sections: sections,
      order: _learningInt(data['order'], 100),
      enabled: data['enabled'] != false,
      sourceModuleId: _learningText(data['sourceModuleId']),
      finalExamQuestions: data['finalExamQuestions'] is Iterable
          ? (data['finalExamQuestions'] as Iterable)
              .whereType<Map>()
              .map((item) => LearningQuizQuestion.fromMap(
                    Map<String, dynamic>.from(item),
                  ))
              .where((item) => item.isValid)
              .toList(growable: false)
          : const [],
      passingPercentage: _learningInt(
        data['passingPercentage'],
        sections.isEmpty ? 70 : sections.first.passingPercentage,
      ).clamp(1, 100),
    );
  }
}

class ChurchLearningConfig {
  const ChurchLearningConfig({
    required this.enabled,
    required this.inheritGlobalModules,
    required this.hiddenGlobalModuleIds,
    required this.moduleOrder,
  });

  const ChurchLearningConfig.defaults()
      : enabled = true,
        inheritGlobalModules = true,
        hiddenGlobalModuleIds = const {},
        moduleOrder = const [];

  final bool enabled;
  final bool inheritGlobalModules;
  final Set<String> hiddenGlobalModuleIds;
  final List<String> moduleOrder;

  factory ChurchLearningConfig.fromMap(Map<String, dynamic>? data) =>
      ChurchLearningConfig(
        enabled: data?['enabled'] != false,
        inheritGlobalModules: data?['inheritGlobalModules'] != false,
        hiddenGlobalModuleIds: data?['hiddenGlobalModuleIds'] is Iterable
            ? (data!['hiddenGlobalModuleIds'] as Iterable)
                .map(_learningText)
                .where((id) => id.isNotEmpty)
                .toSet()
            : const {},
        moduleOrder: data?['moduleOrder'] is Iterable
            ? (data!['moduleOrder'] as Iterable)
                .map(_learningText)
                .where((id) => id.isNotEmpty)
                .toList(growable: false)
            : const [],
      );
}

List<LearningModule> resolveChurchLearningModules({
  required ChurchLearningConfig config,
  required List<LearningModule> globalModules,
  required List<LearningModule> churchModules,
}) {
  if (!config.enabled) return const [];
  final globalIds = globalModules.map((module) => module.id).toSet();
  final customBySource = <String, LearningModule>{
    for (final module in churchModules)
      if (module.sourceModuleId.isNotEmpty) module.sourceModuleId: module,
  };
  final resolved = <LearningModule>[];
  final includedChurchIds = <String>{};

  if (config.inheritGlobalModules) {
    for (final global in globalModules) {
      if (!global.enabled ||
          !global.isConfigured ||
          config.hiddenGlobalModuleIds.contains(global.id)) {
        continue;
      }
      final customized = customBySource[global.id];
      final selected = customized ?? global;
      if (!selected.enabled) continue;
      if (!selected.isConfigured) continue;
      resolved.add(selected);
      if (customized != null) includedChurchIds.add(customized.id);
    }
  }

  for (final module in churchModules) {
    if (includedChurchIds.contains(module.id) ||
        !module.enabled ||
        !module.isConfigured) {
      continue;
    }
    final sourceId = module.sourceModuleId;
    if (sourceId.isNotEmpty &&
        globalIds.contains(sourceId) &&
        config.hiddenGlobalModuleIds.contains(sourceId)) {
      continue;
    }
    resolved.add(module);
  }

  final orderById = <String, int>{
    for (var index = 0; index < config.moduleOrder.length; index++)
      config.moduleOrder[index]: index,
  };
  resolved.sort((left, right) {
    final leftOrder = orderById[left.id];
    final rightOrder = orderById[right.id];
    if (leftOrder != null && rightOrder != null) {
      return leftOrder.compareTo(rightOrder);
    }
    if (leftOrder != null) return -1;
    if (rightOrder != null) return 1;
    return left.order.compareTo(right.order);
  });
  return resolved;
}

class LearningSectionAttempt {
  const LearningSectionAttempt({
    required this.score,
    required this.total,
    required this.answers,
    required this.completedAt,
  });

  final int score;
  final int total;
  final List<int> answers;
  final DateTime? completedAt;

  factory LearningSectionAttempt.fromMap(Map<String, dynamic> data) {
    final rawDate = data['completedAt'];
    return LearningSectionAttempt(
      score: _learningInt(data['score']),
      total: _learningInt(data['total']),
      answers: data['answers'] is Iterable
          ? (data['answers'] as Iterable)
              .map((item) => _learningInt(item, -1))
              .toList(growable: false)
          : const [],
      completedAt: rawDate is Timestamp
          ? rawDate.toDate()
          : rawDate is DateTime
              ? rawDate
              : null,
    );
  }
}

class LearningProgress {
  const LearningProgress({
    required this.completedSectionIds,
    required this.attempts,
    this.completedModuleIds = const {},
  });

  final Set<String> completedSectionIds;
  final Map<String, LearningSectionAttempt> attempts;
  final Set<String> completedModuleIds;

  bool isSectionComplete(String sectionId) =>
      completedSectionIds.contains(sectionId);

  bool isModuleComplete(LearningModule module) {
    if (module.effectiveFinalExamQuestions.isNotEmpty) {
      return completedModuleIds.contains(module.id);
    }
    return module.sections.isNotEmpty &&
        module.sections.every((section) => isSectionComplete(section.id));
  }

  factory LearningProgress.fromMap(Map<String, dynamic>? data) {
    final rawAttempts = data?['attempts'];
    return LearningProgress(
      completedSectionIds: data?['completedSectionIds'] is Iterable
          ? (data!['completedSectionIds'] as Iterable)
              .map(_learningText)
              .where((id) => id.isNotEmpty)
              .toSet()
          : const {},
      completedModuleIds: data?['completedModuleIds'] is Iterable
          ? (data!['completedModuleIds'] as Iterable)
              .map(_learningText)
              .where((id) => id.isNotEmpty)
              .toSet()
          : const {},
      attempts: rawAttempts is Map
          ? rawAttempts.map(
              (key, value) => MapEntry(
                key.toString(),
                LearningSectionAttempt.fromMap(
                  value is Map
                      ? Map<String, dynamic>.from(value)
                      : const <String, dynamic>{},
                ),
              ),
            )
          : const {},
    );
  }
}

class LearningQuizResult {
  const LearningQuizResult({
    required this.id,
    required this.churchId,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.moduleId,
    required this.sectionId,
    required this.answers,
    required this.score,
    required this.total,
    required this.passed,
    required this.attemptNumber,
    required this.submittedAt,
  });

  final String id;
  final String churchId;
  final String userId;
  final String userName;
  final String userEmail;
  final String moduleId;
  final String sectionId;
  final List<int> answers;
  final int score;
  final int total;
  final bool passed;
  final int attemptNumber;
  final DateTime? submittedAt;

  double get percentage => total == 0 ? 0 : score / total * 100;

  factory LearningQuizResult.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final rawSubmittedAt = data['submittedAt'];
    return LearningQuizResult(
      id: doc.id,
      churchId: _learningText(data['churchId']),
      userId: _learningText(data['userId']),
      userName: _learningText(data['userName']),
      userEmail: _learningText(data['userEmail']),
      moduleId: _learningText(data['moduleId']),
      sectionId: _learningText(data['sectionId']),
      answers: data['answers'] is Iterable
          ? (data['answers'] as Iterable)
              .map((answer) => _learningInt(answer, -1))
              .toList(growable: false)
          : const [],
      score: _learningInt(data['score']),
      total: _learningInt(data['total']),
      passed: data['passed'] == true,
      attemptNumber: _learningInt(data['attemptNumber'], 1),
      submittedAt: rawSubmittedAt is Timestamp
          ? rawSubmittedAt.toDate()
          : rawSubmittedAt is DateTime
              ? rawSubmittedAt
              : null,
    );
  }
}
