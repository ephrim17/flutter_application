/// How many distinct emoji the card's reaction pill shows before it stops
/// and lets the total speak for the rest.
const int feedReactionPillMaxEmoji = 3;

/// The emoji counts the reaction pill should display, reconciling the post's
/// server-side aggregate with the reactor's own live reaction.
///
/// `reactionSummary` on the post is denormalized by a Cloud Function
/// (`onChurchFeedReactionWrite`), and the feed list is paginated with
/// one-shot `get()`s — so the aggregate a loaded card holds is a snapshot
/// from fetch time and never moves on its own. The reactor's own reaction,
/// by contrast, is a live single-doc listener. Without reconciling the two,
/// tapping a heart leaves the count sitting at its old value until the feed
/// is pulled to refresh, which reads as a broken pill.
///
/// [serverMyEmoji] is the reactor's reaction as it stood when the aggregate
/// was computed (in practice: the first value their live listener produced
/// for this post), and [myEmoji] is what it is now. Only the difference
/// between those two is applied, so the pill moves the instant they react
/// and still agrees with the server once the feed is refetched. Other
/// people's reactions arriving after fetch time are not reflected until
/// then — the same staleness the rest of the card already carries.
///
/// Counts are clamped at zero and emptied entries dropped, so a stale or
/// mid-flight aggregate can never render a negative count.
Map<String, int> feedReactionPillSummary({
  required Map<String, int> serverSummary,
  required String? serverMyEmoji,
  required String? myEmoji,
}) {
  final counts = <String, int>{};
  for (final entry in serverSummary.entries) {
    if (entry.key.isEmpty || entry.value <= 0) continue;
    counts[entry.key] = entry.value;
  }

  if (serverMyEmoji == myEmoji) return counts;

  if (serverMyEmoji != null && serverMyEmoji.isNotEmpty) {
    final reduced = (counts[serverMyEmoji] ?? 0) - 1;
    if (reduced > 0) {
      counts[serverMyEmoji] = reduced;
    } else {
      counts.remove(serverMyEmoji);
    }
  }
  if (myEmoji != null && myEmoji.isNotEmpty) {
    counts[myEmoji] = (counts[myEmoji] ?? 0) + 1;
  }

  return counts;
}

/// The emoji to draw on the pill, most-reacted first, capped at
/// [feedReactionPillMaxEmoji].
///
/// Ties break on the emoji itself rather than on map order, so the pill
/// doesn't reshuffle between rebuilds of the same unchanged post.
List<String> feedReactionPillEmoji(Map<String, int> summary) {
  final entries = summary.entries
      .where((entry) => entry.key.isNotEmpty && entry.value > 0)
      .toList()
    ..sort((a, b) {
      final byCount = b.value.compareTo(a.value);
      return byCount != 0 ? byCount : a.key.compareTo(b.key);
    });

  return entries
      .take(feedReactionPillMaxEmoji)
      .map((entry) => entry.key)
      .toList(growable: false);
}

/// Total reactions across every emoji in [summary].
int feedReactionPillTotal(Map<String, int> summary) {
  var total = 0;
  for (final value in summary.values) {
    if (value > 0) total += value;
  }
  return total;
}
