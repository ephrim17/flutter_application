import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';
import 'package:flutter_application/church_app/providers/for_you_sections/daily_verse_providers.dart';
import 'package:flutter_application/church_app/providers/language_provider.dart';
import 'package:flutter_application/church_app/screens/home/home_screen.dart';
import 'package:flutter_application/church_app/widgets/modals/verse_share_modal.dart';
import 'package:flutter_application/church_app/widgets/section_header_widget.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application/church_app/widgets/language_toggle_widget.dart';

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

  Future<void> showVerseShareModal(
    BuildContext context, {
    required String text,
    required String reference,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VerseShareModal(
        text: text,
        reference: reference,
      ),
    );
  }

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

        return Container(
          width: width - 32,
          padding: const EdgeInsets.all(12),
          decoration: carouselBoxDecoration(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// 🔹 Header row with toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  SectionHeader(
                    text: "Daily verse",
                    padding: 0.0,
                  ),
                  Spacer(),
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

              /// 🔹 Verse text
              Text(
                verseText!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 6),

              /// 🔹 Reference
              Text(
                verse['reference']!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        );
      },
    );
  }
}
