import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/screens/for_you/bible_swipe/bible_verse_swipe_screen.dart';
import 'package:flutter_application/church_app/screens/for_you/reading_plan/plan_list_screen.dart';
import 'package:flutter_application/church_app/screens/home/home_screen.dart';
import 'package:flutter_application/church_app/helpers/youtube_utils.dart';
import 'package:flutter_application/church_app/widgets/card_Link_button_widget.dart';
import 'package:flutter_application/church_app/widgets/featured_card_widget.dart';
import 'package:flutter_application/church_app/widgets/section_header_widget.dart';

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
              SectionHeader(text: "Plans for you ✮", padding: 0.0),
              const SizedBox(height: 10),
              FeaturedCard(
                badgeText: "Challenge Yourself to do",
                title: "Bible in a year",
                description:
                    "Reading the Bible in a year won't just change what you know; it will change how you think. You are trading 15 minutes of scrolling for a lifetime of wisdom",
                buttonText: "Explore Now",
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
              
              SectionHeader(text: "Featured for you ✮", padding: 0.0),

              const SizedBox(height: 10),
              

              CardLinkButtonWidget(
                title: "Deepen the Word, One Video at a Time. Follow us on YouTube.",
                buttonText: "Start Watching",
                iconStyle: Icon(
                  Icons.video_collection,
                  color: Theme.of(context).colorScheme.primary,
                  size: 28,
                ),
                onPressed: () {
                   YoutubeUtils.openYoutubeChannel(
                    'UCfMUXhM4ujEI8aDTAh34K3A');
                },
              ),

              const SizedBox(height: 10),

              CardLinkButtonWidget(
                title: "Got 2 minutes? That’s enough to fuel your soul. Swipe some verses.",
                buttonText: "Let’s Go",
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
