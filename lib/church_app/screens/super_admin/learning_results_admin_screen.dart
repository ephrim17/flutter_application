import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';
import 'package:flutter_application/church_app/models/church_model.dart';
import 'package:flutter_application/church_app/models/learning_module_models.dart';
import 'package:flutter_application/church_app/services/learning_module_repository.dart';
import 'package:flutter_application/church_app/widgets/app_loading_indicator.dart';
import 'package:intl/intl.dart';

class LearningResultsAdminScreen extends StatelessWidget {
  const LearningResultsAdminScreen({
    super.key,
    required this.church,
    required this.repository,
  });

  final Church church;
  final LearningModuleRepository repository;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(context.t('learning.results_title'))),
        body: StreamBuilder<List<LearningModule>>(
          stream: repository.watchAllModules(),
          builder: (context, modulesSnapshot) {
            if (!modulesSnapshot.hasData) {
              return const Center(child: AppLoadingIndicator());
            }
            return StreamBuilder<List<LearningModule>>(
              stream: repository.watchChurchModules(church.id),
              builder: (context, churchModulesSnapshot) {
                if (!churchModulesSnapshot.hasData) {
                  return const Center(child: AppLoadingIndicator());
                }
                final modulesById = <String, LearningModule>{
                  for (final module in modulesSnapshot.data!) module.id: module,
                  for (final module in churchModulesSnapshot.data!)
                    module.id: module,
                };
                return StreamBuilder<List<LearningQuizResult>>(
                  stream: repository.watchChurchResults(church.id),
                  builder: (context, resultsSnapshot) {
                    if (!resultsSnapshot.hasData) {
                      return const Center(child: AppLoadingIndicator());
                    }
                    return _ResultsBody(
                      church: church,
                      modules: modulesById.values.toList(growable: false),
                      results: resultsSnapshot.data!,
                    );
                  },
                );
              },
            );
          },
        ),
      );
}

class _ResultsBody extends StatelessWidget {
  const _ResultsBody({
    required this.church,
    required this.modules,
    required this.results,
  });

  final Church church;
  final List<LearningModule> modules;
  final List<LearningQuizResult> results;

  @override
  Widget build(BuildContext context) {
    final participants = results.map((result) => result.userId).toSet().length;
    final passed = results.where((result) => result.passed).length;
    final passRate =
        results.isEmpty ? 0 : (passed / results.length * 100).round();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Text(
          church.name,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 6),
        Text(context.t('learning.results_subtitle')),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _ResultMetric(
                label: context.t('learning.results_attempts'),
                value: '${results.length}',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ResultMetric(
                label: context.t('learning.results_learners'),
                value: '$participants',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ResultMetric(
                label: context.t('learning.results_pass_rate'),
                value: '$passRate%',
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Text(
          context.t('learning.results_latest'),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 10),
        if (results.isEmpty)
          Container(
            decoration: carouselBoxDecoration(context),
            padding: const EdgeInsets.all(22),
            child: Column(
              children: [
                const Icon(Icons.insights_outlined, size: 48),
                const SizedBox(height: 12),
                Text(
                  context.t('learning.results_empty'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  context.t('learning.results_empty_hint'),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          for (final result in results) ...[
            _ResultTile(
              result: result,
              module: modules
                  .where((module) => module.id == result.moduleId)
                  .firstOrNull,
            ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _ResultMetric extends StatelessWidget {
  const _ResultMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        decoration: carouselBoxDecoration(context),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
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

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.result, required this.module});

  final LearningQuizResult result;
  final LearningModule? module;

  @override
  Widget build(BuildContext context) {
    final section = module?.sections
        .where((section) => section.id == result.sectionId)
        .firstOrNull;
    final learner = result.userName.isNotEmpty
        ? result.userName
        : result.userEmail.isNotEmpty
            ? result.userEmail
            : context.t('learning.results_unknown_learner');
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: carouselBoxDecoration(context),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                child: Icon(
                  result.passed ? Icons.check_rounded : Icons.refresh_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      learner,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    if (result.userEmail.isNotEmpty &&
                        result.userEmail != learner)
                      Text(
                        result.userEmail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: result.passed
                      ? colors.primaryContainer
                      : colors.errorContainer,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  context.t(
                    result.passed
                        ? 'learning.results_passed'
                        : 'learning.results_retry',
                  ),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            module?.title ?? context.t('learning.results_unknown_module'),
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 3),
          Text(
            result.sectionId.isEmpty
                ? context.t('learning.final_exam')
                : section?.title ??
                    context.t('learning.results_unknown_section'),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ResultDetail(
                icon: Icons.score_outlined,
                label: context.t(
                  'learning.results_score',
                  parameters: {
                    'score': result.score,
                    'total': result.total,
                  },
                ),
              ),
              _ResultDetail(
                icon: Icons.replay_rounded,
                label: context.t(
                  'learning.results_attempt_number',
                  parameters: {'count': result.attemptNumber},
                ),
              ),
              if (result.submittedAt != null)
                _ResultDetail(
                  icon: Icons.schedule_outlined,
                  label: DateFormat.yMMMd()
                      .add_jm()
                      .format(result.submittedAt!.toLocal()),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResultDetail extends StatelessWidget {
  const _ResultDetail({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15),
            const SizedBox(width: 5),
            Text(label, style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
      );
}
