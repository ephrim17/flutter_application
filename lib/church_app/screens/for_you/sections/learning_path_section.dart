import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';
import 'package:flutter_application/church_app/helpers/contact_launcher.dart';
import 'package:flutter_application/church_app/helpers/feed_link_utils.dart';
import 'package:flutter_application/church_app/models/learning_module_models.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
import 'package:flutter_application/church_app/providers/church_provider.dart';
import 'package:flutter_application/church_app/providers/language_provider.dart';
import 'package:flutter_application/church_app/providers/learning_module_providers.dart';
import 'package:flutter_application/church_app/providers/user_provider.dart';
import 'package:flutter_application/church_app/screens/home/home_screen.dart';
import 'package:flutter_application/church_app/services/side_drawer/bible_book_repository.dart';
import 'package:flutter_application/church_app/widgets/app_loading_indicator.dart';
import 'package:flutter_application/church_app/widgets/app_image_gallery_viewer.dart';
import 'package:flutter_application/church_app/widgets/adaptive_youtube_player.dart';
import 'package:flutter_application/church_app/widgets/language_toggle_widget.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

class LearningPathSection implements MasterSection {
  const LearningPathSection();

  @override
  String get id => 'learningPath';

  @override
  int get order => 13;

  @override
  List<Widget> buildSlivers(BuildContext context) => const [
        SliverToBoxAdapter(child: _LearningPathContent()),
      ];
}

class _LearningPathContent extends ConsumerWidget {
  const _LearningPathContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modules = ref.watch(publishedLearningModulesProvider).asData?.value;
    if (modules == null || modules.isEmpty) return const SizedBox.shrink();
    final progress = ref.watch(learningProgressProvider).asData?.value ??
        const LearningProgress(completedSectionIds: {}, attempts: {});
    final completedModules = modules.where(progress.isModuleComplete).length;
    final completedSections = modules
        .expand((module) => module.sections)
        .where((section) => progress.isSectionComplete(section.id))
        .length;
    final totalSections = modules.expand((module) => module.sections).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
      child: Container(
        decoration: carouselBoxDecoration(context),
        child: InkWell(
          borderRadius: BorderRadius.circular(cornerRadius),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const LearningPathScreen(),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(
                        Icons.school_outlined,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.t('learning.member_heading'),
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 3),
                          Text(context.t('learning.overview_hint')),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_rounded),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _LearningMetric(
                        value: '$completedModules',
                        label: context.t('learning.completed_modules'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _LearningMetric(
                        value: '${modules.length - completedModules}',
                        label: context.t('learning.modules_remaining'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                LinearProgressIndicator(
                  value:
                      modules.isEmpty ? 0 : completedModules / modules.length,
                  minHeight: 7,
                  borderRadius: BorderRadius.circular(99),
                ),
                const SizedBox(height: 8),
                Text(
                  context.t(
                    'learning.module_overview_progress',
                    parameters: {
                      'completed': completedModules,
                      'total': modules.length,
                      'sections': completedSections,
                      'sectionTotal': totalSections,
                    },
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

class _LearningMetric extends StatelessWidget {
  const _LearningMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 2),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      );
}

enum _LearningSegment { learning, completed }

class LearningPathScreen extends ConsumerStatefulWidget {
  const LearningPathScreen({super.key});

  @override
  ConsumerState<LearningPathScreen> createState() => _LearningPathScreenState();
}

class _LearningPathScreenState extends ConsumerState<LearningPathScreen> {
  _LearningSegment _segment = _LearningSegment.learning;

  @override
  Widget build(BuildContext context) {
    final modulesAsync = ref.watch(publishedLearningModulesProvider);
    final progress = ref.watch(learningProgressProvider).asData?.value ??
        const LearningProgress(completedSectionIds: {}, attempts: {});
    return Scaffold(
      appBar: AppBar(title: Text(context.t('learning.member_heading'))),
      body: modulesAsync.when(
        loading: () => const Center(child: AppLoadingIndicator()),
        error: (_, __) => Center(
          child: Text(context.t('learning.load_failed')),
        ),
        data: (modules) => _buildCatalogue(context, modules, progress),
      ),
    );
  }

  Widget _buildCatalogue(
    BuildContext context,
    List<LearningModule> modules,
    LearningProgress progress,
  ) {
    final completedCount = modules.where(progress.isModuleComplete).length;
    final indexedModules = modules.indexed.where((entry) {
      final completed = progress.isModuleComplete(entry.$2);
      return _segment == _LearningSegment.completed ? completed : !completed;
    }).toList(growable: false);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        Container(
          decoration: carouselBoxDecoration(context),
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              const Icon(Icons.auto_stories_outlined, size: 32),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.t(
                        'learning.modules_completed_overview',
                        parameters: {
                          'completed': completedCount,
                          'total': modules.length,
                        },
                      ),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value:
                          modules.isEmpty ? 0 : completedCount / modules.length,
                      minHeight: 7,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _LearningSegmentSelector(
          selected: _segment,
          learningCount: modules.length - completedCount,
          completedCount: completedCount,
          onChanged: (value) => setState(() => _segment = value),
        ),
        const SizedBox(height: 18),
        if (indexedModules.isEmpty)
          _LearningEmptyState(segment: _segment)
        else
          for (final entry in indexedModules) ...[
            _LearningModuleTile(
              module: entry.$2,
              number: entry.$1 + 1,
              completed: progress.isModuleComplete(entry.$2),
              unlocked: entry.$1 == 0 ||
                  progress.isModuleComplete(modules[entry.$1 - 1]),
              completedSections: entry.$2.sections
                  .where((section) => progress.isSectionComplete(section.id))
                  .length,
            ),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

class _LearningSegmentSelector extends StatelessWidget {
  const _LearningSegmentSelector({
    required this.selected,
    required this.learningCount,
    required this.completedCount,
    required this.onChanged,
  });

  final _LearningSegment selected;
  final int learningCount;
  final int completedCount;
  final ValueChanged<_LearningSegment> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Expanded(
              child: _LearningSegmentButton(
                label: context.t('learning.segment_learning'),
                count: learningCount,
                selected: selected == _LearningSegment.learning,
                onTap: () => onChanged(_LearningSegment.learning),
              ),
            ),
            Expanded(
              child: _LearningSegmentButton(
                label: context.t('learning.segment_completed'),
                count: completedCount,
                selected: selected == _LearningSegment.completed,
                onTap: () => onChanged(_LearningSegment.completed),
              ),
            ),
          ],
        ),
      );
}

class _LearningSegmentButton extends StatelessWidget {
  const _LearningSegmentButton({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: selected ? colors.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 7),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: selected
                      ? colors.primaryContainer
                      : colors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text('$count'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LearningModuleTile extends StatelessWidget {
  const _LearningModuleTile({
    required this.module,
    required this.number,
    required this.completed,
    required this.unlocked,
    required this.completedSections,
  });

  final LearningModule module;
  final int number;
  final bool completed;
  final bool unlocked;
  final int completedSections;

  @override
  Widget build(BuildContext context) => Container(
        decoration: carouselBoxDecoration(context),
        child: ListTile(
          enabled: unlocked,
          contentPadding: const EdgeInsets.all(16),
          leading: CircleAvatar(
            child: completed
                ? const Icon(Icons.check_rounded)
                : unlocked
                    ? Text('$number')
                    : const Icon(Icons.lock_outline_rounded),
          ),
          title: Text(
            module.title,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              context.t(
                'learning.module_progress',
                parameters: {
                  'completed': completedSections,
                  'total': module.sections.length,
                },
              ),
            ),
          ),
          trailing: unlocked ? const Icon(Icons.chevron_right_rounded) : null,
          onTap: unlocked
              ? () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => _LearningModuleScreen(module: module),
                    ),
                  )
              : null,
        ),
      );
}

class _LearningEmptyState extends StatelessWidget {
  const _LearningEmptyState({required this.segment});

  final _LearningSegment segment;

  @override
  Widget build(BuildContext context) => Container(
        decoration: carouselBoxDecoration(context),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 42),
        child: Column(
          children: [
            Icon(
              segment == _LearningSegment.completed
                  ? Icons.school_outlined
                  : Icons.check_circle_outline_rounded,
              size: 42,
            ),
            const SizedBox(height: 12),
            Text(
              context.t(
                segment == _LearningSegment.completed
                    ? 'learning.no_completed_modules'
                    : 'learning.all_modules_completed',
              ),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
      );
}

class _LearningModuleScreen extends ConsumerWidget {
  const _LearningModuleScreen({required this.module});
  final LearningModule module;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(learningProgressProvider).asData?.value ??
        const LearningProgress(completedSectionIds: {}, attempts: {});
    final moduleCompleted = progress.isModuleComplete(module);
    return Scaffold(
      appBar: AppBar(title: Text(module.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text(
            module.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 8),
          Text(module.description),
          const SizedBox(height: 22),
          for (var index = 0; index < module.sections.length; index++) ...[
            Builder(builder: (context) {
              final section = module.sections[index];
              final unlocked = moduleCompleted ||
                  index == 0 ||
                  progress.isSectionComplete(module.sections[index - 1].id);
              final completed = progress.isSectionComplete(section.id);
              return Container(
                decoration: carouselBoxDecoration(context),
                child: ListTile(
                  enabled: unlocked,
                  contentPadding: const EdgeInsets.all(14),
                  leading: CircleAvatar(
                    child: completed
                        ? const Icon(Icons.check_rounded)
                        : unlocked
                            ? Text('${index + 1}')
                            : const Icon(Icons.lock_outline_rounded),
                  ),
                  title: Text(
                    section.title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(section.scriptureReference),
                  trailing:
                      unlocked ? const Icon(Icons.chevron_right_rounded) : null,
                  onTap: unlocked
                      ? () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => _LearningSectionScreen(
                                module: module,
                                section: section,
                                alreadyComplete: completed,
                              ),
                            ),
                          )
                      : null,
                ),
              );
            }),
            const SizedBox(height: 12),
          ],
          Builder(builder: (context) {
            final allSectionsComplete = module.sections.every(
              (section) => progress.isSectionComplete(section.id),
            );
            final canTakeExam = allSectionsComplete && !moduleCompleted;
            return Container(
              decoration: carouselBoxDecoration(context),
              child: ListTile(
                enabled: canTakeExam,
                contentPadding: const EdgeInsets.all(14),
                leading: CircleAvatar(
                  child: moduleCompleted
                      ? const Icon(Icons.workspace_premium_outlined)
                      : allSectionsComplete
                          ? const Icon(Icons.quiz_outlined)
                          : const Icon(Icons.lock_outline_rounded),
                ),
                title: Text(
                  context.t('learning.final_exam'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  context.t(
                    moduleCompleted
                        ? 'learning.final_exam_completed'
                        : allSectionsComplete
                            ? 'learning.final_exam_ready'
                            : 'learning.final_exam_locked',
                  ),
                ),
                trailing: canTakeExam
                    ? const Icon(Icons.chevron_right_rounded)
                    : null,
                onTap: canTakeExam
                    ? () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => _LearningQuizScreen(
                              module: module,
                            ),
                          ),
                        )
                    : null,
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _LearningSectionScreen extends ConsumerStatefulWidget {
  const _LearningSectionScreen({
    required this.module,
    required this.section,
    required this.alreadyComplete,
  });

  final LearningModule module;
  final LearningSection section;
  final bool alreadyComplete;

  @override
  ConsumerState<_LearningSectionScreen> createState() =>
      _LearningSectionScreenState();
}

class _LearningSectionScreenState
    extends ConsumerState<_LearningSectionScreen> {
  late final List<LearningPassage> _passages;
  late final List<Future<Map<String, String>>> _passageText;
  bool _completing = false;

  @override
  void initState() {
    super.initState();
    _passages = [...widget.section.effectivePassages]
      ..sort((left, right) => left.order.compareTo(right.order));
    _passageText = _passages
        .map(
          (passage) => BibleRepository().getVerseRange(
            book: passage.book,
            chapter: passage.chapter,
            startVerse: passage.startVerse,
            endVerse: passage.endVerse,
          ),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(dailyVerseLanguageProvider);
    return Scaffold(
      appBar: AppBar(title: Text(widget.section.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
        children: [
          Text(
            widget.section.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          if (widget.section.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(widget.section.description),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  context.t('learning.bible_passages'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              BibleLanguageToggle(provider: dailyVerseLanguageProvider),
            ],
          ),
          const SizedBox(height: 10),
          for (var index = 0; index < _passages.length; index++) ...[
            _PassageCard(
              passage: _passages[index],
              passageText: _passageText[index],
              language: language,
            ),
            const SizedBox(height: 12),
          ],
          if (widget.section.resources.isNotEmpty) ...[
            const SizedBox(height: 22),
            Text(
              context.t('learning.lesson_resources'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            for (final resource in ([...widget.section.resources]
              ..sort((left, right) => left.order.compareTo(right.order)))) ...[
              _LearningResourceView(resource: resource),
              const SizedBox(height: 12),
            ],
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton.icon(
          icon: Icon(
            widget.alreadyComplete
                ? Icons.check_circle_outline_rounded
                : Icons.arrow_forward_rounded,
          ),
          label: Text(
            context.t(
              widget.alreadyComplete
                  ? 'learning.section_completed'
                  : 'learning.complete_section',
            ),
          ),
          onPressed: _completing ? null : _completeSection,
        ),
      ),
    );
  }

  Future<void> _completeSection() async {
    if (widget.alreadyComplete) {
      Navigator.pop(context);
      return;
    }
    final churchId = ref.read(currentChurchIdProvider).asData?.value;
    final userId = ref.read(firebaseAuthProvider).currentUser?.uid;
    if (churchId == null || userId == null) return;
    setState(() => _completing = true);
    try {
      await ref.read(learningModuleRepositoryProvider).completeSection(
            churchId: churchId,
            userId: userId,
            sectionId: widget.section.id,
          );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      setState(() => _completing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('learning.progress_save_failed'))),
      );
    }
  }
}

class _PassageCard extends StatelessWidget {
  const _PassageCard({
    required this.passage,
    required this.passageText,
    required this.language,
  });

  final LearningPassage passage;
  final Future<Map<String, String>> passageText;
  final BibleLanguage language;

  @override
  Widget build(BuildContext context) => Container(
        decoration: carouselBoxDecoration(context),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              passage.reference,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            FutureBuilder<Map<String, String>>(
              future: passageText,
              builder: (context, snapshot) {
                if (!snapshot.hasData && !snapshot.hasError) {
                  return const Center(child: AppLoadingIndicator());
                }
                if (snapshot.hasError) {
                  return Text(context.t('faith.passage_load_failed'));
                }
                final key =
                    language == BibleLanguage.tamil ? 'tamil' : 'english';
                return Text(
                  snapshot.data![key] ?? snapshot.data!['english'] ?? '',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        height: 1.5,
                      ),
                );
              },
            ),
          ],
        ),
      );
}

class _LearningResourceView extends StatelessWidget {
  const _LearningResourceView({required this.resource});

  final LearningResource resource;

  @override
  Widget build(BuildContext context) {
    switch (resource.type) {
      case LearningResourceType.image:
        return _LearningImagePreview(resource: resource);
      case LearningResourceType.youtube:
        final uri = Uri.tryParse(resource.downloadUrl);
        final videoId =
            uri == null ? null : FeedLinkUtils.extractYoutubeVideoId(uri);
        if (videoId == null) {
          return _ResourceLinkTile(
            resource: resource,
            icon: Icons.play_circle_outline_rounded,
          );
        }
        return _LazyLearningVideo(
          videoId: videoId,
          title: resource.name,
        );
      case LearningResourceType.externalLink:
        return _ResourceLinkTile(
          resource: resource,
          icon: Icons.link_rounded,
        );
      case LearningResourceType.pdf:
        return _ResourceLinkTile(
          resource: resource,
          icon: Icons.picture_as_pdf_outlined,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => _LearningPdfScreen(resource: resource),
            ),
          ),
        );
    }
  }
}

class _ResourceLinkTile extends StatelessWidget {
  const _ResourceLinkTile({
    required this.resource,
    required this.icon,
    this.onTap,
  });

  final LearningResource resource;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Container(
        decoration: carouselBoxDecoration(context),
        child: ListTile(
          leading: Icon(icon),
          title: Text(resource.name),
          trailing: const Icon(Icons.open_in_new_rounded),
          onTap: onTap ??
              () => launchExternalUri(
                    context,
                    Uri.parse(resource.downloadUrl),
                    failureMessage: context.t('common.open_link_failed'),
                  ),
        ),
      );
}

class _LearningImagePreview extends StatelessWidget {
  const _LearningImagePreview({required this.resource});

  final LearningResource resource;

  @override
  Widget build(BuildContext context) {
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final previewWidth = (MediaQuery.sizeOf(context).width * pixelRatio)
        .round()
        .clamp(480, 1600);
    final heroTag = 'learning-image-${resource.downloadUrl}';
    return Material(
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.circular(cornerRadius),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: InkWell(
        onTap: () => showAppImageGallery(
          context,
          imageUrls: [resource.downloadUrl],
          title: resource.name,
          heroTagBuilder: (_, __) => heroTag,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Hero(
              tag: heroTag,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: CachedNetworkImage(
                  imageUrl: resource.downloadUrl,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  memCacheWidth: previewWidth,
                  fadeInDuration: const Duration(milliseconds: 180),
                  placeholder: (_, __) => const Center(
                    child: AppLoadingIndicator(),
                  ),
                  errorWidget: (_, __, ___) => const Center(
                    child: Icon(Icons.broken_image_outlined, size: 40),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 12,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.all(9),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.zoom_out_map_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LazyLearningVideo extends StatefulWidget {
  const _LazyLearningVideo({required this.videoId, required this.title});

  final String videoId;
  final String title;

  @override
  State<_LazyLearningVideo> createState() => _LazyLearningVideoState();
}

class _LazyLearningVideoState extends State<_LazyLearningVideo>
    with AutomaticKeepAliveClientMixin {
  final _playerController = AdaptiveYoutubePlayerController();
  bool _activated = false;

  @override
  bool get wantKeepAlive => _activated;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: carouselBoxDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _activated
              ? AdaptiveYoutubePlayer(
                  videoId: widget.videoId,
                  controller: _playerController,
                  autoPlay: true,
                  showFullscreenButton: false,
                )
              : AdaptiveYoutubeThumbnail(
                  videoId: widget.videoId,
                  onPlay: () {
                    setState(() => _activated = true);
                    updateKeepAlive();
                  },
                ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                IconButton(
                  tooltip: context.t('ui.live_church_section.full_screen'),
                  onPressed: _openFullscreen,
                  icon: const Icon(Icons.fullscreen_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openFullscreen() async {
    _playerController.pause();
    await showAdaptiveYoutubeFullscreen(
      context,
      videoId: widget.videoId,
    );
  }
}

class _LearningPdfScreen extends StatefulWidget {
  const _LearningPdfScreen({required this.resource});

  final LearningResource resource;

  @override
  State<_LearningPdfScreen> createState() => _LearningPdfScreenState();
}

class _LearningPdfScreenState extends State<_LearningPdfScreen> {
  static const _maximumPdfBytes = 16 * 1024 * 1024;
  late Future<Uint8List> _pdfBytes = _loadPdf();

  Future<Uint8List> _loadPdf() async {
    final storage = FirebaseStorage.instance;
    final reference = widget.resource.storagePath.trim().isNotEmpty
        ? storage.ref().child(widget.resource.storagePath.trim())
        : storage.refFromURL(widget.resource.downloadUrl);
    final bytes = await reference
        .getData(_maximumPdfBytes)
        .timeout(const Duration(seconds: 30));
    if (bytes == null || bytes.isEmpty) {
      throw StateError('The PDF contained no readable data.');
    }
    return bytes;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.resource.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: FutureBuilder<Uint8List>(
        future: _pdfBytes,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _PdfError(
              message: context.t('learning.pdf_load_failed'),
              onRetry: _retry,
            );
          }
          final bytes = snapshot.data;
          if (bytes == null) {
            return const Center(child: AppLoadingIndicator());
          }
          return PdfViewer.data(
            bytes,
            sourceName: widget.resource.storagePath.isNotEmpty
                ? widget.resource.storagePath
                : widget.resource.downloadUrl,
            useProgressiveLoading: false,
            params: PdfViewerParams(
              backgroundColor: Theme.of(context).colorScheme.surface,
              margin: 12,
              maxImageBytesCachedOnMemory: 48 * 1024 * 1024,
              errorBannerBuilder: (_, __, ___, ____) => _PdfError(
                message: context.t('learning.pdf_load_failed'),
                onRetry: _retry,
              ),
            ),
          );
        },
      ),
    );
  }

  void _retry() => setState(() => _pdfBytes = _loadPdf());
}

class _PdfError extends StatelessWidget {
  const _PdfError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.picture_as_pdf_outlined, size: 48),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(context.t('common.retry')),
              ),
            ],
          ),
        ),
      );
}

class _LearningQuizScreen extends ConsumerStatefulWidget {
  const _LearningQuizScreen({
    required this.module,
  });

  final LearningModule module;

  @override
  ConsumerState<_LearningQuizScreen> createState() =>
      _LearningQuizScreenState();
}

class _LearningQuizScreenState extends ConsumerState<_LearningQuizScreen> {
  late List<int?> _answers;
  bool _submitting = false;
  int? _score;

  @override
  void initState() {
    super.initState();
    _answers = List<int?>.filled(
        widget.module.effectiveFinalExamQuestions.length, null);
  }

  @override
  Widget build(BuildContext context) {
    final passed = _score != null &&
        learningQuizPasses(
          score: _score!,
          total: widget.module.effectiveFinalExamQuestions.length,
          passingPercentage: widget.module.passingPercentage,
        );
    return Scaffold(
      appBar: AppBar(title: Text(context.t('learning.final_exam'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
        children: [
          Text(
            widget.module.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            context.t(
              'learning.pass_requirement',
              parameters: {'count': widget.module.passingPercentage},
            ),
          ),
          const SizedBox(height: 18),
          for (var questionIndex = 0;
              questionIndex < widget.module.effectiveFinalExamQuestions.length;
              questionIndex++) ...[
            _LearningQuestionCard(
              number: questionIndex + 1,
              question:
                  widget.module.effectiveFinalExamQuestions[questionIndex],
              selected: _answers[questionIndex],
              revealAnswer: _score != null,
              onChanged: _score != null
                  ? null
                  : (value) => setState(() => _answers[questionIndex] = value),
            ),
            const SizedBox(height: 12),
          ],
          if (_score != null)
            Container(
              decoration: carouselBoxDecoration(context),
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  Icon(
                    passed
                        ? Icons.check_circle_outline_rounded
                        : Icons.refresh_rounded,
                    size: 46,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    context.t(
                      passed
                          ? 'learning.final_exam_module_completed'
                          : 'learning.quiz_try_again',
                    ),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.t(
                      'learning.quiz_result',
                      parameters: {
                        'score': _score!,
                        'total':
                            widget.module.effectiveFinalExamQuestions.length,
                      },
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton(
          onPressed: _submitting
              ? null
              : passed
                  ? () => Navigator.pop(context, true)
                  : _score == null
                      ? _submit
                      : _retry,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: _submitting
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    context.t(
                      passed
                          ? 'learning.continue_action'
                          : _score == null
                              ? 'faith.submit_quiz'
                              : 'learning.retry_quiz',
                    ),
                  ),
          ),
        ),
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
    final questions = widget.module.effectiveFinalExamQuestions;
    final score = Iterable<int>.generate(questions.length)
        .where(
          (index) => _answers[index] == questions[index].correctOptionIndex,
        )
        .length;
    final passed = learningQuizPasses(
      score: score,
      total: questions.length,
      passingPercentage: widget.module.passingPercentage,
    );
    final churchId = ref.read(currentChurchIdProvider).asData?.value;
    final userId = ref.read(firebaseAuthProvider).currentUser?.uid;
    final appUser = ref.read(appUserProvider).asData?.value;
    if (churchId == null || userId == null) return;
    setState(() => _submitting = true);
    try {
      await ref.read(learningModuleRepositoryProvider).submitModuleExam(
            churchId: churchId,
            userId: userId,
            moduleId: widget.module.id,
            userName: appUser?.name ?? '',
            userEmail: appUser?.email ?? '',
            answers: _answers.cast<int>(),
            score: score,
            total: questions.length,
            passed: passed,
          );
      if (!mounted) return;
      setState(() {
        _score = score;
        _submitting = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('learning.progress_save_failed'))),
      );
    }
  }

  void _retry() => setState(() {
        _answers = List<int?>.filled(
          widget.module.effectiveFinalExamQuestions.length,
          null,
        );
        _score = null;
      });
}

class _LearningQuestionCard extends StatelessWidget {
  const _LearningQuestionCard({
    required this.number,
    required this.question,
    required this.selected,
    required this.revealAnswer,
    required this.onChanged,
  });

  final int number;
  final LearningQuizQuestion question;
  final int? selected;
  final bool revealAnswer;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) => Container(
        decoration: carouselBoxDecoration(context),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t(
                'learning.question_number',
                parameters: {'count': number},
              ),
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 6),
            Text(
              question.prompt,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            RadioGroup<int>(
              groupValue: selected,
              onChanged: (value) {
                if (value != null) onChanged?.call(value);
              },
              child: Column(
                children: [
                  for (var index = 0; index < question.options.length; index++)
                    RadioListTile<int>(
                      contentPadding: EdgeInsets.zero,
                      value: index,
                      enabled: onChanged != null,
                      title: Text(question.options[index]),
                      secondary:
                          revealAnswer && index == question.correctOptionIndex
                              ? const Icon(
                                  Icons.check_circle_outline_rounded,
                                )
                              : null,
                    ),
                ],
              ),
            ),
          ],
        ),
      );
}
