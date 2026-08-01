import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application/church_app/models/faith_engagement_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('circle is visible only to its assigned group', () {
    const circle = YouthCircle(
      id: 'circle',
      title: 'Music team',
      description: 'A group discussion',
      audienceGroupId: 'music_ministry',
      enabled: true,
      order: 1,
    );

    expect(circle.isVisibleTo(['music_ministry']), isTrue);
    expect(circle.isVisibleTo(['youth_ministry']), isFalse);
    expect(circle.isVisibleTo([]), isFalse);
  });

  test('quiz challenge is active only inside its configured window', () {
    final now = DateTime(2026, 8, 1, 12);
    final challenge = QuizChallenge(
      id: 'challenge',
      title: 'Bible quiz',
      description: 'Choose the correct answer.',
      questions: const [
        QuizQuestion(
          prompt: 'Who built the ark?',
          options: ['Noah', 'Moses'],
          correctOptionIndex: 0,
        ),
      ],
      startAt: now.subtract(const Duration(days: 1)),
      endAt: now.add(const Duration(days: 1)),
      enabled: true,
    );

    expect(challenge.isActiveAt(now), isTrue);
    expect(challenge.isActiveAt(now.add(const Duration(days: 2))), isFalse);
    expect(challenge.isConfigured, isTrue);
  });

  test('quiz attempt is valid only when every answer is stored', () {
    const complete = QuizAttempt(answers: [0, 2], score: 1, total: 2);
    const incomplete = QuizAttempt(answers: [0], score: 1, total: 2);

    expect(complete.isValid, isTrue);
    expect(incomplete.isValid, isFalse);
  });

  test('quiz dashboard result aggregates participation and scores', () {
    final result = QuizDashboardResult(
      challenge: QuizChallenge(
        id: 'quiz',
        title: 'Quiz',
        description: '',
        questions: const [
          QuizQuestion(
            prompt: 'Question',
            options: ['One', 'Two'],
            correctOptionIndex: 0,
          ),
          QuizQuestion(
            prompt: 'Question two',
            options: ['One', 'Two'],
            correctOptionIndex: 1,
          ),
        ],
        startAt: null,
        endAt: null,
        enabled: true,
      ),
      participants: const [
        QuizParticipantResult(
          userId: 'one',
          attempt: QuizAttempt(answers: [0, 1], score: 2, total: 2),
          submittedAt: null,
        ),
        QuizParticipantResult(
          userId: 'two',
          attempt: QuizAttempt(answers: [0, 0], score: 1, total: 2),
          submittedAt: null,
        ),
      ],
    );

    expect(result.participantCount, 2);
    expect(result.highestScore, 2);
    expect(result.averagePercentage, 75);
  });

  test('daily faith progress requires all three meaningful steps', () {
    const partial = DailyFaithProgress(
      completedSteps: {'reflect', 'pray'},
    );
    const complete = DailyFaithProgress(
      completedSteps: {'reflect', 'pray', 'challenge'},
    );

    expect(partial.isComplete, isFalse);
    expect(complete.isComplete, isTrue);
  });

  test('faith loop dashboard groups daily completion records', () {
    final day = DateTime(2026, 8, 2);
    final updates = FaithLoopDashboardUpdate(
      records: [
        DailyFaithProgressRecord(
          userId: 'one',
          date: day,
          updatedAt: day,
          completedSteps: const {'reflect', 'pray', 'challenge'},
        ),
        DailyFaithProgressRecord(
          userId: 'two',
          date: day,
          updatedAt: day,
          completedSteps: const {'reflect'},
        ),
      ],
    );

    expect(updates.recordsForDay(day), hasLength(2));
    expect(updates.completedForDay(day), 1);
    expect(updates.recordsForDay(day.add(const Duration(days: 1))), isEmpty);
  });

  test('reflection matches only its configured calendar day', () {
    final reflection = FaithReflection(
      id: 'reflection',
      title: 'Today',
      body: 'Body',
      scriptureBook: 'John',
      scriptureChapter: 3,
      scriptureStartVerse: 16,
      scriptureEndVerse: 16,
      activeDate: Timestamp.fromDate(DateTime(2026, 8, 1)).toDate(),
      enabled: true,
    );

    expect(reflection.isForDay(DateTime(2026, 8, 1, 23)), isTrue);
    expect(reflection.isForDay(DateTime(2026, 8, 2)), isFalse);
    expect(reflection.scriptureReference, 'John 3:16');
  });

  test('reflection formats a bounded scripture range', () {
    const reflection = FaithReflection(
      id: 'reflection',
      title: 'Today',
      body: 'Body',
      scriptureBook: 'John',
      scriptureChapter: 2,
      scriptureStartVerse: 1,
      scriptureEndVerse: 10,
      prayerPoints: ['Pray for wisdom', 'Pray for courage'],
      liveItOut: 'Encourage one person today.',
      activeDate: null,
      enabled: true,
    );

    expect(reflection.hasScripture, isTrue);
    expect(reflection.scriptureReference, 'John 2:1-10');
    expect(reflection.prayerPoints, hasLength(2));
    expect(reflection.liveItOut, 'Encourage one person today.');
  });
}
