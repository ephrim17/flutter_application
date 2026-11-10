import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application/church_app/helpers/feed_reaction_summary.dart';

/// The reaction pill reads a *denormalized* aggregate (written by a Cloud
/// Function) off a post the feed fetched with a one-shot `get()`, while the
/// reactor's own reaction arrives on a live listener. These pin the
/// reconciliation between the two: react, and the count has to move at once,
/// without ever drifting from what a refetch will show.
void main() {
  group('feedReactionPillSummary', () {
    test('passes the aggregate through when nothing has changed', () {
      final summary = feedReactionPillSummary(
        serverSummary: const {'🙏': 3, '❤️': 2},
        serverMyEmoji: '🙏',
        myEmoji: '🙏',
      );
      expect(summary, {'🙏': 3, '❤️': 2});
    });

    test('adding a first reaction increments that emoji', () {
      final summary = feedReactionPillSummary(
        serverSummary: const {'🙏': 3},
        serverMyEmoji: null,
        myEmoji: '❤️',
      );
      expect(summary, {'🙏': 3, '❤️': 1});
    });

    test('removing your reaction decrements it', () {
      final summary = feedReactionPillSummary(
        serverSummary: const {'🙏': 3, '❤️': 1},
        serverMyEmoji: '❤️',
        myEmoji: null,
      );
      expect(summary, {'🙏': 3});
    });

    test('changing your emoji moves the count across', () {
      final summary = feedReactionPillSummary(
        serverSummary: const {'🙏': 3, '❤️': 1},
        serverMyEmoji: '🙏',
        myEmoji: '❤️',
      );
      expect(summary, {'🙏': 2, '❤️': 2});
    });

    test('un-reacting the only reaction empties the pill', () {
      final summary = feedReactionPillSummary(
        serverSummary: const {'👍': 1},
        serverMyEmoji: '👍',
        myEmoji: null,
      );
      expect(summary, isEmpty);
      expect(feedReactionPillTotal(summary), 0);
    });

    test('a stale aggregate can never produce a negative count', () {
      // The aggregate hadn't caught up and shows nothing, yet the reactor's
      // live doc says they had reacted — decrementing blindly would render
      // "-1 reactions".
      final summary = feedReactionPillSummary(
        serverSummary: const {},
        serverMyEmoji: '🙏',
        myEmoji: null,
      );
      expect(summary, isEmpty);
      expect(feedReactionPillTotal(summary), 0);
    });

    test('junk entries in the aggregate are dropped', () {
      final summary = feedReactionPillSummary(
        serverSummary: const {'🙏': 2, '': 5, '👍': 0, '❤️': -1},
        serverMyEmoji: null,
        myEmoji: null,
      );
      expect(summary, {'🙏': 2});
    });

    test('does not mutate the post\'s own aggregate map', () {
      final server = {'🙏': 1};
      feedReactionPillSummary(
        serverSummary: server,
        serverMyEmoji: null,
        myEmoji: '🙏',
      );
      expect(server, {'🙏': 1});
    });
  });

  group('feedReactionPillEmoji', () {
    test('orders by count, most reacted first', () {
      expect(
        feedReactionPillEmoji(const {'🙏': 1, '❤️': 7, '👍': 3}),
        ['❤️', '👍', '🙏'],
      );
    });

    test('caps the emoji shown so a busy post keeps a pill-sized pill', () {
      final emoji = feedReactionPillEmoji(const {
        '🙏': 9,
        '❤️': 8,
        '🤍': 7,
        '👍': 6,
        '🎉': 5,
      });
      expect(emoji, hasLength(feedReactionPillMaxEmoji));
      expect(emoji, ['🙏', '❤️', '🤍']);
    });

    test('ties break deterministically, so the pill cannot reshuffle', () {
      const tied = {'👍': 2, '🙏': 2, '❤️': 2};
      expect(
        feedReactionPillEmoji(tied),
        feedReactionPillEmoji(Map.of(tied)),
      );
    });

    test('an empty aggregate yields no emoji', () {
      expect(feedReactionPillEmoji(const {}), isEmpty);
    });
  });

  group('feedReactionPillTotal', () {
    test('sums every emoji', () {
      expect(feedReactionPillTotal(const {'🙏': 3, '❤️': 2, '👍': 1}), 6);
    });

    test('ignores non-positive counts', () {
      expect(feedReactionPillTotal(const {'🙏': 3, '👍': 0, '❤️': -2}), 3);
    });
  });
}
