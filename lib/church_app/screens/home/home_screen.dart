import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';
import 'package:flutter_application/church_app/models/app_config_model.dart';
import 'package:flutter_application/church_app/models/app_user_model.dart';
import 'package:flutter_application/church_app/providers/home_sections/home_section_config_providers.dart';
import 'package:flutter_application/church_app/providers/church_provider.dart';
import 'package:flutter_application/church_app/providers/user_provider.dart';
import 'package:flutter_application/church_app/screens/home/sections/announcement_section.dart';
import 'package:flutter_application/church_app/screens/home/sections/events_section.dart';
import 'package:flutter_application/church_app/screens/footer_sections/footer_section.dart';
import 'package:flutter_application/church_app/screens/home/sections/promise_section.dart';
import 'package:flutter_application/church_app/services/church_user_repository.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_provider.dart';
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
  ProviderSubscription<AsyncValue<AppUser?>>? _streakListener;
  bool _isPromptOpen = false;
  String? _lastDailyStreakSyncKey;

  bool _isSameDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  Future<void> _syncDailyStreakIfNeeded(AppUser user) async {
    final churchId = await ref.read(currentChurchIdProvider.future);
    if (churchId == null || !mounted) return;

    final today = DateTime.now();
    if (user.lastStreakRecordedAt != null &&
        _isSameDay(user.lastStreakRecordedAt!, today)) {
      return;
    }

    final syncKey =
        '$churchId:${user.uid}:${today.year}-${today.month}-${today.day}';
    if (_lastDailyStreakSyncKey == syncKey) return;

    _lastDailyStreakSyncKey = syncKey;
    final repository = ChurchUsersRepository(
      firestore: ref.read(firestoreProvider),
      churchId: churchId,
    );

    try {
      await repository.updateDailyStreak(uid: user.uid);
      ref.invalidate(appUserProvider);
      ref.invalidate(getCurrentUserProvider);
    } catch (_) {
      _lastDailyStreakSyncKey = null;
    }
  }

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

      _streakListener = ref.listenManual<AsyncValue<AppUser?>>(
        appUserProvider,
        (previous, next) async {
          final user = next.asData?.value;
          if (user == null) return;
          await _syncDailyStreakIfNeeded(user);
        },
        fireImmediately: true,
      );

      final currentUser = await ref.read(getCurrentUserProvider.future);
      if (currentUser != null) {
        await _syncDailyStreakIfNeeded(currentUser);
      }

      await _showInitialPrompts();
    });
  }

  @override
  void dispose() {
    _announcementListener?.close();
    _birthdayListener?.close();
    _streakListener?.close();
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
        final appUser = userAsync.asData?.value;
        final userName = appUser?.name.trim() ?? '';

        if (appUser != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!mounted) return;
            await _syncDailyStreakIfNeeded(appUser);
          });
        }

        if (userName.isNotEmpty) {
          slivers.add(
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: _WelcomeCard(
                  userName: userName,
                  dayStreak: appUser?.dayStreak ?? 10,
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
  });

  final String userName;
  final int dayStreak;

  ({IconData icon, String label}) _greetingVisualForHour(int hour) {
    if (hour < 5) {
      return (icon: Icons.nightlight_round, label: 'Late night');
    }
    if (hour < 8) {
      return (icon: Icons.wb_twilight_outlined, label: 'Early morning');
    }
    if (hour < 12) {
      return (icon: Icons.wb_sunny_outlined, label: 'Morning');
    }
    if (hour < 17) {
      return (icon: Icons.light_mode_outlined, label: 'Afternoon');
    }
    if (hour < 20) {
      return (icon: Icons.wb_twilight, label: 'Evening');
    }
    return (icon: Icons.dark_mode_outlined, label: 'Night');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final secondary = theme.colorScheme.secondary;
    final onPrimary = theme.colorScheme.onPrimary;
    final greetingVisual = _greetingVisualForHour(DateTime.now().hour);

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
                          'Welcome back',
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
                      const SizedBox(height: 10),
                      Text(
                        'Here is a quick look at what is happening in your church today.',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: onPrimary.withValues(alpha: 0.88),
                          height: 1.35,
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
                              Text(
                                '$dayStreak day streak',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: onPrimary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
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
