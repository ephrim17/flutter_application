import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/widgets/app_loading_indicator.dart';
import 'package:flutter_application/church_app/widgets/app_modal_bottom_sheet.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';
import 'package:flutter_application/church_app/models/app_config_model.dart';
import 'package:flutter_application/church_app/providers/home_sections/home_section_config_providers.dart';
import 'package:flutter_application/church_app/providers/prompt_sequence_provider.dart';
import 'package:flutter_application/church_app/providers/user_provider.dart';
import 'package:flutter_application/church_app/screens/home/sections/announcement_section.dart';
import 'package:flutter_application/church_app/screens/home/sections/events_section.dart';
import 'package:flutter_application/church_app/screens/footer_sections/footer_section.dart';
import 'package:flutter_application/church_app/screens/home/sections/promise_section.dart';
import 'package:flutter_application/church_app/screens/side_drawer/settings_screen.dart'
    show showEditProfileSheet;
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
  ProviderSubscription<bool>? _notificationPromptListener;
  bool _isDrainingPrompts = false;
  bool _promptDrainRequested = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      _announcementListener = ref.listenManual<PromptSheetModel?>(
        isAnnouncementEnabledProvider,
        (previous, next) async {
          if (next?.enabled ?? false) {
            await _drainPrompts();
          }
        },
      );

      _birthdayListener = ref.listenManual<bool>(
        isBirthdayProvider,
        (previous, next) async {
          if (next == true) {
            await _drainPrompts();
          }
        },
      );

      _notificationPromptListener = ref.listenManual<bool>(
        notificationPromptCompletedProvider,
        (previous, next) async {
          if (next) {
            await _drainPrompts();
          }
        },
      );

      await _drainPrompts();
    });
  }

  @override
  void dispose() {
    _announcementListener?.close();
    _birthdayListener?.close();
    _notificationPromptListener?.close();
    super.dispose();
  }

  Future<void> _drainPrompts() async {
    if (!mounted) return;
    _promptDrainRequested = true;
    if (_isDrainingPrompts) return;

    _isDrainingPrompts = true;
    try {
      while (mounted && _promptDrainRequested) {
        _promptDrainRequested = false;

        if (!ref.read(notificationPromptCompletedProvider)) return;

        final showedPrompt = await _showNextEligiblePrompt();
        if (showedPrompt) {
          _promptDrainRequested = true;
        }
      }
    } finally {
      _isDrainingPrompts = false;
    }
  }

  Future<bool> _showNextEligiblePrompt() async {
    final announcement = ref.read(isAnnouncementEnabledProvider);
    if (!mounted) return false;
    final pendingPrompt = nextEligibleHomePrompt(
      notificationPromptCompleted:
          ref.read(notificationPromptCompletedProvider),
      announcement: announcement,
      isBirthday: ref.read(isBirthdayProvider),
      shownPromptKeys: ref.read(promptSessionShownProvider),
    );
    if (pendingPrompt == null) return false;

    return _maybeShowPrompt(
      pendingPrompt.type,
      promptSheetModel: pendingPrompt.model,
    );
  }

  Future<bool> _maybeShowPrompt(
    PromptType sheetType, {
    PromptSheetModel? promptSheetModel,
  }) async {
    if (!mounted) return false;

    final key = promptSessionKey(sheetType, promptSheetModel);
    final shownPrompts = ref.read(promptSessionShownProvider);

    if (shownPrompts.contains(key)) return false;

    ref.read(promptSessionShownProvider.notifier).state = {
      ...shownPrompts,
      key,
    };
    await showPromptSheet(sheetType, promptSheetModel);
    return true;
  }

  Future<dynamic> showPromptSheet(
      PromptType sheetType, PromptSheetModel? promptSheetModel) {
    return showAppModalBottomSheet(
      context: context,
      isScrollControlled: true,
      heightFactor: sheetType == PromptType.announcement ? 0.55 : 0.9,
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
    final userAsync = ref.watch(userIdentityProvider);

    return sectionConfigsAsync.when(
      loading: () => const Center(child: AppLoadingIndicator()),
      error: (e, _) => Center(
        child: Text("${context.t('common.error_prefix')}: $e"),
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
        final appUser = userAsync.asData?.value;
        final userName = appUser?.name.trim() ?? '';

        if (userName.isNotEmpty) {
          slivers.add(
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: HomeCardAlign(
                  child: _WelcomeCard(
                    userName: userName,
                    dayStreak: appUser?.dayStreak ?? 10,
                    showSetupProfilePrompt:
                        appUser != null && !appUser.profileComplete,
                    onSetupProfile: appUser == null
                        ? null
                        : () => showEditProfileSheet(context, appUser),
                  ),
                ),
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
    required this.dayStreak,
    required this.showSetupProfilePrompt,
    required this.onSetupProfile,
  });

  final String userName;
  final int dayStreak;

  /// True once `users/{uid}.profileComplete` is false — see the field's own
  /// doc comment in `UserIdentity` ("drives the non-blocking completion
  /// prompt").
  final bool showSetupProfilePrompt;
  final VoidCallback? onSetupProfile;

  ({IconData icon, String label}) _greetingVisualForHour(
    BuildContext context,
    int hour,
  ) {
    if (hour < 5) {
      return (
        icon: Icons.nightlight_round,
        label: context.t('ui.home.late_night')
      );
    }
    if (hour < 8) {
      return (
        icon: Icons.wb_twilight_outlined,
        label: context.t('ui.home.early_morning')
      );
    }
    if (hour < 12) {
      return (
        icon: Icons.wb_sunny_outlined,
        label: context.t('ui.home.morning')
      );
    }
    if (hour < 17) {
      return (
        icon: Icons.light_mode_outlined,
        label: context.t('ui.home.afternoon')
      );
    }
    if (hour < 20) {
      return (icon: Icons.wb_twilight, label: context.t('ui.home.evening'));
    }
    return (icon: Icons.dark_mode_outlined, label: context.t('ui.home.night'));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final secondary = theme.colorScheme.secondary;
    final onPrimary = theme.colorScheme.onPrimary;
    final greetingVisual = _greetingVisualForHour(
      context,
      DateTime.now().hour,
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(cornerRadius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primary.withValues(alpha: 0.96),
            secondary.withValues(alpha: 0.88),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -26,
            top: -18,
            child: Container(
              width: 122,
              height: 122,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            right: 42,
            bottom: -30,
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.18),
                          ),
                        ),
                        child: Text(
                          context.t('ui.home.welcome_back'),
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: onPrimary.withValues(alpha: 0.96),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        userName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: onPrimary,
                          height: 1.05,
                        ),
                      ),
                      if (dayStreak > 0) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.18),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.local_fire_department_outlined,
                                color: onPrimary,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              // Flexible, or the pill overflows its card on
                              // a narrow phone: at 320dp this row was 61px
                              // wider than the space it had. Wrapping keeps
                              // every word, which ellipsis would not.
                              Flexible(
                                child: Text(
                                  context.t(
                                    'home.current_streak',
                                    parameters: {'count': '$dayStreak'},
                                  ),
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: onPrimary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (showSetupProfilePrompt) ...[
                        const SizedBox(height: 14),
                        InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: onSetupProfile,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.18),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.person_outline,
                                  color: onPrimary,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  context.t('home.setup_profile_action'),
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: onPrimary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  color: onPrimary,
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    greetingVisual.icon,
                    color: onPrimary,
                    size: 30,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared geometry for the Home page's cards.
///
/// Events and Announcements are carousels; Promise Word is a single card
/// between them. Their left and right edges have to agree, and a carousel
/// card does not sit flush with its carousel — a `PageView` with a
/// viewport fraction below 1 insets the current page, and each page is then
/// padded by half the spacing. These functions are the one place that
/// arithmetic lives, so the single card can line itself up with cards it
/// cannot see. `test/home_card_alignment_test.dart` asserts the alignment at
/// both a phone and a desktop width.

/// Gap between two carousel cards. Each page carries half of it per side,
/// which is why the inset below adds `spacing / 2` rather than `spacing`.
const double homeCarouselSpacing = 12.0;

/// Past this width the page stops stretching and centres its content; a
/// full-bleed card on a desktop window reads as a banner, not a card.
const double _homeWideBreakpoint = 700.0;

/// Widest the Home content is allowed to get.
const double _homeMaxContentWidth = 700.0;

/// The cap a Home section's content is laid out within, or null on a narrow
/// screen where it simply fills the width.
double? homeSectionMaxWidth(double screenWidth) =>
    screenWidth > _homeWideBreakpoint ? _homeMaxContentWidth : null;

/// How much of the carousel a single card occupies. Below 1 so the next
/// card peeks in and the carousel reads as scrollable without a hint.
double homeCarouselViewportFraction(double screenWidth) => 0.9;

/// Distance from a carousel's own left edge to the left edge of the card
/// inside it: half the viewport the card does not fill, plus the page's
/// half-spacing. Promise Word pads itself by this much so its edges land on
/// the carousel cards above and below it.
double homeCarouselCardInset(double screenWidth) {
  final carouselWidth = homeSectionMaxWidth(screenWidth) ?? screenWidth;
  final unfilled =
      carouselWidth * (1 - homeCarouselViewportFraction(screenWidth)) / 2;
  return unfilled + homeCarouselSpacing / 2;
}

/// The width a Home card actually occupies — the content column less the
/// inset a carousel page imposes on both sides. This is the page's real
/// visible card edge, which is what every other surface should line up
/// with, rather than the column that contains it.
double homeCardWidth(double screenWidth) {
  final columnWidth = homeSectionMaxWidth(screenWidth) ?? screenWidth;
  return columnWidth - homeCarouselCardInset(screenWidth) * 2;
}

/// Puts a section's content on the page's shared card edges: centred within
/// the content column, then inset to where a carousel page puts its card.
///
/// A heading wrapped in this lands on the left edge of the card it labels,
/// and a single full-width card (the welcome card, the footer) lands on the
/// same edges as the carousel cards above and below it. Below the wide
/// breakpoint the column is the screen, so this is only the inset.
class HomeCardAlign extends StatelessWidget {
  const HomeCardAlign({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final maxWidth = homeSectionMaxWidth(screenWidth);

    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth ?? double.infinity),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: homeCarouselCardInset(screenWidth),
          ),
          child: child,
        ),
      ),
    );
  }
}
