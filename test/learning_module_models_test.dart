import 'package:flutter_application/church_app/models/learning_module_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const question = LearningQuizQuestion(
    prompt: 'Who built the ark?',
    options: ['Noah', 'Moses', 'David', 'Paul'],
    correctOptionIndex: 0,
  );
  const firstSection = LearningSection(
    id: 'section-1',
    title: 'The call to obedience',
    description: '',
    scriptureBook: 'Genesis',
    scriptureChapter: 6,
    scriptureStartVerse: 9,
    scriptureEndVerse: 22,
    resources: [],
    questions: [question],
    order: 10,
    passingPercentage: 70,
  );
  const secondSection = LearningSection(
    id: 'section-2',
    title: 'The flood',
    description: '',
    scriptureBook: 'Genesis',
    scriptureChapter: 7,
    scriptureStartVerse: 1,
    scriptureEndVerse: 10,
    resources: [],
    questions: [question],
    order: 20,
    passingPercentage: 70,
  );
  const module = LearningModule(
    id: 'module-1',
    title: 'Walking with God',
    description: 'A study from the life of Noah.',
    sections: [firstSection, secondSection],
    order: 10,
    enabled: true,
  );

  test('a configured learning section requires scripture and a quiz', () {
    expect(firstSection.isConfigured, isTrue);
    expect(firstSection.scriptureReference, 'Genesis 6:9-22');
  });

  test('module completion requires every section to be completed', () {
    const partial = LearningProgress(
      completedSectionIds: {'section-1'},
      attempts: {},
    );
    const complete = LearningProgress(
      completedSectionIds: {'section-1', 'section-2'},
      attempts: {},
    );

    expect(partial.isModuleComplete(module), isFalse);
    expect(complete.isModuleComplete(module), isTrue);
  });

  test('a failed section quiz can be retaken without counting as passed', () {
    expect(
      learningQuizPasses(score: 1, total: 4, passingPercentage: 70),
      isFalse,
    );
    expect(
      learningQuizPasses(score: 3, total: 4, passingPercentage: 70),
      isTrue,
    );
  });

  test('learning results retain retake number and score percentage', () {
    const result = LearningQuizResult(
      id: 'result-2',
      churchId: 'church-1',
      userId: 'user-1',
      userName: 'Learner',
      userEmail: 'learner@example.com',
      moduleId: 'module-1',
      sectionId: 'section-1',
      answers: [0, 1, 2, 3],
      score: 3,
      total: 4,
      passed: true,
      attemptNumber: 2,
      submittedAt: null,
    );

    expect(result.attemptNumber, 2);
    expect(result.percentage, 75);
  });

  group('church learning catalogue resolution', () {
    const secondModule = LearningModule(
      id: 'module-2',
      title: 'Life of Jesus',
      description: 'A Gospel study.',
      sections: [firstSection],
      order: 20,
      enabled: true,
    );

    test('disabling learning hides the entire catalogue for one church', () {
      final resolved = resolveChurchLearningModules(
        config: const ChurchLearningConfig(
          enabled: false,
          inheritGlobalModules: true,
          hiddenGlobalModuleIds: {},
          moduleOrder: [],
        ),
        globalModules: const [module, secondModule],
        churchModules: const [],
      );

      expect(resolved, isEmpty);
    });

    test('a hidden global module is removed only from the church view', () {
      final globals = <LearningModule>[module, secondModule];
      final resolved = resolveChurchLearningModules(
        config: const ChurchLearningConfig(
          enabled: true,
          inheritGlobalModules: true,
          hiddenGlobalModuleIds: {'module-1'},
          moduleOrder: [],
        ),
        globalModules: globals,
        churchModules: const [],
      );

      expect(resolved.map((item) => item.id), ['module-2']);
      expect(globals.map((item) => item.id), ['module-1', 'module-2']);
    });

    test('a church customization replaces its global source', () {
      const customization = LearningModule(
        id: 'module-1',
        title: 'Walking with God — Church Edition',
        description: 'An independent church version.',
        sections: [firstSection],
        order: 10,
        enabled: true,
        sourceModuleId: 'module-1',
      );
      final resolved = resolveChurchLearningModules(
        config: const ChurchLearningConfig.defaults(),
        globalModules: const [module, secondModule],
        churchModules: const [customization],
      );

      expect(resolved, hasLength(2));
      expect(resolved.first.title, customization.title);
      expect(module.title, 'Walking with God');
    });

    test('church-only modules participate in church-specific ordering', () {
      const churchOnly = LearningModule(
        id: 'church-module',
        title: 'Local Foundations',
        description: 'Church-specific study.',
        sections: [firstSection],
        order: 100,
        enabled: true,
      );
      final resolved = resolveChurchLearningModules(
        config: const ChurchLearningConfig(
          enabled: true,
          inheritGlobalModules: true,
          hiddenGlobalModuleIds: {},
          moduleOrder: ['church-module', 'module-2', 'module-1'],
        ),
        globalModules: const [module, secondModule],
        churchModules: const [churchOnly],
      );

      expect(
        resolved.map((item) => item.id),
        ['church-module', 'module-2', 'module-1'],
      );
    });
  });
}
