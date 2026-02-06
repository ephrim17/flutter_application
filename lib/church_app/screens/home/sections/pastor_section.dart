import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';
import 'package:flutter_application/church_app/models/home_section_models/pastor_model.dart';
import 'package:flutter_application/church_app/providers/home_sections/pastor_providers.dart';
import 'package:flutter_application/church_app/screens/home/home_screen.dart';
import 'package:flutter_application/church_app/widgets/section_header_widget.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PastorSection implements MasterSection {
  const PastorSection();

  @override
  String get id => 'pastor';

  @override
  int get order => 30;

  @override
  List<Widget> buildSlivers(BuildContext context) {
    return [
      SliverToBoxAdapter(
        child: Consumer(
          builder: (context, ref, _) {
            final asyncBanner = ref.watch(pastorsProvider);

            return asyncBanner.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: LinearProgressIndicator(),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Error: $e'),
              ),
              data: (items) => _PastorList(items)
            );
          },
        ),
      ),
    ];
  }
}


class _PastorList extends StatelessWidget {
  const _PastorList(this.items);
  final List<Pastor> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Something went wrong'),
      );
    }

    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(text: "Our Pastors", padding: 16.0,),
          const SizedBox(height: 10,),
          SizedBox(
            height: cardHeight(PastorSection().id),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 0),
              itemBuilder: (_, i) => _PastorCard(items[i]),
            ),
          ),
        ],
    );
  }
}

class _PastorCard extends StatelessWidget {
  const _PastorCard(this.a);
  final Pastor a;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: width - 32,
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
            Text(a.contact,
                maxLines: 3, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
