import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';
import 'package:flutter_application/church_app/helpers/event_builders.dart';
import 'package:flutter_application/church_app/models/home_section_models/event_model.dart';
import 'package:flutter_application/church_app/providers/home_sections/event_providers.dart';
import 'package:flutter_application/church_app/screens/home/home_screen.dart';
import 'package:flutter_application/church_app/screens/side_drawer/event_screen.dart';
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
  const EventsList(this.items,
      {super.key, this.scrollDirection = Axis.horizontal});
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(text: "Events"),
          const SizedBox(
            height: 10,
          ),
          SizedBox(
            height: cardHeight(EventsSection().id),
            child: ListView.separated(
              scrollDirection: scrollDirection,
              itemCount: items.length,
              separatorBuilder: (_, __) => SizedBox(
                  width: 12, height: scrollDirection == Axis.vertical ? 30 : 0),
              itemBuilder: (_, i) => EventsCard(items[i]),
            ),
          ),
        ],
      ),
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
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(cornerRadius),
          border: Border.all(color: const Color.fromARGB(31, 190, 0, 0)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                a.type.imageAsset,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Text(a.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(a.description,
                      maxLines: 3, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
