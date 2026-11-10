import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/widgets/app_loading_indicator.dart';
import 'package:flutter_application/church_app/providers/for_you_sections/daily_verse_providers.dart';
import 'package:flutter_application/church_app/providers/language_provider.dart';
import 'package:flutter_application/church_app/screens/for_you/for_you_card_layout.dart';
import 'package:flutter_application/church_app/screens/home/home_screen.dart';
import 'package:flutter_application/church_app/widgets/decorated_scripture_card_widget.dart';
import 'package:flutter_application/church_app/widgets/language_toggle_widget.dart';
import 'package:flutter_application/church_app/widgets/modals/verse_share_modal.dart';
import 'package:flutter_application/church_app/widgets/section_header_widget.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DailyVerseSection implements MasterSection {
  const DailyVerseSection();

  @override
  String get id => 'dailyVerse';

  @override
  int get order => 10;

  @override
  List<Widget> buildSlivers(BuildContext context) {
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Outside the card, like every other For You section. It used
              // to sit inside, which made the card carry its own title while
              // "Pray for others", "Featured For you" and the rest announced
              // themselves from above it.
              SectionHeader(
                text: context.t('daily_verse.title'),
                padding: 0.0,
              ),
              const SizedBox(height: forYouHeaderGap),
              const DailyVerseCard(),
            ],
          ),
        ),
      ),
    ];
  }
}

class DailyVerseCard extends ConsumerWidget {
  const DailyVerseCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dailyVerseAsync = ref.watch(dailyVerseProviderLocal);
    final language = ref.watch(dailyVerseLanguageProvider);
    final width = MediaQuery.of(context).size.width;

    return dailyVerseAsync.when(
      loading: () => const Center(child: AppLoadingIndicator()),
      error: (_, __) => Text(context.t('ui.verse_share.verse_unavailable')),
      data: (verse) {
        final isTamil = language == BibleLanguage.tamil;
        final verseText = (isTamil ? verse['tamil'] : verse['english']) ?? '';
        final reference =
            (isTamil ? verse['referenceTamil'] : verse['reference']) ?? '';

        // No minimum height any more. It existed to stop the card looking
        // stunted next to the other For You cards back when it also carried
        // the section title; with the title moved out and the controls moved
        // down, that floor only showed as dead space under the bottom bar.
        // The card is now exactly the verse plus its bar.
        return DecoratedScriptureCard(
          width: width - 32,
          plain: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (verseText.isEmpty)
                Text(context.t('ui.verse_share.verse_unavailable'))
              else ...[
                Text(
                  verseText,
                  maxLines: 8,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 18.0,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 14),
                // The card's one bar of controls, along the bottom: which
                // verse this is, which language it is in, and sharing it.
                // The verse itself is the card now — nothing competes with
                // it along the top edge.
                Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: ScriptureReferencePill(reference: reference),
                      ),
                    ),
                    BibleLanguageToggle(
                      provider: dailyVerseLanguageProvider,
                    ),
                    IconButton(
                      tooltip: context.t('daily_verse.share'),
                      icon: const Icon(Icons.share_outlined),
                      onPressed: () => showVerseShareChoiceSheet(
                        context,
                        text: verseText,
                        reference: reference,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
