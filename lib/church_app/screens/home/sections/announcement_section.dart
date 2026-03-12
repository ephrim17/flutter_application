import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
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
                      child: Text("${context.t('common.error_prefix', fallback: 'Error')}: $e"),
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
      return Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          context.t('announcements.none', fallback: 'No announcements'),
        ),
      );
    }

    final screenWidth = MediaQuery.sizeOf(context).width;
    final viewportFraction = screenWidth >= 1400
        ? 0.72
        : screenWidth >= 1024
            ? 0.82
            : 0.92;
    final maxWidth = screenWidth >= 1024 ? 1100.0 : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          text: context.t('announcements.section_title', fallback: 'Announcements'),
          padding: 16.0,
        ),
        const SizedBox(
          height: 10,
        ),
        Align(
          alignment: Alignment.center,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth ?? double.infinity),
            child: AutoScrollCarousel(
              height: cardHeight(AnnouncementSection().id),
              itemCount: items.length,
              viewportFraction: viewportFraction,
              autoScroll: true,
              spacing: 12,
              itemBuilder: (_, i) => _AnnouncementCard(items[i]),
            ),
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
        width: double.infinity,
        height: cardHeight(AnnouncementSection().id),
        padding: const EdgeInsets.all(2),
        decoration: carouselBoxDecoration(context),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(cornerRadius), // SAME radius
            child: a.imageUrl.isNotEmpty ?  ShimmerImage(
              imageUrl: a.imageUrl,
            ) : Padding(
              padding: const EdgeInsets.all(12.0),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      a.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      a.body,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ) ,
          ),
        ),
      ),
    );
  }
}
