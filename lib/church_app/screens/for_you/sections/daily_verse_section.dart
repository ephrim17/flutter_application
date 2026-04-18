import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/providers/for_you_sections/daily_verse_providers.dart';
import 'package:flutter_application/church_app/providers/language_provider.dart';
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
            children: const [
              DailyVerseCard(),
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
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text(e.toString()),
      data: (verse) {
        final verseText =
            language == BibleLanguage.tamil ? verse['tamil'] : verse['english'];

        return DecoratedScriptureCard(
          width: width - 32,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const SectionHeader(
                    text: 'Daily verse',
                    padding: 0.0,
                  ),
                  const Spacer(),
                  BibleLanguageToggle(
                    provider: dailyVerseLanguageProvider,
                  ),
                  IconButton(
                    icon: const Icon(Icons.share_outlined),
                    onPressed: () async {
                      await showVerseShareModal(
                        context,
                        text: verseText!,
                        reference: verse['reference']!,
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                verseText!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 18.0,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 12),
              ScriptureReferencePill(
                reference: verse['reference']!,
              ),
            ],
          ),
        );
      },
    );
  }
}
