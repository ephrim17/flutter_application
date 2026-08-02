import 'package:flutter_application/church_app/screens/for_you/for_you_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('faith content remains one top-level For You section', () {
    final sections = ForYouSectionRegistry.all();
    final ids = sections.map((section) => section.id).toList();

    expect(
        ids,
        containsAll(<String>[
          'faithEngagement',
          'prayForOthers',
          'featured',
        ]));
    expect(ids, isNot(contains('dailyFaithLoop')));
    expect(ids, isNot(contains('quizChallenge')));
    expect(ids, isNot(contains('circles')));
    expect(ids.toSet().length, ids.length);
  });
}
