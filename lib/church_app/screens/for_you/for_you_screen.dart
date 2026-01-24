import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';
import 'package:flutter_application/church_app/providers/for_you_sections/for_you_section_config_providers.dart';
import 'package:flutter_application/church_app/screens/footer_sections/footer_section.dart';
import 'package:flutter_application/church_app/screens/for_you/sections/daily_verse_section.dart';
import 'package:flutter_application/church_app/screens/for_you/sections/featured_section.dart';
import 'package:flutter_application/church_app/screens/home/home_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
//import 'home_sections_provider.dart';

class ForYouScreen extends ConsumerWidget {
  const ForYouScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sectionConfigsAsync = ref.watch(forYouSectionConfigsProvider);

    return sectionConfigsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (configs) {
        final registry = ForYouSectionRegistry.all();

        // 🔹 Enable / disable + order
        final activeSections = registry.where((section) {
          final config = configs.where((c) => c.id == section.id).firstOrNull;
          return config?.enabled ?? false;
        }).map((section) {
          final config = configs.firstWhere((c) => c.id == section.id);
          return OrderedSectionForYou(section, config.order);
        }).toList()
          ..sort((a, b) => a.order.compareTo(b.order));

        final slivers = <Widget>[];

          for (final ordered in activeSections) {
          final spacing = spacingForOrder(ordered.order);

          // 🔹 Add spacing BEFORE section if needed
          if (spacing > 0) {
            slivers.add(
              SliverToBoxAdapter(
                child: SizedBox(height: spacing),
              ),
            );
          }
          // 🔹 Add section slivers
          slivers.addAll(
            ordered.section.buildSlivers(context),
          );
        }

        return CustomScrollView(
            slivers: slivers
        );
      },
    );
  }
}

class ForYouSectionRegistry {
  static List<MasterSection> all() => [
        DailyVerseSection(),
        FeaturedSection(),
        FooterSection()
      ];
}

class OrderedSectionForYou {
  const OrderedSectionForYou(this.section, this.order);

  final MasterSection section;
  final int order;
}