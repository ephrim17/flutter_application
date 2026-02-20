import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';
import 'package:flutter_application/church_app/models/home_section_models/announcement_model.dart';
import 'package:flutter_application/church_app/providers/home_sections/announcement_providers.dart';
import 'package:flutter_application/church_app/screens/home/home_screen.dart';
import 'package:flutter_application/church_app/widgets/autoscroll_widget.dart';
import 'package:flutter_application/church_app/widgets/detail_widget.dart';
import 'package:flutter_application/church_app/widgets/section_header_widget.dart';
import 'package:flutter_application/church_app/widgets/shimmer_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AnnouncementSection implements MasterSection {
  const AnnouncementSection();

  @override
  String get id => 'announcements';

  @override
  int get order => 10;

  @override
  List<Widget> buildSlivers(BuildContext context) {
    return [
      SliverToBoxAdapter(
        child: Consumer(
          builder: (context, ref, _) {
            final asyncBanner = ref.watch(announcementsProvider);

            return asyncBanner.when(
                loading: () => const Padding(
                      padding: EdgeInsets.all(16),
                      child: LinearProgressIndicator(),
                    ),
                error: (e, _) => Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Error: $e'),
                    ),
                data: (items) => _AnnouncementList(items));
          },
        ),
      ),
    ];
  }
}

class _AnnouncementList extends StatelessWidget {
  const _AnnouncementList(this.items);
  final List<Announcement> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('No announcements'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(text: "Announcements", padding: 16.0),
        const SizedBox(
          height: 10,
        ),
        SizedBox(
          child: AutoScrollCarousel(
            height: cardHeight(AnnouncementSection().id),
            itemCount: items.length,
            viewportFraction: 0.92,
            autoScroll: true,
            spacing: 12,
            itemBuilder: (_, i) => _AnnouncementCard(items[i]),
          ),
        ),
      ],
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard(this.a);
  final Announcement a;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) {
              return DetailWidget(
                title: a.title,
                description: a.body,
                imageUrl: a.imageUrl, 
              );
            },
          ),
        );
      },
      child: Container(
        width: width - 32,
        height: cardHeight(AnnouncementSection().id),
        padding: const EdgeInsets.all(5),
        decoration: carouselBoxDecoration(context),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16), // SAME radius
            child: ShimmerImage(
              imageUrl: a.imageUrl,
            ),
          ),
        ),
      ),
    );
  }
}
