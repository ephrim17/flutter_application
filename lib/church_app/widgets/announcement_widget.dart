import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/models/announcements/announcement_model.dart';
import 'package:flutter_application/church_app/providers/announcements/announcement_providers.dart';
import 'package:flutter_application/church_app/screens/home/home_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AnnouncementWidget implements HomeSection {
  const AnnouncementWidget();

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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Announcements"),
          const SizedBox(height: 10,),
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => _AnnouncementCard(items[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard(this.a);
  final Announcement a;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color.fromARGB(31, 190, 0, 0)),
      ),
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
    );
  }
}
