import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/screens/for_you/bible_swipe/bible_verse_swipe_screen.dart';
import 'package:flutter_application/church_app/screens/for_you/reading_plan/plan_list_screen.dart';
import 'package:flutter_application/church_app/screens/home/home_screen.dart';
import 'package:flutter_application/church_app/helpers/youtube_utils.dart';
import 'package:flutter_application/church_app/widgets/section_header_widget.dart';

class FeaturedSection implements MasterSection {
  const FeaturedSection();

  @override
  String get id => 'featured';

  @override
  int get order => 20;

  @override
  List<Widget> buildSlivers(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              SectionHeader(text: "✮ Featured for you ✮", padding: 0.0),
              const SizedBox(height: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader(text: "Bible in a year", padding: 0.0),
                  PlanListScreen(),
                ],
              ),
              SizedBox(
                  height: 50,
                  width: width * 0.9,
                  child: ElevatedButton(
                    onPressed: () {
                      // Replace with your YouTube channel ID
                      YoutubeUtils.openYoutubeChannel(
                          'UCfMUXhM4ujEI8aDTAh34K3A');
                    },
                    child: const Text('watch us on YouTube'),
                  )
                  ),
              const SizedBox(height: 10),
              SizedBox(
                  height: 50,
                  width: width * 0.9,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BibleSwipeVerseScreen(),
                        ),
                      );
                    },
                    child: const Text('Bible Swipes'),
                  ))
            ],
          ),
        ),
      ),
    ];
  }
}
