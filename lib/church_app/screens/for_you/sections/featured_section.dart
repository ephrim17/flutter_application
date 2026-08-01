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
                text: context.t('for_you.featured.plans_section_title'),
                padding: 0.0,
              ),
              const SizedBox(height: 10),
              FeaturedCard(
                badgeText: context.t('for_you.featured.plan_badge'),
                title: context.t('for_you.featured.plan_title'),
                description: context.t('for_you.featured.plan_description'),
                buttonText: context.t('for_you.featured.plan_button'),
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
                text: context.t('for_you.featured.section_title'),
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
                    title: context.t('for_you.featured.youtube_title'),
                    buttonText: context.t('for_you.featured.youtube_button'),
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
                title: context.t('for_you.featured.swipe_title'),
                buttonText: context.t('for_you.featured.swipe_button'),
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
