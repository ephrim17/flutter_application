import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/widgets/app_loading_indicator.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/providers/for_you_sections/for_you_section_config_providers.dart';
import 'package:flutter_application/church_app/providers/for_you_sections/live_church_provider.dart';
import 'package:flutter_application/church_app/screens/footer_sections/footer_section.dart';
import 'package:flutter_application/church_app/screens/for_you/for_you_card_layout.dart';
import 'package:flutter_application/church_app/screens/for_you/sections/article_section.dart';
import 'package:flutter_application/church_app/screens/for_you/sections/daily_verse_section.dart';
import 'package:flutter_application/church_app/screens/for_you/sections/featured_section.dart';
import 'package:flutter_application/church_app/screens/for_you/sections/faith_engagement_section.dart';
import 'package:flutter_application/church_app/screens/for_you/sections/live_church_section.dart';
import 'package:flutter_application/church_app/screens/for_you/sections/learning_path_section.dart';
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
  final _dailyFaithLoopKey = GlobalKey();
  final _circlesKey = GlobalKey();

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
        destination != NotificationDestination.faithEngagement &&
        destination != NotificationDestination.circles) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final sectionContext = switch (destination) {
        NotificationDestination.faithEngagement =>
          _dailyFaithLoopKey.currentContext,
        NotificationDestination.circles => _circlesKey.currentContext,
        _ => _prayForOthersKey.currentContext,
      };
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
          dailyFaithLoopKey: _dailyFaithLoopKey,
          circlesKey: _circlesKey,
        );
        final configById = {for (final config in configs) config.id: config};

        // 🔹 Enable / disable + order
        final activeSections = registry.where((section) {
          final config = configById[section.id];
          if (section.id == 'liveChurch' &&
              !(liveChurchStatus?.canPlay ?? false)) {
            return false;
          }
          if (config != null) return config.enabled;
          if (section.id == 'prayForOthers') return true;
          if (section.id == 'faithEngagement') return true;
          if (section.id == 'learningPath') return true;
          return config?.enabled ?? false;
        }).map((section) {
          final config = configById[section.id];
          return OrderedSectionForYou(section, config?.order ?? section.order);
        }).toList()
          ..sort((a, b) => a.order.compareTo(b.order));

        final slivers = <Widget>[];

        for (final ordered in activeSections) {
          // The one and only gap between sections, and it belongs to the
          // section rather than sitting before it as a bare spacer: a
          // section that renders nothing today (no published modules, no
          // reflection) must cost nothing, not leave 24dp of empty page
          // behind. See `ForYouSectionSpacing`.
          for (final sliver in ordered.section.buildSlivers(context)) {
            slivers.add(_withSectionGap(sliver));
          }
        }
        // The last section needs the same breathing room below it that every
        // other section gets above the next one; the footer used to supply
        // its own and nothing else did. This one is unconditional — it
        // trails real content by definition.
        slivers.add(
          const SliverToBoxAdapter(
            child: SizedBox(height: forYouSectionGap),
          ),
        );

        return CustomScrollView(
          controller: _scrollController,
          slivers: slivers,
        );
      },
    );
  }
}

/// Gives one section's sliver the page's between-sections gap, in a form
/// that disappears when the section draws nothing.
///
/// Every For You section currently returns a single `SliverToBoxAdapter`,
/// whose box child can be measured; anything else falls back to ordinary
/// padding, which is the old behaviour and still correct for a section that
/// always renders.
/// The width cap is applied here too, in the one place every section passes
/// through, so no section has to remember it. It goes inside the spacing so
/// `ForYouSectionSpacing` still measures the content's real height.
Widget _withSectionGap(Widget sliver) {
  if (sliver is SliverToBoxAdapter && sliver.child != null) {
    final child = sliver.child!;
    // A group of sibling sections spaces its own parts; adding the page's
    // gap on top would double the space above its first heading. The marker
    // is checked before wrapping, since wrapping would hide it.
    if (child is ForYouSelfSpaced) {
      return SliverToBoxAdapter(child: ForYouContentWidth(child: child));
    }
    return SliverToBoxAdapter(
      child: ForYouSectionSpacing(child: ForYouContentWidth(child: child)),
    );
  }
  return SliverPadding(
    padding: const EdgeInsets.only(top: forYouSectionGap),
    sliver: sliver,
  );
}

class ForYouSectionRegistry {
  static List<MasterSection> all({
    GlobalKey? prayForOthersKey,
    GlobalKey? dailyFaithLoopKey,
    GlobalKey? circlesKey,
  }) =>
      [
        const LiveChurchSection(),
        DailyVerseSection(),
        FaithEngagementSection(
          dailyFaithLoopKey: dailyFaithLoopKey,
          circlesKey: circlesKey,
        ),
        const LearningPathSection(),
        PrayForOthersSection(anchorKey: prayForOthersKey),
        FeaturedSection(),
        FooterSection(),
        ArticleSection()
      ];
}

class OrderedSectionForYou {
  const OrderedSectionForYou(this.section, this.order);

  final MasterSection section;
  final int order;
}
