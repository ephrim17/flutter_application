import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';
import 'package:flutter_application/church_app/helpers/event_builders.dart';
import 'package:flutter_application/church_app/models/home_section_models/event_model.dart';
import 'package:flutter_application/church_app/providers/home_sections/event_providers.dart';
import 'package:flutter_application/church_app/widgets/app_bar_title_widget.dart';
import 'package:flutter_application/church_app/widgets/app_loading_indicator.dart';
import 'package:flutter_application/church_app/widgets/blur_Image_text_widget.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

class EventsScreen extends ConsumerWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncEvents = ref.watch(eventsProvider);

    return Scaffold(
      appBar: AppBar(
        title: AppBarTitle(
          text: context.t('events.title'),
        ),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Expanded(
            child: asyncEvents.when(
              loading: () => const Center(child: AppLoadingIndicator()),
              error: (e, _) => Center(
                child: Text("${context.t('common.error_prefix')}: $e"),
              ),
              data: (items) => EventsFullList(items),
            ),
          ),
        ],
      ),
    );
  }
}

class EventsFullList extends StatelessWidget {
  const EventsFullList(this.items, {super.key});
  final List<Event> items;
  final String id = "eventsFullListCard";

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          context.t('events.none'),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (_, i) => SizedBox(
        height: cardHeight(id),
        child: BlurImageTextContainer(
          items[i].type.imageAsset,
          items[i].title,
          items[i].description,
          items[i].type.badgeColor,
          items[i].type.label,
          dateTimeLabel: _eventDateTimeLabel(items[i]),
        ),
      ),
    );
  }
}

String _eventDateTimeLabel(Event event) {
  final startAt = event.startAt;
  if (startAt != null) {
    return DateFormat('d MMM, h:mm a').format(startAt);
  }
  return event.timing.trim();
}
