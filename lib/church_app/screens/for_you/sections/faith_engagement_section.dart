import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';
import 'package:flutter_application/church_app/models/faith_engagement_models.dart';
import 'package:flutter_application/church_app/providers/authentication/admin_provider.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
import 'package:flutter_application/church_app/providers/faith_engagement_providers.dart';
import 'package:flutter_application/church_app/providers/for_you_sections/for_you_section_config_providers.dart';
import 'package:flutter_application/church_app/providers/language_provider.dart';
import 'package:flutter_application/church_app/providers/user_provider.dart';
import 'package:flutter_application/church_app/screens/for_you/for_you_card_layout.dart';
import 'package:flutter_application/church_app/screens/home/home_screen.dart';
import 'package:flutter_application/church_app/services/side_drawer/bible_book_repository.dart';
import 'package:flutter_application/church_app/widgets/app_loading_indicator.dart';
import 'package:flutter_application/church_app/widgets/app_modal_bottom_sheet.dart';
import 'package:flutter_application/church_app/widgets/app_profile_avatar.dart';
import 'package:flutter_application/church_app/widgets/app_text_field.dart';
import 'package:flutter_application/church_app/widgets/language_toggle_widget.dart';
import 'package:flutter_application/church_app/widgets/section_header_widget.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class FaithEngagementSection implements MasterSection {
  const FaithEngagementSection({
    this.dailyFaithLoopKey,
    this.circlesKey,
  });

  final GlobalKey? dailyFaithLoopKey;
  final GlobalKey? circlesKey;

  @override
  String get id => 'faithEngagement';

  @override
  int get order => 12;

  @override
  List<Widget> buildSlivers(BuildContext context) => [
        SliverToBoxAdapter(
          child: _FaithEngagementContent(
            dailyFaithLoopKey: dailyFaithLoopKey,
            circlesKey: circlesKey,
          ),
        ),
      ];
}

class _FaithEngagementContent extends ConsumerWidget {
  const _FaithEngagementContent({
    required this.dailyFaithLoopKey,
    required this.circlesKey,
  });

  final GlobalKey? dailyFaithLoopKey;
  final GlobalKey? circlesKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configs =
        ref.watch(forYouSectionConfigsProvider).asData?.value ?? const [];
    final configById = {for (final config in configs) config.id: config};
    final items = <({String id, int order, Widget child})>[
      if (configById['dailyFaithLoop']?.enabled ?? true)
        (
          id: 'dailyFaithLoop',
          order: configById['dailyFaithLoop']?.order ?? 10,
          child: KeyedSubtree(
            key: dailyFaithLoopKey,
            child: const _DailyFaithLoopContent(),
          ),
        ),
      if (configById['circles']?.enabled ?? true)
        (
          id: 'circles',
          order: configById['circles']?.order ?? 30,
          child: KeyedSubtree(
            key: circlesKey,
            child: const _CirclesContent(),
          ),
        ),
    ]..sort((left, right) => left.order.compareTo(right.order));

    if (items.isEmpty) return const SizedBox.shrink();
    return Column(children: items.map((item) => item.child).toList());
  }
}

class _DailyFaithLoopContent extends ConsumerWidget {
  const _DailyFaithLoopContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reflection = ref.watch(todayReflectionProvider).asData?.value;
    if (reflection == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            text: context.t('faith.today_heading'),
            padding: 16,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
            child: _TodayFaithCard(reflection: reflection),
          ),
        ],
      ),
    );
  }
}

class _CirclesContent extends ConsumerWidget {
  const _CirclesContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final circles = ref.watch(youthCirclesProvider).asData?.value ?? const [];
    if (circles.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            text: context.t('faith.circles_heading'),
            padding: 16,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
            child: Text(
              context.t('faith.circles_subtitle'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          SizedBox(
            height: 184,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: circles.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) => SizedBox(
                width: 184,
                child: _YouthCircleCard(circle: circles[index]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayFaithCard extends ConsumerWidget {
  const _TodayFaithCard({required this.reflection});

  final FaithReflection reflection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(dailyFaithProgressProvider).asData?.value ??
        const DailyFaithProgress(completedSteps: {});
    final completed = progress.completedSteps.length.clamp(0, 3);
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: forYouPrimaryCardHeight,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(cornerRadius),
          onTap: () => showAppModalBottomSheet<void>(
            context: context,
            heightFactor: 0.88,
            builder: (_) => _DailyFaithLoop(reflection: reflection),
          ),
          child: Ink(
            padding: const EdgeInsets.all(18),
            decoration: welcomeBackCardDecoration(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child:
                          const Icon(Icons.bolt_rounded, color: Colors.white),
                    ),
                    const Spacer(),
                    Text(
                      context.t('faith.minutes_label'),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  reflection.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.t('faith.loop_summary'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                ),
                const Spacer(),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: completed / 3,
                    minHeight: 7,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    color: colors.surface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.t(
                    'faith.steps_completed',
                    parameters: {'count': completed},
                  ),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Colors.white,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _YouthCircleCard extends StatelessWidget {
  const _YouthCircleCard({required this.circle});
  final YouthCircle circle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.14),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colors.primaryContainer,
                colors.secondaryContainer,
              ],
            ),
            border: Border.all(
              color: colors.primary.withValues(alpha: 0.18),
            ),
          ),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => _CircleDiscussionScreen(circle: circle),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: SizedBox(
                  width: 140,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.groups_2_rounded,
                        size: 28,
                        color: colors.primary,
                      ),
                      const SizedBox(height: 7),
                      Text(
                        circle.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  height: 1.15,
                                ),
                      ),
                      if (circle.description.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          circle.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: colors.onSecondaryContainer,
                                    height: 1.2,
                                  ),
                        ),
                      ],
                      const SizedBox(height: 7),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 19,
                        color: colors.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CircleDiscussionScreen extends ConsumerStatefulWidget {
  const _CircleDiscussionScreen({required this.circle});
  final YouthCircle circle;

  @override
  ConsumerState<_CircleDiscussionScreen> createState() =>
      _CircleDiscussionScreenState();
}

class _CircleDiscussionScreenState
    extends ConsumerState<_CircleDiscussionScreen> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final responses = ref.watch(circleResponsesProvider(widget.circle.id));
    final currentUser = ref.watch(appUserProvider).asData?.value;
    final isAdmin = ref.watch(isAdminProvider);
    return Scaffold(
      appBar: AppBar(title: Text(widget.circle.title)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.circle.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 6),
              Text(widget.circle.description),
              const SizedBox(height: 14),
              Expanded(
                child: responses.when(
                  loading: () => const Center(child: AppLoadingIndicator()),
                  error: (_, __) => Center(
                    child: Text(context.t('faith.responses_failed')),
                  ),
                  data: (items) => items.isEmpty
                      ? Center(child: Text(context.t('faith.no_responses')))
                      : ListView.separated(
                          reverse: true,
                          itemCount: items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final item = items[items.length - index - 1];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: AppProfileAvatar(
                                name: item.userName,
                                imageUrl: item.userPhotoUrl,
                              ),
                              title: Text(item.userName),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.message),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatCircleResponseTime(
                                      context,
                                      item.createdAt,
                                    ),
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                              trailing: isAdmin ||
                                      item.userId == currentUser?.uid
                                  ? IconButton(
                                      tooltip: context.t('common.delete'),
                                      onPressed: () => ref
                                          .read(
                                              faithEngagementRepositoryProvider)
                                          ?.deleteResponse(
                                            widget.circle.id,
                                            item.id,
                                          ),
                                      icon: const Icon(Icons.delete_outline),
                                    )
                                  : null,
                            );
                          },
                        ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _controller,
                      label: context.t('faith.response_label'),
                      maxLines: 2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending || currentUser == null ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _send() async {
    final user = ref.read(appUserProvider).asData?.value;
    final repository = ref.read(faithEngagementRepositoryProvider);
    if (user == null || repository == null || _controller.text.trim().isEmpty) {
      return;
    }
    setState(() => _sending = true);
    try {
      await repository.addResponse(
        circleId: widget.circle.id,
        user: user,
        message: _controller.text,
        notificationBody: context.t(
          'faith.circle_response_notification_body',
          parameters: {'name': user.name},
        ),
      );
      _controller.clear();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t('faith.response_failed'))),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}

class _DailyFaithLoop extends ConsumerStatefulWidget {
  const _DailyFaithLoop({required this.reflection});
  final FaithReflection reflection;

  @override
  ConsumerState<_DailyFaithLoop> createState() => _DailyFaithLoopState();
}

class _DailyFaithLoopState extends ConsumerState<_DailyFaithLoop> {
  int _step = 0;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final titles = [
      context.t('faith.reflect_step'),
      context.t('faith.pray_step'),
      context.t('faith.challenge_step'),
    ];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t('faith.loop_title'),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: (_step + 1) / 3),
            const SizedBox(height: 18),
            Text(
              titles[_step],
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                child: _step == 0
                    ? _ReflectionStep(reflection: widget.reflection)
                    : _step == 1
                        ? _PrayerPointsStep(
                            prayerPoints: widget.reflection.prayerPoints,
                          )
                        : _LiveItOutStep(action: widget.reflection.liveItOut),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _completeStep,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        _step == 2
                            ? context.t('faith.finish_loop')
                            : context.t('faith.complete_and_continue'),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _completeStep() async {
    final repository = ref.read(faithEngagementRepositoryProvider);
    final uid = ref.read(firebaseAuthProvider).currentUser?.uid;
    if (repository == null || uid == null) return;
    setState(() => _saving = true);
    try {
      await repository.completeDailyStep(
        userId: uid,
        day: DateTime.now(),
        step: const ['reflect', 'pray', 'challenge'][_step],
      );
      if (!mounted) return;
      if (_step == 2) {
        Navigator.of(context).pop();
      } else {
        setState(() => _step += 1);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t('faith.update_failed'))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _ReflectionStep extends ConsumerWidget {
  const _ReflectionStep({required this.reflection});
  final FaithReflection reflection;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: carouselBoxDecoration(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(reflection.title,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            Text(reflection.body),
            if (reflection.hasScripture) ...[
              const SizedBox(height: 14),
              _ScripturePassage(
                reflection: reflection,
                language: ref.watch(dailyVerseLanguageProvider),
              ),
            ],
          ],
        ),
      );
}

class _ScripturePassage extends StatelessWidget {
  const _ScripturePassage({
    required this.reflection,
    required this.language,
  });

  final FaithReflection reflection;
  final BibleLanguage language;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, String>>(
      future: BibleRepository().getVerseRange(
        book: reflection.scriptureBook,
        chapter: reflection.scriptureChapter,
        startVerse: reflection.scriptureStartVerse,
        endVerse: reflection.scriptureEndVerse,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: AppLoadingIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Text(
            context.t('faith.passage_load_failed'),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          );
        }
        final passage = snapshot.data!;
        final preferredText = language == BibleLanguage.tamil
            ? passage['tamil'] ?? ''
            : passage['english'] ?? '';
        final fallbackText = language == BibleLanguage.tamil
            ? passage['english'] ?? ''
            : passage['tamil'] ?? '';
        final text = preferredText.isNotEmpty ? preferredText : fallbackText;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      reflection.scriptureReference,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  BibleLanguageToggle(provider: dailyVerseLanguageProvider),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                text,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      height: 1.5,
                    ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PrayerPointsStep extends StatelessWidget {
  const _PrayerPointsStep({required this.prayerPoints});
  final List<String> prayerPoints;

  @override
  Widget build(BuildContext context) {
    final points = prayerPoints.isEmpty
        ? [context.t('faith.general_prayer_body')]
        : prayerPoints;
    return Column(
      children: [
        for (var index = 0; index < points.length; index++) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: carouselBoxDecoration(context),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 16,
                  child: Text('${index + 1}'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    points[index],
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          height: 1.45,
                        ),
                  ),
                ),
              ],
            ),
          ),
          if (index != points.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _LiveItOutStep extends StatelessWidget {
  const _LiveItOutStep({required this.action});
  final String action;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: carouselBoxDecoration(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.flag_rounded,
                color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              context.t('faith.live_it_out_today'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              action.trim().isEmpty
                  ? context.t('faith.general_challenge_body')
                  : action,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    height: 1.45,
                  ),
            ),
          ],
        ),
      );
}

String _formatCircleResponseTime(BuildContext context, DateTime? value) {
  if (value == null) return context.t('time.just_now');
  final timestamp = value.toLocal();
  return context.t(
    'time.date_at',
    parameters: {
      'date': DateFormat.yMMMd().format(timestamp),
      'time': DateFormat.jm().format(timestamp),
    },
  );
}
