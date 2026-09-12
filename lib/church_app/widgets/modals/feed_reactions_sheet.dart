import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/providers/feed_reaction_provider.dart';
import 'package:flutter_application/church_app/widgets/app_loading_indicator.dart';
import 'package:flutter_application/church_app/widgets/app_modal_bottom_sheet.dart';
import 'package:flutter_application/church_app/widgets/app_profile_avatar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// "N Reactions" — a chip per emoji present (tap to filter) above a list of
/// everyone who reacted and with what, WhatsApp-channel style.
Future<void> showFeedReactionsSheet(
  BuildContext context, {
  required String? churchId,
  required String postId,
}) {
  return showAppModalBottomSheet<void>(
    context: context,
    heightFactor: 0.75,
    builder: (_) => _FeedReactionsSheet(
      target: FeedReactionTarget(churchId: churchId, postId: postId),
    ),
  );
}

class _FeedReactionsSheet extends ConsumerStatefulWidget {
  const _FeedReactionsSheet({required this.target});

  final FeedReactionTarget target;

  @override
  ConsumerState<_FeedReactionsSheet> createState() =>
      _FeedReactionsSheetState();
}

class _FeedReactionsSheetState extends ConsumerState<_FeedReactionsSheet> {
  String? _selectedEmoji;

  @override
  Widget build(BuildContext context) {
    final reactionsAsync = ref.watch(allFeedReactionsProvider(widget.target));

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: reactionsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: AppLoadingIndicator()),
          ),
          error: (_, __) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text(context.t('ui.feed_reactions.load_failed')),
            ),
          ),
          data: (reactions) {
            final summary = <String, int>{};
            for (final reaction in reactions) {
              summary[reaction.emoji] = (summary[reaction.emoji] ?? 0) + 1;
            }
            final filtered = _selectedEmoji == null
                ? reactions
                : reactions
                    .where((reaction) => reaction.emoji == _selectedEmoji)
                    .toList(growable: false);

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t(
                    'ui.feed_reactions.title',
                    parameters: {'count': reactions.length},
                  ),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 14),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _ReactionFilterChip(
                        label: context.t('ui.feed_reactions.all'),
                        selected: _selectedEmoji == null,
                        onTap: () => setState(() => _selectedEmoji = null),
                      ),
                      for (final entry in summary.entries) ...[
                        const SizedBox(width: 8),
                        _ReactionFilterChip(
                          label: '${entry.key} ${entry.value}',
                          selected: _selectedEmoji == entry.key,
                          onTap: () =>
                              setState(() => _selectedEmoji = entry.key),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final reaction = filtered[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: AppProfileAvatar(
                          name: reaction.name,
                          imageUrl: reaction.photoUrl,
                          radius: 20,
                        ),
                        title: Text(
                          reaction.name.isEmpty
                              ? context.t('ui.feed_reactions.unknown_name')
                              : reaction.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        trailing: Text(
                          reaction.emoji,
                          style: const TextStyle(fontSize: 22),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ReactionFilterChip extends StatelessWidget {
  const _ReactionFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: selected ? colors.primaryContainer : colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
