import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';
import 'package:flutter_application/church_app/models/faith_engagement_models.dart';
import 'package:flutter_application/church_app/providers/authentication/admin_provider.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
import 'package:flutter_application/church_app/providers/faith_engagement_providers.dart';
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
  const FaithEngagementSection({this.anchorKey});

  final GlobalKey? anchorKey;

  @override
  String get id => 'faithEngagement';

  @override
  int get order => 12;

  @override
  List<Widget> buildSlivers(BuildContext context) => [
        SliverToBoxAdapter(
          child: KeyedSubtree(
            key: anchorKey,
            child: const _FaithEngagementContent(),
          ),
        ),
      ];
}

class _FaithEngagementContent extends ConsumerWidget {
  const _FaithEngagementContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reflection = ref.watch(todayReflectionProvider).asData?.value;
    final circles = ref.watch(youthCirclesProvider).asData?.value ?? const [];
    final quizzes = ref.watch(quizChallengesProvider).asData?.value ?? const [];
    final activeQuiz =
        quizzes.where((item) => item.isActiveAt(DateTime.now())).firstOrNull;

    if (reflection == null && circles.isEmpty && activeQuiz == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (reflection != null) ...[
            SectionHeader(
              text: context.t('faith.today_heading'),
              padding: 16,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
              child: _TodayFaithCard(reflection: reflection),
            ),
          ],
          if (activeQuiz != null) ...[
            SectionHeader(
              text: context.t('faith.quiz_challenge_heading'),
              padding: 16,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
              child: _QuizChallengeCard(challenge: activeQuiz),
            ),
          ],
          if (circles.isNotEmpty) ...[
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

class _QuizChallengeCard extends ConsumerWidget {
  const _QuizChallengeCard({required this.challenge});
  final QuizChallenge challenge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attempt = ref.watch(quizAttemptProvider(challenge.id)).asData?.value;
    return SizedBox(
      height: forYouPrimaryCardHeight,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: carouselBoxDecoration(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.quiz_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    challenge.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                if (attempt != null)
                  Chip(
                    label: Text('${attempt.score}/${attempt.total}'),
                    avatar: const Icon(Icons.check_circle_rounded, size: 18),
                  ),
              ],
            ),
            if (challenge.description.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                challenge.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const Spacer(),
            Text(
              context.t(
                'faith.quiz_question_count',
                parameters: {'count': challenge.questions.length},
              ),
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: () => showAppModalBottomSheet<void>(
                  context: context,
                  heightFactor: 0.92,
                  builder: (_) => _QuizChallengeSheet(
                    challenge: challenge,
                    attempt: attempt,
                  ),
                ),
                icon: Icon(
                  attempt == null ? Icons.play_arrow_rounded : Icons.insights,
                ),
                label: Text(
                  context.t(
                    attempt == null ? 'faith.start_quiz' : 'faith.view_result',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuizChallengeSheet extends ConsumerStatefulWidget {
  const _QuizChallengeSheet({required this.challenge, required this.attempt});

  final QuizChallenge challenge;
  final QuizAttempt? attempt;

  @override
  ConsumerState<_QuizChallengeSheet> createState() =>
      _QuizChallengeSheetState();
}

class _QuizChallengeSheetState extends ConsumerState<_QuizChallengeSheet> {
  late final List<int?> _answers;
  bool _submitting = false;

  bool get _submitted => widget.attempt != null;

  @override
  void initState() {
    super.initState();
    _answers = List<int?>.generate(
      widget.challenge.questions.length,
      (index) => index < (widget.attempt?.answers.length ?? 0)
          ? widget.attempt!.answers[index]
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.challenge.title,
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                      ),
                      if (_submitted)
                        Text(
                          context.t(
                            'faith.quiz_score',
                            parameters: {
                              'score': widget.attempt!.score,
                              'total': widget.attempt!.total,
                            },
                          ),
                        ),
                    ],
                  ),
                ),
                const Icon(Icons.quiz_rounded),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
              itemCount: widget.challenge.questions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, questionIndex) {
                final question = widget.challenge.questions[questionIndex];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: carouselBoxDecoration(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.t(
                          'faith.quiz_question_number',
                          parameters: {'number': questionIndex + 1},
                        ),
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        question.prompt,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                      const SizedBox(height: 10),
                      RadioGroup<int>(
                        groupValue: _answers[questionIndex],
                        onChanged: (value) {
                          if (_submitted) return;
                          setState(() => _answers[questionIndex] = value);
                        },
                        child: Column(
                          children: [
                            for (var optionIndex = 0;
                                optionIndex < question.options.length;
                                optionIndex++)
                              RadioListTile<int>(
                                contentPadding: EdgeInsets.zero,
                                value: optionIndex,
                                enabled: !_submitted,
                                title: Text(question.options[optionIndex]),
                                secondary: _submitted
                                    ? Icon(
                                        optionIndex ==
                                                question.correctOptionIndex
                                            ? Icons.check_circle_rounded
                                            : _answers[questionIndex] ==
                                                    optionIndex
                                                ? Icons.cancel_rounded
                                                : Icons.circle_outlined,
                                        color: optionIndex ==
                                                question.correctOptionIndex
                                            ? Colors.green
                                            : _answers[questionIndex] ==
                                                    optionIndex
                                                ? Theme.of(context)
                                                    .colorScheme
                                                    .error
                                                : null,
                                      )
                                    : null,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          if (!_submitted)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(context.t('faith.submit_quiz')),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_answers.any((answer) => answer == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('faith.answer_all_questions'))),
      );
      return;
    }
    final repository = ref.read(faithEngagementRepositoryProvider);
    final uid = ref.read(firebaseAuthProvider).currentUser?.uid;
    if (repository == null || uid == null) return;
    setState(() => _submitting = true);
    final answers = _answers.cast<int>();
    final score = List.generate(
      answers.length,
      (index) =>
          answers[index] == widget.challenge.questions[index].correctOptionIndex
              ? 1
              : 0,
    ).fold<int>(0, (sum, item) => sum + item);
    try {
      await repository.submitQuizAttempt(
        challengeId: widget.challenge.id,
        userId: uid,
        answers: answers,
        score: score,
        total: widget.challenge.questions.length,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t('faith.quiz_submit_failed'))),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
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
  final now = DateTime.now();
  final difference = now.difference(timestamp);
  if (difference.isNegative || difference.inMinutes < 1) {
    return context.t('time.just_now');
  }
  if (difference.inMinutes < 60) {
    final minutes = difference.inMinutes;
    return context.t(
      minutes == 1 ? 'time.minute_ago' : 'time.minutes_ago',
      parameters: {'count': minutes},
    );
  }
  if (difference.inHours < 24) {
    final hours = difference.inHours;
    return context.t(
      hours == 1 ? 'time.hour_ago' : 'time.hours_ago',
      parameters: {'count': hours},
    );
  }
  final today = DateTime(now.year, now.month, now.day);
  final messageDay = DateTime(timestamp.year, timestamp.month, timestamp.day);
  final daysAgo = today.difference(messageDay).inDays;
  final time = DateFormat.jm().format(timestamp);
  if (daysAgo == 1) {
    return context.t(
      'time.yesterday_at',
      parameters: {'time': time},
    );
  }
  if (daysAgo < 7) {
    return context.t(
      'time.weekday_at',
      parameters: {
        'day': DateFormat.EEEE().format(timestamp),
        'time': time,
      },
    );
  }
  return context.t(
    'time.date_at',
    parameters: {
      'date': DateFormat.yMMMd().format(timestamp),
      'time': time,
    },
  );
}
