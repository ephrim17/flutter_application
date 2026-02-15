import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';
import 'package:flutter_application/church_app/models/app_config_model.dart';
import 'package:flutter_application/church_app/providers/home_sections/home_section_config_providers.dart';
import 'package:flutter_application/church_app/screens/home/sections/announcement_section.dart';
import 'package:flutter_application/church_app/screens/home/sections/events_section.dart';
import 'package:flutter_application/church_app/screens/footer_sections/footer_section.dart';
import 'package:flutter_application/church_app/screens/home/sections/promise_section.dart';
import 'package:flutter_application/church_app/widgets/prompts/prompt_sheet.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
//import 'home_sections_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  // ignore: unused_field
  late final ProviderSubscription<bool> _birthdayListener;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final announcement = ref.read(isAnnouncementEnabledProvider);
      if (announcement?.enabled ?? false) {
        // ⏳ Wait until announcement sheet closes
        await showPromptSheet(PromptType.announcement, announcement);
      }

      // 🎂 Now check birthday AFTER announcement
      _birthdayListener = ref.listenManual<bool>(
        isBirthdayProvider,
        (previous, next) {
          if (next == true) {
            showPromptSheet(PromptType.birthday, null);
          }
        },
      );
    });
  }

  Future<dynamic> showPromptSheet(PromptType sheetType, PromptSheetModel? promptSheetModel) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => PromptSheet(type: sheetType, promptSheetModel: promptSheetModel,),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          return OrderedSectionHome(section, config.order);
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

        return CustomScrollView(slivers: slivers);
      },
    );
  }
}

/// A reusable section that can render itself into the home scroll.
abstract class MasterSection {
  String get id;

  /// Lower number shows earlier in the page.
  int get order;

  /// Return one or more slivers (so everything is one scroll).
  List<Widget> buildSlivers(BuildContext context);
}

class HomeSectionRegistry {
  static List<MasterSection> all() => [
        AnnouncementSection(),
        EventsSection(),
        FooterSection(),
        PromiseSection()
      ];
}

class OrderedSectionHome {
  const OrderedSectionHome(this.section, this.order);

  final MasterSection section;
  final int order;
}
