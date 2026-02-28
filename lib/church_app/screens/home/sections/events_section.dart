import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';
import 'package:flutter_application/church_app/helpers/event_builders.dart';
import 'package:flutter_application/church_app/models/home_section_models/event_model.dart';
import 'package:flutter_application/church_app/providers/home_sections/event_providers.dart';
import 'package:flutter_application/church_app/screens/home/home_screen.dart';
import 'package:flutter_application/church_app/widgets/autoscroll_widget.dart';
import 'package:flutter_application/church_app/widgets/blur_Image_text_widget.dart';
import 'package:flutter_application/church_app/widgets/detail_widget.dart';
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
                      child: Text('Error: $e'),
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
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('No Events'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(text: "Events", padding: 16.0),
        const SizedBox(height: 10),
        SizedBox(
            height: cardHeight(EventsSection().id),
            child: 
            AutoScrollCarousel(
                height: cardHeight(EventsSection().id),
                itemCount: items.length,
                viewportFraction: 0.92,
                spacing: 12,
                itemBuilder: (_, i) =>
                 EventsCard(items[i]),
              )
            ),
      ],
    );
  }
}

class EventsCard extends StatelessWidget {
  const EventsCard(this.a, {super.key});
  final Event a;

  @override
  Widget build(BuildContext context) {

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) {
              return DetailWidget(
                title: a.title,
                description: a.description,
              );
            },
          ),
        );
      },
      child: BlurImageTextContainer(
          a.type.imageAsset,
         a.title,
          a.description,
          a.type.badgeColor,
          a.type.label,
        ),
    );
  }
}
