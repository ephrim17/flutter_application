

import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/models/home_section_models/event_model.dart';
import 'package:flutter_application/church_app/providers/home_sections/event_providers.dart';
import 'package:flutter_application/church_app/screens/home/sections/events_section.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class EventsScreen extends ConsumerWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncEvents = ref.watch(eventsProvider);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Events'),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [

          // 👇 THIS is the key fix
          Expanded(
            child: asyncEvents.when(
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (e, _) => Center(
                child: Text('Error: $e'),
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

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('No Events'));
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (_, i) => EventsCard(items[i]),
    );
  }
}
