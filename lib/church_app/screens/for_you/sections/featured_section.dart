import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/providers/church_provider.dart';
import 'package:flutter_application/church_app/providers/select_church_provider.dart';
import 'package:flutter_application/church_app/screens/for_you/bible_swipe/bible_verse_swipe_screen.dart';
import 'package:flutter_application/church_app/screens/for_you/reading_plan/plan_list_screen.dart';
import 'package:flutter_application/church_app/screens/home/home_screen.dart';
import 'package:flutter_application/church_app/helpers/youtube_utils.dart';
import 'package:flutter_application/church_app/widgets/card_Link_button_widget.dart';
import 'package:flutter_application/church_app/widgets/featured_card_widget.dart';
import 'package:flutter_application/church_app/widgets/section_header_widget.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FeaturedSection implements MasterSection {
  const FeaturedSection();

  @override
  String get id => 'featured';

  @override
  int get order => 20;

  @override
  List<Widget> buildSlivers(BuildContext context) {
    //final width = MediaQuery.of(context).size.width;
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              SectionHeader(
                text: context.t(
                  'for_you.featured.plans_section_title',
                  fallback: 'Plans for you ✮',
                ),
                padding: 0.0,
              ),
              const SizedBox(height: 10),
              FeaturedCard(
                badgeText: context.t(
                  'for_you.featured.plan_badge',
                  fallback: 'Challenge Yourself to do',
                ),
                title: context.t(
                  'for_you.featured.plan_title',
                  fallback: 'Bible in a year',
                ),
                description: context.t(
                  'for_you.featured.plan_description',
                  fallback:
                      "Reading the Bible in a year won't just change what you know; it will change how you think. You are trading 15 minutes of scrolling for a lifetime of wisdom",
                ),
                buttonText: context.t(
                  'for_you.featured.plan_button',
                  fallback: 'Explore Now',
                ),
                imagePath: "assets/images/bible_read.png",
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PlanListScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              SectionHeader(
                text: context.t(
                  'for_you.featured.section_title',
                  fallback: 'Featured for you ✮',
                ),
                padding: 0.0,
              ),
              const SizedBox(height: 10),
              Consumer(
                builder: (context, ref, _) {
                  final churchId = ref.watch(currentChurchIdProvider).value;
                  if (churchId == null || churchId.trim().isEmpty) {
                    return const SizedBox.shrink();
                  }
                  final youtubeLink =
                      ref.watch(churchByIdProvider(churchId)).maybeWhen(
                            data: (church) => church?.youtubeLink ?? '',
                            orElse: () => '',
                          );

                  if (youtubeLink.trim().isEmpty) {
                    return const SizedBox.shrink();
                  }

                  return CardLinkButtonWidget(
                    title: context.t(
                      'for_you.featured.youtube_title',
                      fallback:
                          'Deepen the Word, One Video at a Time. Follow us on YouTube.',
                    ),
                    buttonText: context.t(
                      'for_you.featured.youtube_button',
                      fallback: 'Start Watching',
                    ),
                    iconStyle: Icon(
                      Icons.video_collection,
                      color: Theme.of(context).colorScheme.primary,
                      size: 28,
                    ),
                    onPressed: () {
                      YoutubeUtils.openYoutubeChannel(youtubeLink);
                    },
                  );
                },
              ),
              Consumer(
                builder: (context, ref, _) {
                  final churchId = ref.watch(currentChurchIdProvider).value;
                  if (churchId == null || churchId.trim().isEmpty) {
                    return const SizedBox(height: 20);
                  }
                  final youtubeLink =
                      ref.watch(churchByIdProvider(churchId)).maybeWhen(
                            data: (church) => church?.youtubeLink ?? '',
                            orElse: () => '',
                          );

                  return SizedBox(height: youtubeLink.trim().isEmpty ? 20 : 30);
                },
              ),
              CardLinkButtonWidget(
                title: context.t(
                  'for_you.featured.swipe_title',
                  fallback:
                      'Got 2 minutes? That’s enough to fuel your soul. Swipe some verses.',
                ),
                buttonText: context.t(
                  'for_you.featured.swipe_button',
                  fallback: 'Let’s Go',
                ),
                iconStyle: Icon(
                  Icons.swipe_up,
                  color: Theme.of(context).colorScheme.primary,
                  size: 28,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BibleSwipeVerseScreen(),
                    ),
                  );
                },
              )
            ],
          ),
        ),
      ),
    ];
  }
}
