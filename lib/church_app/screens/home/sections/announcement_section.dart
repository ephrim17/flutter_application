import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';
import 'package:flutter_application/church_app/models/home_section_models/announcement_model.dart';
import 'package:flutter_application/church_app/providers/home_sections/announcement_providers.dart';
import 'package:flutter_application/church_app/screens/home/home_screen.dart';
import 'package:flutter_application/church_app/widgets/autoscroll_widget.dart';
import 'package:flutter_application/church_app/widgets/detail_widget.dart';
import 'package:flutter_application/church_app/widgets/section_header_widget.dart';
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
              data: (items) => _AnnouncementList(items)
            );
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
          const SizedBox(height: 10,),
          SizedBox(
            height: cardHeight(AnnouncementSection().id),
            child: AutoScrollCarousel(
                itemCount: items.length,
                viewportFraction: 0.92,
                spacing: 12,
                itemBuilder: (_, i) =>
                 _AnnouncementCard(items[i]),
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
              );
            },
          ),
        );
      },
      child: Container(
        width: width * 0.9,
        padding: const EdgeInsets.all(12),
        decoration: carouselBoxDecoration(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(a.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(a.body,
                maxLines: 3, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
