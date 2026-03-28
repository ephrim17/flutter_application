import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';
import 'package:flutter_application/church_app/models/home_section_models/announcement_model.dart';
import 'package:flutter_application/church_app/providers/home_sections/announcement_providers.dart';
import 'package:flutter_application/church_app/screens/home/home_screen.dart';
import 'package:flutter_application/church_app/services/analytics/firebase_analytics_helper.dart';
import 'package:flutter_application/church_app/widgets/autoscroll_widget.dart';
import 'package:flutter_application/church_app/widgets/detail_widget.dart';
import 'package:flutter_application/church_app/widgets/media_detail_card_widget.dart';
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
                child: Text(
                  "${context.t('common.error_prefix', fallback: 'Error')}: $e",
                ),
              ),
              data: (items) => _AnnouncementList(items),
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
      return Padding(
        padding: const EdgeInsets.all(16),
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
          text: context.t(
            'announcements.section_title',
            fallback: 'Announcements',
          ),
          padding: 16.0,
        ),
        const SizedBox(height: 10),
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

class _AnnouncementCard extends ConsumerWidget {
  const _AnnouncementCard(this.a);
  final Announcement a;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () async {
        await logChurchAnalyticsEvent(
          ref,
          name: 'announcement_opened',
          parameters: {
            'announcement_id': a.id,
            'source': 'home',
          },
        );
        if (!context.mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => DetailWidget(
              title: a.title,
              description: a.body,
              imageUrl: a.imageUrl,
            ),
          ),
        );
      },
      child: MediaDetailCard(
        height: cardHeight(AnnouncementSection().id),
        badgeText: 'Announcement',
        title: a.title,
        body: a.body,
        topChild: a.imageUrl.trim().isNotEmpty
            ? _AnnouncementBackgroundImage(imageUrl: a.imageUrl)
            : Container(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.08),
                alignment: Alignment.center,
                child: Icon(
                  Icons.campaign_outlined,
                  size: 48,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
      ),
    );
  }
}

class _AnnouncementBackgroundImage extends StatelessWidget {
  const _AnnouncementBackgroundImage({
    required this.imageUrl,
  });

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return ShimmerImage(
      imageUrl: imageUrl,
      aspectRatio: 16 / 9,
      borderRadius: 0,
      fit: BoxFit.cover,
    );
  }
}
