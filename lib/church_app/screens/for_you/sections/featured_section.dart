import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/screens/for_you/bibleVerse/bible_swipe_screen.dart';
import 'package:flutter_application/church_app/screens/for_you/sermon_screen.dart';
import 'package:flutter_application/church_app/screens/for_you/shorts_feed_screen.dart';
import 'package:flutter_application/church_app/screens/home/home_screen.dart';
import 'package:flutter_application/church_app/helpers/youtube_utils.dart';

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
          padding: const EdgeInsets.only(left: 16, right: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
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
                  // child: GridView(
                  //     gridDelegate:
                  //         const SliverGridDelegateWithFixedCrossAxisCount(
                  //             crossAxisCount: 2,
                  //             childAspectRatio: 1.5,
                  //             mainAxisSpacing: 10,
                  //             crossAxisSpacing: 10),
                  //     children: [
                  //       FeaturedItemWidget(title: "Shorts",),
                  //       FeaturedItemWidget(title: "Sermons",),
                  //     ]),
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
                          builder: (_) => BibleSwipeScreen(),
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

class FeaturedItemWidget extends StatelessWidget {
  const FeaturedItemWidget({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) {
              if (title == "Shorts") {
                return const ShortsFeedScreen();
              } else {
                return const SermonsScreen();
              }
            },
          ),
        ),
      },
      splashColor: Colors.red,
      borderRadius: BorderRadius.circular(10),
      child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16.0),
            gradient: LinearGradient(
                colors: [Colors.red, Colors.red.withBlue(100)],
                begin: Alignment.bottomRight,
                end: Alignment.topLeft),
          ),
          child: Center(
              child: Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium,
          ))),
    );
  }
}
