import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';
import 'package:flutter_application/church_app/helpers/event_builders.dart';
import 'package:flutter_application/church_app/models/home_section_models/event_model.dart';
import 'package:flutter_application/church_app/providers/home_sections/event_providers.dart';
import 'package:flutter_application/church_app/screens/home/home_screen.dart';
import 'package:flutter_application/church_app/services/analytics/firebase_analytics_helper.dart';
import 'package:flutter_application/church_app/widgets/autoscroll_widget.dart';
import 'package:flutter_application/church_app/widgets/detail_widget.dart';
import 'package:flutter_application/church_app/widgets/media_detail_card_widget.dart';
import 'package:flutter_application/church_app/widgets/section_header_widget.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class EventsSection implements MasterSection {
  const EventsSection();

  @override
  String get id => 'events';

  @override
  int get order => 20;

  @override
  List<Widget> buildSlivers(BuildContext context) {
    return [
      SliverToBoxAdapter(
        child: Consumer(
          builder: (context, ref, _) {
            final asyncBanner = ref.watch(eventsProvider);

            return asyncBanner.when(
                loading: () => const Padding(
                      padding: EdgeInsets.all(16),
                      child: LinearProgressIndicator(),
                    ),
                error: (e, _) => Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text("${context.t('common.error_prefix', fallback: 'Error')}: $e"),
                    ),
                data: (items) => EventsList(items));
          },
        ),
      ),
    ];
  }
}

class EventsList extends StatelessWidget {
  const EventsList(
    this.items, {
    super.key,
    this.scrollDirection = Axis.horizontal,
  });

  final List<Event> items;
  final Axis scrollDirection;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          context.t('events.none', fallback: 'No Events'),
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
          text: context.t('events.section_title', fallback: 'Events'),
          padding: 16.0,
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.center,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth ?? double.infinity),
            child: SizedBox(
              height: cardHeight(EventsSection().id),
              child: AutoScrollCarousel(
                height: cardHeight(EventsSection().id),
                itemCount: items.length,
                viewportFraction: viewportFraction,
                spacing: 12,
                itemBuilder: (_, i) => EventsCard(items[i]),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class EventsCard extends ConsumerWidget {
  const EventsCard(this.a, {super.key});
  final Event a;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () async {
        await logChurchAnalyticsEvent(
          ref,
          name: 'event_opened',
          parameters: {
            'event_id': a.id,
            'source': 'home',
          },
        );
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) {
              return DetailWidget(
                title: a.title,
                description: a.description,
                contact: a.contact,
                location: a.location,
                imageUrl: a.type.imageAsset,
                timing: a.timing,
              );
            },
          ),
        );
      },
      child: MediaDetailCard(
        height: cardHeight(EventsSection().id),
        badgeText: a.type.label,
        badgeColor: a.type.badgeColor,
        title: a.title,
        body: a.description.trim().isEmpty ? a.timing : a.description,
        topChild: Image.asset(
          a.type.imageAsset,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: Theme.of(context)
                .colorScheme
                .primary
                .withValues(alpha: 0.08),
            alignment: Alignment.center,
            child: Icon(
              Icons.event_outlined,
              size: 44,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}
