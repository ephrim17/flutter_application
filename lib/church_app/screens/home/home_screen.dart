import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';
import 'package:flutter_application/church_app/models/app_config_model.dart';
import 'package:flutter_application/church_app/providers/home_sections/home_section_config_providers.dart';
import 'package:flutter_application/church_app/providers/user_provider.dart';
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
  ProviderSubscription<PromptSheetModel?>? _announcementListener;
  ProviderSubscription<bool>? _birthdayListener;
  bool _isPromptOpen = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _announcementListener = ref.listenManual<PromptSheetModel?>(
        isAnnouncementEnabledProvider,
        (previous, next) async {
          if (next?.enabled ?? false) {
            await _maybeShowPrompt(
              PromptType.announcement,
              promptSheetModel: next,
            );
          }
        },
      );

      _birthdayListener = ref.listenManual<bool>(
        isBirthdayProvider,
        (previous, next) async {
          if (next == true) {
            await _maybeShowPrompt(PromptType.birthday);
          }
        },
      );

      await _showInitialPrompts();
    });
  }

  @override
  void dispose() {
    _announcementListener?.close();
    _birthdayListener?.close();
    super.dispose();
  }

  Future<void> _showInitialPrompts() async {
    final announcement = ref.read(isAnnouncementEnabledProvider);
    if (announcement?.enabled ?? false) {
      await _maybeShowPrompt(
        PromptType.announcement,
        promptSheetModel: announcement,
      );
    }

    if (ref.read(isBirthdayProvider) == true) {
      await _maybeShowPrompt(PromptType.birthday);
    }
  }

  Future<void> _maybeShowPrompt(
    PromptType sheetType, {
    PromptSheetModel? promptSheetModel,
  }) async {
    if (!mounted || _isPromptOpen) return;

    final key = promptSessionKey(sheetType, promptSheetModel);
    final shownPrompts = ref.read(promptSessionShownProvider);

    if (shownPrompts.contains(key)) return;

    ref.read(promptSessionShownProvider.notifier).state = {
      ...shownPrompts,
      key,
    };
    _isPromptOpen = true;

    try {
      await showPromptSheet(sheetType, promptSheetModel);
    } finally {
      _isPromptOpen = false;
    }
  }

  Future<dynamic> showPromptSheet(
      PromptType sheetType, PromptSheetModel? promptSheetModel) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => PromptSheet(
        type: sheetType,
        promptSheetModel: promptSheetModel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sectionConfigsAsync = ref.watch(homeSectionConfigsProvider);
    final userAsync = ref.watch(appUserProvider);

    return sectionConfigsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child:
            Text("${context.t('common.error_prefix', fallback: 'Error')}: $e"),
      ),
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
        final userName = userAsync.asData?.value?.name.trim() ?? '';

        if (userName.isNotEmpty) {
          slivers.add(
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: _WelcomeCard(userName: userName),
              ),
            ),
          );
        }

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

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({
    required this.userName,
  });

  final String userName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: carouselBoxDecoration(context),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome back,',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            userName,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
