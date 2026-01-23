import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/models/for_you_section_model/shorts_model.dart';
import 'package:flutter_application/church_app/providers/for_you_sections/shorts_provider.dart';
import 'package:flutter_application/church_app/screens/home/home_screen.dart';
import 'package:flutter_application/church_app/widgets/section_header_widget.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class FeaturedSection implements MasterSection {
  const FeaturedSection();

  @override
  String get id => 'featured';

  @override
  int get order => 20;

  @override
  List<Widget> buildSlivers(BuildContext context) {
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(left: 16, right: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              SectionHeader(text: "Featured"),
              const SizedBox(height: 10),
              SizedBox(
                height: 200,
                child: GridView(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 1.5,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10),
                    children: [
                      FeaturedItemWidget(title: "Shorts",),
                      FeaturedItemWidget(title: "Sermons",),
                    ]),
              )
            ],
          ),
        ),
      ),
    ];
  }
}

class FeaturedItemWidget extends StatelessWidget {
  const FeaturedItemWidget({
    super.key, required this.title
  });

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
                return const Placeholder();
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
                colors: [
                  Colors.red,
                  Colors.red.withBlue(100)
                ],
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

class ShortsFeedScreen extends ConsumerStatefulWidget {
  const ShortsFeedScreen({super.key});

  @override
  ConsumerState<ShortsFeedScreen> createState() => _ShortsFeedScreenState();
}

class _ShortsFeedScreenState extends ConsumerState<ShortsFeedScreen> {
  final PageController _pageController = PageController(initialPage: 0);

  @override
  Widget build(BuildContext context) {
    final shorts = ref.watch(shortsProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: shorts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (shortsList) => PageView.builder(
          controller: _pageController,
          scrollDirection: Axis.vertical,
          itemCount: shortsList.length,
          itemBuilder: (context, index) {
            final short = shortsList[index];
            return ShortsPlayerItem(short);
          },
        ),
      ),
    );
  }
}


class ShortsPlayerItem extends StatefulWidget {
  final ShortModel short;
  const ShortsPlayerItem(this.short, {super.key});

  @override
  State<ShortsPlayerItem> createState() => _ShortsPlayerItemState();
}

class _ShortsPlayerItemState extends State<ShortsPlayerItem> {
  late YoutubePlayerController controller;

  @override
  void initState() {
    super.initState();
    controller = YoutubePlayerController(
      initialVideoId: widget.short.videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        loop: true,
        controlsVisibleAtStart: false,
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //backgroundColor: Colors.black,
      //appBar: AppBar(
      //   title: Text(widget.short.title),
      //),
      body: Stack(
        children: [
          Center(
            child: FittedBox(
              fit: BoxFit.fill,
              child: SizedBox(
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height,
                child: YoutubePlayer(
                  controller: controller,
                  showVideoProgressIndicator: false,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
