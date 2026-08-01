import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/widgets/app_loading_indicator.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';
import 'package:flutter_application/church_app/providers/for_you_sections/for_you_section_config_providers.dart';
import 'package:flutter_application/church_app/providers/for_you_sections/live_church_provider.dart';
import 'package:flutter_application/church_app/screens/footer_sections/footer_section.dart';
import 'package:flutter_application/church_app/screens/for_you/sections/article_section.dart';
import 'package:flutter_application/church_app/screens/for_you/sections/daily_verse_section.dart';
import 'package:flutter_application/church_app/screens/for_you/sections/featured_section.dart';
import 'package:flutter_application/church_app/screens/for_you/sections/faith_engagement_section.dart';
import 'package:flutter_application/church_app/screens/for_you/sections/live_church_section.dart';
import 'package:flutter_application/church_app/screens/for_you/sections/pray_for_others_section.dart';
import 'package:flutter_application/church_app/screens/home/home_screen.dart';
import 'package:flutter_application/church_app/services/notification_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ForYouScreen extends ConsumerStatefulWidget {
  const ForYouScreen({super.key});

  @override
  ConsumerState<ForYouScreen> createState() => _ForYouScreenState();
}

class _ForYouScreenState extends ConsumerState<ForYouScreen> {
  final _scrollController = ScrollController();
  final _prayForOthersKey = GlobalKey();
  final _faithEngagementKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    notificationDestinationRequest.addListener(_handleSectionRequest);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _handleSectionRequest());
  }

  @override
  void dispose() {
    notificationDestinationRequest.removeListener(_handleSectionRequest);
    _scrollController.dispose();
    super.dispose();
  }

  void _handleSectionRequest() {
    final destination = notificationDestinationRequest.value;
    if (destination != NotificationDestination.prayForOthers &&
        destination != NotificationDestination.faithEngagement) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final sectionContext =
          destination == NotificationDestination.faithEngagement
              ? _faithEngagementKey.currentContext
              : _prayForOthersKey.currentContext;
      if (sectionContext == null) return;

      notificationDestinationRequest.value = null;
      Scrollable.ensureVisible(
        sectionContext,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        alignment: 0.08,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final sectionConfigsAsync = ref.watch(forYouSectionConfigsProvider);
    final liveChurchStatus = ref.watch(liveChurchStatusProvider).asData?.value;

    return sectionConfigsAsync.when(
      loading: () => const Center(child: AppLoadingIndicator()),
      error: (e, _) => Center(
        child: Text("${context.t('common.error_prefix')}: $e"),
      ),
      data: (configs) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _handleSectionRequest(),
        );
        final registry = ForYouSectionRegistry.all(
          prayForOthersKey: _prayForOthersKey,
          faithEngagementKey: _faithEngagementKey,
        );

        // 🔹 Enable / disable + order
        final activeSections = registry.where((section) {
          final config = configs.where((c) => c.id == section.id).firstOrNull;
          if (section.id == 'liveChurch' &&
              !(liveChurchStatus?.canPlay ?? false)) {
            return false;
          }
          if (section.id == 'prayForOthers') return true;
          if (section.id == 'faithEngagement') return true;
          return config?.enabled ?? false;
        }).map((section) {
          final config = configs.where((c) => c.id == section.id).firstOrNull;
          return OrderedSectionForYou(section, config?.order ?? section.order);
        }).toList()
          ..sort((a, b) => a.order.compareTo(b.order));

        _movePrayForOthersAbovePlans(activeSections);

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
          controller: _scrollController,
          slivers: slivers,
        );
      },
    );
  }
}

void _movePrayForOthersAbovePlans(
  List<OrderedSectionForYou> sections,
) {
  final prayerIndex =
      sections.indexWhere((item) => item.section.id == 'prayForOthers');
  final plansIndex =
      sections.indexWhere((item) => item.section.id == 'featured');
  if (prayerIndex < 0 || plansIndex < 0 || prayerIndex < plansIndex) return;

  final prayerSection = sections.removeAt(prayerIndex);
  final updatedPlansIndex =
      sections.indexWhere((item) => item.section.id == 'featured');
  sections.insert(updatedPlansIndex, prayerSection);
}

class ForYouSectionRegistry {
  static List<MasterSection> all({
    GlobalKey? prayForOthersKey,
    GlobalKey? faithEngagementKey,
  }) =>
      [
        const LiveChurchSection(),
        DailyVerseSection(),
        FaithEngagementSection(anchorKey: faithEngagementKey),
        FeaturedSection(),
        PrayForOthersSection(anchorKey: prayForOthersKey),
        FooterSection(),
        ArticleSection()
      ];
}

class OrderedSectionForYou {
  const OrderedSectionForYou(this.section, this.order);

  final MasterSection section;
  final int order;
}
