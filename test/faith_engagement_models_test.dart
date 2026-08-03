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
