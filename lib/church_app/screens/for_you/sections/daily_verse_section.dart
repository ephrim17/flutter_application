import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';
import 'package:flutter_application/church_app/providers/for_you_sections/daily_verse_providers.dart';
import 'package:flutter_application/church_app/providers/language_provider.dart';
import 'package:flutter_application/church_app/screens/home/home_screen.dart';
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
        child: Consumer(
          builder: (context, ref, _) {
            final asyncBanner = ref.watch(dailyVerseProvider);
            return asyncBanner.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: LinearProgressIndicator(),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Error: $e'),
              ),
              data: (items) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    //SectionHeader(text: "Daily verse", padding: 0.0,),
                    const SizedBox(height: 10,),
                    DailyVerseCard(),
                  ],
                ),
              )
            );
          },
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
        final verseText = language == BibleLanguage.tamil
            ? verse['tamil']
            : verse['english'];

        return Container(
          width: width - 32,
          padding: const EdgeInsets.all(12),
          decoration: carouselBoxDecoration(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// 🔹 Header row with toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SectionHeader(text: "Daily verse", padding: 0.0,),
                  BibleLanguageToggle(provider: dailyVerseLanguageProvider,),
                ],
              ),
              const SizedBox(height: 12),

              /// 🔹 Verse text
              Text(
                verseText!,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  height: 1.4,
                ),
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