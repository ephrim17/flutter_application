import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';
import 'package:flutter_application/church_app/providers/home_sections/home_section_config_providers.dart';
import 'package:flutter_application/church_app/widgets/announcement_widget.dart';
import 'package:flutter_application/church_app/widgets/events_widget.dart';
import 'package:flutter_application/church_app/widgets/pastor_widget.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
//import 'home_sections_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sectionConfigsAsync = ref.watch(homeSectionConfigsProvider);

    return sectionConfigsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (configs) {
        final registry = HomeSectionRegistry.all();

        // 🔹 Enable / disable + order
        final activeSections = registry.where((section) {
          final config = configs.where((c) => c.id == section.id).firstOrNull;
          return config?.enabled ?? false;
        }).map((section) {
          final config = configs.firstWhere((c) => c.id == section.id);
          return _OrderedSection(section, config.order);
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

/// A reusable section that can render itself into the home scroll.
abstract class HomeSection {
  String get id;

  /// Lower number shows earlier in the page.
  int get order;

  /// Return one or more slivers (so everything is one scroll).
  List<Widget> buildSlivers(BuildContext context);
}

class HomeSectionRegistry {
  static List<HomeSection> all() => const [
        AnnouncementWidget(),
        EventsWidget(),
        PastorWidget()
      ];
}

class _OrderedSection {
  const _OrderedSection(this.section, this.order);

  final HomeSection section;
  final int order;
}
