part of '../dashboard_screen.dart';

class _DashboardQuizResultsSection extends StatelessWidget {
  const _DashboardQuizResultsSection({
    required this.resultsAsync,
    required this.members,
  });

  final AsyncValue<List<QuizDashboardResult>> resultsAsync;
  final List<AppUser> members;

  @override
  Widget build(BuildContext context) => resultsAsync.when(
        loading: () => const Center(child: AppLoadingIndicator()),
        error: (_, __) => _DashboardEmptyState(
          title: context.t('dashboard.quiz_results_failed'),
          subtitle: context.t('dashboard.quiz_results_failed_hint'),
        ),
        data: (results) {
          if (results.isEmpty) {
            return _DashboardEmptyState(
              title: context.t('dashboard.quiz_results_empty'),
              subtitle: context.t('dashboard.quiz_results_empty_hint'),
            );
          }
          final submissions = results.fold<int>(
            0,
            (sum, result) => sum + result.participantCount,
          );
          final participantIds = results
              .expand((result) => result.participants)
              .map((result) => result.userId)
              .toSet();
          final scoredResults = results
              .expand((result) => result.participants)
              .toList(growable: false);
          final average = scoredResults.isEmpty
              ? 0.0
              : scoredResults.fold<double>(
                    0,
                    (sum, result) =>
                        sum + result.attempt.score / result.attempt.total * 100,
                  ) /
                  scoredResults.length;
          final now = DateTime.now();
          final todayResults = scoredResults
              .where(
                (result) =>
                    result.submittedAt != null &&
                    _isSameDashboardDay(result.submittedAt!, now),
              )
              .toList(growable: false);
          final todayParticipants =
              todayResults.map((result) => result.userId).toSet().length;
          final todayAverage = todayResults.isEmpty
              ? 0.0
              : todayResults.fold<double>(
                    0,
                    (accumulated, result) =>
                        accumulated +
                        result.attempt.score / result.attempt.total * 100,
                  ) /
                  todayResults.length;
          final dailyActivity = List.generate(7, (index) {
            final day = DateTime(now.year, now.month, now.day)
                .subtract(Duration(days: 6 - index));
            final submissions = scoredResults
                .where(
                  (result) =>
                      result.submittedAt != null &&
                      _isSameDashboardDay(result.submittedAt!, day),
                )
                .length;
            return _QuizDailyActivity(day: day, submissions: submissions);
          });
          return Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _DashboardQuizMetric(
                      label: context.t('dashboard.quiz_participants'),
                      value: '${participantIds.length}',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _DashboardQuizMetric(
                      label: context.t('dashboard.quiz_submissions'),
                      value: '$submissions',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _DashboardQuizMetric(
                      label: context.t('dashboard.quiz_average'),
                      value: '${average.round()}%',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.t('dashboard.quiz_daily_updates'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.t(
                        'dashboard.quiz_today_summary',
                        parameters: {
                          'participants': todayParticipants,
                          'submissions': todayResults.length,
                          'average': todayAverage.round(),
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 72,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: dailyActivity.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final activity = dailyActivity[index];
                          final isToday =
                              _isSameDashboardDay(activity.day, now);
                          return Container(
                            width: 62,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: isToday
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  isToday
                                      ? context.t('dashboard.today_short')
                                      : DateFormat.E().format(activity.day),
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: isToday
                                            ? Theme.of(context)
                                                .colorScheme
                                                .onPrimary
                                            : null,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${activity.submissions}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        color: isToday
                                            ? Theme.of(context)
                                                .colorScheme
                                                .onPrimary
                                            : null,
                                        fontWeight: FontWeight.w900,
                                      ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.t('dashboard.quiz_daily_submissions_hint'),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              for (var index = 0; index < results.length; index++) ...[
                _DashboardQuizTile(
                  result: results[index],
                  members: members,
                ),
                if (index != results.length - 1) const SizedBox(height: 10),
              ],
            ],
          );
        },
      );
}

class _QuizDailyActivity {
  const _QuizDailyActivity({required this.day, required this.submissions});

  final DateTime day;
  final int submissions;
}

bool _isSameDashboardDay(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;

class _DashboardQuizMetric extends StatelessWidget {
  const _DashboardQuizMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      );
}

class _DashboardQuizTile extends StatelessWidget {
  const _DashboardQuizTile({required this.result, required this.members});

  final QuizDashboardResult result;
  final List<AppUser> members;

  @override
  Widget build(BuildContext context) => Material(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => _DashboardQuizResultDetailsScreen(
                result: result,
                members: members,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  child: const Icon(Icons.quiz_outlined),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.challenge.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.t(
                          'dashboard.quiz_summary',
                          parameters: {
                            'participants': result.participantCount,
                            'average': result.averagePercentage.round(),
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      );
}

class _DashboardQuizResultDetailsScreen extends StatelessWidget {
  const _DashboardQuizResultDetailsScreen({
    required this.result,
    required this.members,
  });

  final QuizDashboardResult result;
  final List<AppUser> members;

  @override
  Widget build(BuildContext context) {
    final membersById = {for (final member in members) member.uid: member};
    return Scaffold(
      appBar: AppBar(title: Text(context.t('dashboard.quiz_details_title'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Text(
            result.challenge.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          if (result.challenge.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(result.challenge.description),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _DashboardQuizMetric(
                  label: context.t('dashboard.quiz_participants'),
                  value: '${result.participantCount}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DashboardQuizMetric(
                  label: context.t('dashboard.quiz_average'),
                  value: '${result.averagePercentage.round()}%',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DashboardQuizMetric(
                  label: context.t('dashboard.quiz_highest'),
                  value:
                      '${result.highestScore}/${result.challenge.questions.length}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            context.t('dashboard.quiz_member_results'),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 10),
          if (result.participants.isEmpty)
            _DashboardEmptyState(
              title: context.t('dashboard.quiz_no_submissions'),
              subtitle: context.t('dashboard.quiz_no_submissions_hint'),
            )
          else
            for (final participant in result.participants) ...[
              _DashboardQuizParticipantTile(
                participant: participant,
                challenge: result.challenge,
                member: membersById[participant.userId],
              ),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _DashboardQuizParticipantTile extends StatelessWidget {
  const _DashboardQuizParticipantTile({
    required this.participant,
    required this.challenge,
    required this.member,
  });

  final QuizParticipantResult participant;
  final QuizChallenge challenge;
  final AppUser? member;

  @override
  Widget build(BuildContext context) {
    final name = member?.name.trim().isNotEmpty == true
        ? member!.name
        : context.t('dashboard.unknown_member');
    final percentage =
        (participant.attempt.score / participant.attempt.total * 100).round();
    return Container(
      decoration: carouselBoxDecoration(context),
      child: ExpansionTile(
        leading: AppProfileAvatar(
          name: name,
          imageUrl: member?.profilePhotoUrl,
          radius: 20,
        ),
        title: Text(name),
        subtitle: Text(
          participant.submittedAt == null
              ? context.t('dashboard.submission_time_unknown')
              : DateFormat.yMMMd().add_jm().format(participant.submittedAt!),
        ),
        trailing: Text(
          '${participant.attempt.score}/${participant.attempt.total} • $percentage%',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        children: [
          for (var index = 0; index < challenge.questions.length; index++)
            _DashboardQuizAnswerTile(
              questionNumber: index + 1,
              question: challenge.questions[index],
              selectedOption: index < participant.attempt.answers.length
                  ? participant.attempt.answers[index]
                  : -1,
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _DashboardQuizAnswerTile extends StatelessWidget {
  const _DashboardQuizAnswerTile({
    required this.questionNumber,
    required this.question,
    required this.selectedOption,
  });

  final int questionNumber;
  final QuizQuestion question;
  final int selectedOption;

  @override
  Widget build(BuildContext context) {
    final selectedValid =
        selectedOption >= 0 && selectedOption < question.options.length;
    final isCorrect = selectedOption == question.correctOptionIndex;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18),
      leading: Icon(
        isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
        color: isCorrect ? Colors.green : Theme.of(context).colorScheme.error,
      ),
      title: Text(
        context.t(
          'dashboard.quiz_question_with_prompt',
          parameters: {
            'number': questionNumber,
            'question': question.prompt,
          },
        ),
      ),
      subtitle: Text(
        context.t(
          isCorrect
              ? 'dashboard.quiz_selected_answer'
              : 'dashboard.quiz_answer_correction',
          parameters: {
            'selected': selectedValid
                ? question.options[selectedOption]
                : context.t('dashboard.quiz_no_answer'),
            'correct': question.options[question.correctOptionIndex],
          },
        ),
      ),
    );
  }
}
