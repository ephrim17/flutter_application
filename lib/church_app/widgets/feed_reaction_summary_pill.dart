import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/helpers/emoji_text_style.dart';
import 'package:flutter_application/church_app/helpers/feed_reaction_summary.dart';

/// The reaction count pill — the emoji people actually used, most-reacted
/// first, then the total. Tapping it opens the "who reacted" sheet.
///
/// This is the card's only visible affordance for the reactor list; the
/// reaction button's long-press does the same thing, but a long-press on an
/// unlabelled circle is not something anyone discovers. Renders nothing at
/// all when the post has no reactions, so a quiet feed stays quiet.
class FeedReactionSummaryPill extends StatelessWidget {
  const FeedReactionSummaryPill({
    super.key,
    required this.summary,
    required this.onTap,
  });

  final Map<String, int> summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final total = feedReactionPillTotal(summary);
    if (total == 0) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final emoji = feedReactionPillEmoji(summary);

    return Semantics(
      button: true,
      label: context.t(
        'ui.feed_card.reactions_pill_label',
        parameters: {'count': total},
      ),
      child: Material(
        color: theme.colorScheme.surface,
        shape: StadiumBorder(
          side: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.10),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(9, 6, 11, 6),
            // The emoji and the bare count would otherwise merge into the
            // enclosing label, leaving a screen reader to announce
            // "3 reactions. See who reacted. 🙏 3".
            child: ExcludeSemantics(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final item in emoji)
                    Padding(
                      padding: const EdgeInsets.only(right: 2),
                      child: Text(item, style: emojiTextStyle(fontSize: 15)),
                    ),
                  const SizedBox(width: 3),
                  Text(
                    '$total',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
