import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';
import 'package:flutter_application/church_app/helpers/feed_link_utils.dart';
import 'package:flutter_application/church_app/models/learning_module_models.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
import 'package:flutter_application/church_app/services/learning_module_repository.dart';
import 'package:flutter_application/church_app/widgets/app_loading_indicator.dart';
import 'package:flutter_application/church_app/widgets/app_modal_bottom_sheet.dart';
import 'package:flutter_application/church_app/widgets/app_popup_menu.dart';
import 'package:flutter_application/church_app/widgets/app_text_field.dart';
import 'package:flutter_application/church_app/widgets/bible_verse_picker_sheet.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LearningModulesAdminScreen extends ConsumerWidget {
  const LearningModulesAdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = LearningModuleRepository(
      firestore: ref.read(firestoreProvider),
    );
    return Scaffold(
      appBar: AppBar(title: Text(context.t('learning.admin_title'))),
      body: StreamBuilder<List<LearningModule>>(
        stream: repository.watchAllModules(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: AppLoadingIndicator());
          }
          final modules = snapshot.data!;
          if (modules.isEmpty) {
            return _AdminEmptyState(
              onCreate: () => _openEditor(context, repository),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: modules.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final module = modules[index];
              return Container(
                decoration: carouselBoxDecoration(context),
                child: ListTile(
                  contentPadding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                  leading: CircleAvatar(
                    child: Text('${index + 1}'),
                  ),
                  title: Text(
                    module.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    context.t(
                      'learning.section_count',
                      parameters: {'count': module.sections.length},
                    ),
                  ),
                  trailing: AppPopupMenu<String>(
                    actions: [
                      if (index > 0)
                        AppPopupMenuAction(
                          value: 'move_up',
                          icon: Icons.arrow_upward_rounded,
                          label: context.t('common.move_up'),
                        ),
                      if (index < modules.length - 1)
                        AppPopupMenuAction(
                          value: 'move_down',
                          icon: Icons.arrow_downward_rounded,
                          label: context.t('common.move_down'),
                        ),
                      AppPopupMenuAction(
                        value: 'edit',
                        icon: Icons.edit_outlined,
                        label: context.t('common.edit'),
                      ),
                      AppPopupMenuAction(
                        value: 'delete',
                        icon: Icons.delete_outline,
                        label: context.t('common.delete'),
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ],
                    onSelected: (action) async {
                      if (action == 'move_up') {
                        await _moveModule(
                          context,
                          repository,
                          modules,
                          index,
                          -1,
                        );
                      } else if (action == 'move_down') {
                        await _moveModule(
                          context,
                          repository,
                          modules,
                          index,
                          1,
                        );
                      } else if (action == 'edit') {
                        await _openEditor(context, repository, module: module);
                      } else {
                        await _deleteModule(context, repository, module);
                      }
                    },
                  ),
                  onTap: () => _openEditor(context, repository, module: module),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context, repository),
        icon: const Icon(Icons.add_rounded),
        label: Text(context.t('learning.new_module')),
      ),
    );
  }

  Future<void> _openEditor(
    BuildContext context,
    LearningModuleRepository repository, {
    LearningModule? module,
  }) =>
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => LearningModuleEditorScreen(
            repository: repository,
            module: module,
          ),
        ),
      );

  Future<void> _deleteModule(
    BuildContext context,
    LearningModuleRepository repository,
    LearningModule module,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.t('learning.delete_module_title')),
        content: Text(context.t('learning.delete_module_message')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.t('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.t('common.delete')),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await repository.deleteModule(module);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('learning.delete_failed'))),
      );
    }
  }

  Future<void> _moveModule(
    BuildContext context,
    LearningModuleRepository repository,
    List<LearningModule> modules,
    int index,
    int direction,
  ) async {
    final reordered = [...modules];
    final module = reordered.removeAt(index);
    reordered.insert(index + direction, module);
    try {
      await repository.reorderGlobalModules(reordered);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('learning.reorder_failed'))),
      );
    }
  }
}

class _AdminEmptyState extends StatelessWidget {
  const _AdminEmptyState({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.school_outlined, size: 64),
              const SizedBox(height: 16),
              Text(
                context.t('learning.no_modules'),
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                context.t('learning.no_modules_hint'),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add_rounded),
                label: Text(context.t('learning.new_module')),
              ),
            ],
          ),
        ),
      );
}

class LearningModuleEditorScreen extends StatefulWidget {
  const LearningModuleEditorScreen({
    super.key,
    required this.repository,
    this.module,
    this.churchId,
    this.sourceModuleId = '',
  });

  final LearningModuleRepository repository;
  final LearningModule? module;
  final String? churchId;
  final String sourceModuleId;

  @override
  State<LearningModuleEditorScreen> createState() =>
      _LearningModuleEditorState();
}

class _LearningModuleEditorState extends State<LearningModuleEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final String _moduleId;
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final List<_SectionDraft> _sections;
  late final List<_QuestionDraft> _finalExamQuestions;
  late final TextEditingController _passingPercentage;
  final List<LearningResource> _removedResources = [];
  bool _enabled = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final module = widget.module;
    _moduleId = module?.id ?? widget.repository.createModuleId();
    _title = TextEditingController(text: module?.title ?? '');
    _description = TextEditingController(text: module?.description ?? '');
    _enabled = module?.enabled ?? true;
    _sections = module?.sections.map(_SectionDraft.fromSection).toList() ??
        [_SectionDraft.empty(widget.repository.createModuleId())];
    final existingQuestions = module?.effectiveFinalExamQuestions ?? const [];
    _finalExamQuestions = existingQuestions.isEmpty
        ? [_QuestionDraft.empty()]
        : existingQuestions.map(_QuestionDraft.fromQuestion).toList();
    _passingPercentage = TextEditingController(
      text: '${module?.passingPercentage ?? 70}',
    );
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _passingPercentage.dispose();
    for (final question in _finalExamQuestions) {
      question.dispose();
    }
    for (final section in _sections) {
      section.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(
            context.t(
              widget.module == null
                  ? 'learning.create_module'
                  : 'learning.edit_module',
            ),
          ),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
            children: [
              Container(
                decoration: carouselBoxDecoration(context),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    AppTextField(
                      controller: _title,
                      label: context.t('learning.module_title'),
                      validator: _required,
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _description,
                      label: context.t('common.description'),
                      maxLines: 4,
                      validator: _required,
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: Text(context.t('common.active')),
                      value: _enabled,
                      onChanged: (value) => setState(() => _enabled = value),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.t('learning.sections_title'),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _addSection,
                    icon: const Icon(Icons.add_rounded),
                    label: Text(context.t('learning.add_section')),
                  ),
                ],
              ),
              Text(context.t('learning.sections_hint')),
              const SizedBox(height: 12),
              for (var index = 0; index < _sections.length; index++) ...[
                _SectionEditorCard(
                  key: ObjectKey(_sections[index]),
                  index: index,
                  draft: _sections[index],
                  canDelete: _sections.length > 1,
                  onMoveUp: index == 0 ? null : () => _moveSection(index, -1),
                  onMoveDown: index == _sections.length - 1
                      ? null
                      : () => _moveSection(index, 1),
                  onDelete: () => _removeSection(index),
                  onResourceRemoved: _removedResources.add,
                ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 8),
              Container(
                decoration: carouselBoxDecoration(context),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _EditorHeading(
                      title: context.t('learning.final_exam'),
                      action: TextButton.icon(
                        onPressed: () => setState(
                          () => _finalExamQuestions.add(_QuestionDraft.empty()),
                        ),
                        icon: const Icon(Icons.add_rounded),
                        label: Text(context.t('faith.add_question')),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(context.t('learning.final_exam_hint')),
                    ),
                    const SizedBox(height: 12),
                    for (var index = 0;
                        index < _finalExamQuestions.length;
                        index++) ...[
                      _QuestionEditor(
                        index: index,
                        draft: _finalExamQuestions[index],
                        canDelete: _finalExamQuestions.length > 1,
                        onDelete: () => setState(() {
                          _finalExamQuestions.removeAt(index).dispose();
                        }),
                      ),
                      const SizedBox(height: 10),
                    ],
                    AppTextField(
                      controller: _passingPercentage,
                      label: context.t('learning.passing_percentage'),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        final parsed = int.tryParse(value ?? '');
                        return parsed == null || parsed < 1 || parsed > 100
                            ? context.t('learning.percentage_required')
                            : null;
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            onPressed: _saving ? null : _save,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: _saving
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(context.t('common.save')),
            ),
          ),
        ),
      );

  String? _required(String? value) => value == null || value.trim().isEmpty
      ? context.t('common.required_field')
      : null;

  void _addSection() => setState(
        () => _sections.add(
          _SectionDraft.empty(widget.repository.createModuleId()),
        ),
      );

  void _moveSection(int index, int direction) => setState(() {
        final item = _sections.removeAt(index);
        _sections.insert(index + direction, item);
      });

  void _removeSection(int index) => setState(() {
        final removed = _sections.removeAt(index);
        _removedResources.addAll(removed.existingResources);
        removed.dispose();
      });

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    for (final section in _sections) {
      if (!section.isConfigured) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t('learning.section_incomplete'))),
        );
        return;
      }
    }
    if (_finalExamQuestions.isEmpty ||
        _finalExamQuestions.any((question) => !question.isConfigured)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('learning.final_exam_incomplete'))),
      );
      return;
    }
    setState(() => _saving = true);
    final newlyUploaded = <LearningResource>[];
    try {
      final moduleOrder = widget.module?.order ??
          await widget.repository.nextModuleOrder(churchId: widget.churchId);
      final builtSections = <LearningSection>[];
      for (var index = 0; index < _sections.length; index++) {
        final draft = _sections[index];
        final resources = <LearningResource>[];
        for (var resourceIndex = 0;
            resourceIndex < draft.resources.length;
            resourceIndex++) {
          final resourceDraft = draft.resources[resourceIndex];
          final existing = resourceDraft.existing;
          if (existing == null) continue;
          final churchId = widget.churchId;
          final ownedPrefix = churchId == null
              ? ''
              : 'churches/$churchId/learning_modules/$_moduleId/';
          if (churchId != null &&
              existing.storagePath.isNotEmpty &&
              !existing.storagePath.startsWith(ownedPrefix)) {
            final copied = await widget.repository.copyResourceToChurch(
              churchId: churchId,
              moduleId: _moduleId,
              sectionId: draft.id,
              resource: existing,
            );
            newlyUploaded.add(copied);
            resources.add(copied.withOrder((resourceIndex + 1) * 10));
          } else {
            resources.add(existing.withOrder((resourceIndex + 1) * 10));
          }
        }
        for (var resourceIndex = 0;
            resourceIndex < draft.resources.length;
            resourceIndex++) {
          final pending = draft.resources[resourceIndex];
          if (pending.existing != null) continue;
          if (pending.bytes == null) {
            resources.add(pending.build((resourceIndex + 1) * 10));
            continue;
          }
          final uploaded = await widget.repository.uploadResource(
            moduleId: _moduleId,
            sectionId: draft.id,
            fileName: pending.name,
            bytes: pending.bytes!,
            type: pending.type,
            contentType: pending.contentType,
            order: (resourceIndex + 1) * 10,
            churchId: widget.churchId,
          );
          newlyUploaded.add(uploaded);
          resources.add(uploaded);
        }
        builtSections.add(draft.build(index: index, resources: resources));
      }
      final churchId = widget.churchId;
      if (churchId == null) {
        await widget.repository.saveModule(
          id: _moduleId,
          title: _title.text,
          description: _description.text,
          order: moduleOrder,
          enabled: _enabled,
          sections: builtSections,
          finalExamQuestions:
              _finalExamQuestions.map((question) => question.build()).toList(),
          passingPercentage: int.parse(_passingPercentage.text),
        );
      } else {
        await widget.repository.saveChurchModule(
          churchId: churchId,
          id: _moduleId,
          title: _title.text,
          description: _description.text,
          order: moduleOrder,
          enabled: _enabled,
          sections: builtSections,
          finalExamQuestions:
              _finalExamQuestions.map((question) => question.build()).toList(),
          passingPercentage: int.parse(_passingPercentage.text),
          sourceModuleId: widget.sourceModuleId.isNotEmpty
              ? widget.sourceModuleId
              : widget.module?.sourceModuleId ?? '',
        );
      }
      for (final resource in _removedResources) {
        final canDelete = churchId == null ||
            resource.storagePath.startsWith(
              'churches/$churchId/learning_modules/$_moduleId/',
            );
        if (canDelete) await widget.repository.deleteResource(resource);
      }
      if (!mounted) return;
      Navigator.pop(context);
    } catch (_) {
      for (final resource in newlyUploaded) {
        try {
          await widget.repository.deleteResource(resource);
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('learning.save_failed'))),
      );
    }
  }
}

class _SectionEditorCard extends StatefulWidget {
  const _SectionEditorCard({
    super.key,
    required this.index,
    required this.draft,
    required this.canDelete,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onDelete,
    required this.onResourceRemoved,
  });

  final int index;
  final _SectionDraft draft;
  final bool canDelete;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback onDelete;
  final ValueChanged<LearningResource> onResourceRemoved;

  @override
  State<_SectionEditorCard> createState() => _SectionEditorCardState();
}

class _SectionEditorCardState extends State<_SectionEditorCard> {
  bool _pickingFile = false;

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    return Container(
      decoration: carouselBoxDecoration(context),
      child: ExpansionTile(
        initiallyExpanded: widget.index == 0,
        title: Text(
          draft.title.text.trim().isEmpty
              ? context.t(
                  'learning.section_number',
                  parameters: {'count': widget.index + 1},
                )
              : draft.title.text,
        ),
        subtitle: Text(
          draft.passages.isEmpty
              ? context.t('learning.passage_not_selected')
              : context.t(
                  'learning.passage_count',
                  parameters: {'count': draft.passages.length},
                ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                tooltip: context.t('common.move_up'),
                onPressed: widget.onMoveUp,
                icon: const Icon(Icons.arrow_upward_rounded),
              ),
              IconButton(
                tooltip: context.t('common.move_down'),
                onPressed: widget.onMoveDown,
                icon: const Icon(Icons.arrow_downward_rounded),
              ),
              IconButton(
                tooltip: context.t('common.delete'),
                onPressed: widget.canDelete ? widget.onDelete : null,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          AppTextField(
            controller: draft.title,
            label: context.t('learning.section_title'),
            validator: _required,
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: draft.description,
            label: context.t('common.description'),
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          _EditorHeading(
            title: context.t('learning.bible_passages'),
            action: TextButton.icon(
              onPressed: () => _pickPassage(),
              icon: const Icon(Icons.add_rounded),
              label: Text(context.t('learning.add_passage')),
            ),
          ),
          if (draft.passages.isEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(context.t('learning.passage_not_selected')),
            ),
          for (var index = 0; index < draft.passages.length; index++)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.menu_book_outlined),
              title: Text(draft.passages[index].reference),
              onTap: () => _pickPassage(index: index),
              trailing: _OrderAndDeleteActions(
                onMoveUp:
                    index == 0 ? null : () => _move(draft.passages, index, -1),
                onMoveDown: index == draft.passages.length - 1
                    ? null
                    : () => _move(draft.passages, index, 1),
                onDelete: () => setState(() => draft.passages.removeAt(index)),
              ),
            ),
          const Divider(),
          _EditorHeading(
            title: context.t('learning.lesson_resources'),
            action: TextButton.icon(
              onPressed: _chooseResourceType,
              icon: const Icon(Icons.add_rounded),
              label: Text(context.t('learning.add_resource')),
            ),
          ),
          if (draft.resources.isEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(context.t('learning.resources_optional')),
            ),
          for (var index = 0; index < draft.resources.length; index++)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(_resourceIcon(draft.resources[index].type)),
              title: Text(draft.resources[index].name),
              subtitle: Text(
                _resourceTypeLabel(context, draft.resources[index].type),
              ),
              trailing: _OrderAndDeleteActions(
                onMoveUp:
                    index == 0 ? null : () => _move(draft.resources, index, -1),
                onMoveDown: index == draft.resources.length - 1
                    ? null
                    : () => _move(draft.resources, index, 1),
                onDelete: () => setState(() {
                  final removed = draft.resources.removeAt(index);
                  if (removed.existing != null) {
                    widget.onResourceRemoved(removed.existing!);
                  }
                }),
              ),
            ),
        ],
      ),
    );
  }

  String? _required(String? value) => value == null || value.trim().isEmpty
      ? context.t('common.required_field')
      : null;

  Future<void> _chooseResourceType() async {
    LearningResourceType? selectedLinkType;
    await showAppModalBottomSheet<void>(
      context: context,
      heightFactor: 0.48,
      builder: (sheetContext) => ListView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
        children: [
          Text(
            context.t('learning.add_resource'),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 12),
          _ResourceChoiceTile(
            icon: Icons.image_outlined,
            label: context.t('learning.upload_image'),
            onTap: () {
              unawaited(_pickFile(LearningResourceType.image));
              Navigator.pop(sheetContext);
            },
          ),
          _ResourceChoiceTile(
            icon: Icons.play_circle_outline_rounded,
            label: context.t('learning.add_youtube_link'),
            onTap: () {
              selectedLinkType = LearningResourceType.youtube;
              Navigator.pop(sheetContext);
            },
          ),
          _ResourceChoiceTile(
            icon: Icons.link_rounded,
            label: context.t('learning.add_external_link'),
            onTap: () {
              selectedLinkType = LearningResourceType.externalLink;
              Navigator.pop(sheetContext);
            },
          ),
          _ResourceChoiceTile(
            icon: Icons.picture_as_pdf_outlined,
            label: context.t('learning.upload_pdf'),
            onTap: () {
              unawaited(_pickFile(LearningResourceType.pdf));
              Navigator.pop(sheetContext);
            },
          ),
        ],
      ),
    );
    if (selectedLinkType != null && mounted) {
      await _addLink(selectedLinkType!);
    }
  }

  Future<void> _pickPassage({int? index}) => showBibleVerseRangePickerSheet(
        context,
        title: context.t('learning.choose_passage'),
        initialBook: index == null
            ? context.t('learning.default_bible_book')
            : widget.draft.passages[index].book,
        initialChapter:
            index == null ? 1 : widget.draft.passages[index].chapter,
        initialStartVerse:
            index == null ? 1 : widget.draft.passages[index].startVerse,
        initialEndVerse:
            index == null ? 1 : widget.draft.passages[index].endVerse,
        onSave: ({
          required book,
          required chapter,
          required startVerse,
          required endVerse,
        }) async {
          final passage = _PassageDraft(
            book: book,
            chapter: chapter,
            startVerse: startVerse,
            endVerse: endVerse,
          );
          setState(() {
            index == null
                ? widget.draft.passages.add(passage)
                : widget.draft.passages[index] = passage;
          });
        },
      );

  Future<void> _pickFile(LearningResourceType type) async {
    if (_pickingFile || !mounted) return;
    setState(() => _pickingFile = true);
    try {
      final isPdf = type == LearningResourceType.pdf;
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions:
            isPdf ? const ['pdf'] : const ['jpg', 'jpeg', 'png', 'webp'],
        allowMultiple: true,
        withData: true,
        cancelUploadOnWindowBlur: false,
      );
      if (result == null || !mounted) return;
      final selectedResources = <_ResourceDraft>[];
      var skippedLargeFile = false;
      for (final file in result.files) {
        final bytes = await _readPickedFile(file);
        if (bytes.lengthInBytes > 15 * 1024 * 1024) {
          skippedLargeFile = true;
          continue;
        }
        selectedResources.add(
          _ResourceDraft.pending(
            name: file.name,
            bytes: bytes,
            type: type,
          ),
        );
      }
      if (skippedLargeFile && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t('learning.resource_too_large'))),
        );
      }
      if (selectedResources.isNotEmpty && mounted) {
        setState(() => widget.draft.resources.addAll(selectedResources));
      }
    } catch (error, stackTrace) {
      debugPrint('Learning resource picker failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('learning.resource_pick_failed'))),
      );
    } finally {
      if (mounted) setState(() => _pickingFile = false);
    }
  }

  Future<Uint8List> _readPickedFile(PlatformFile file) async {
    final bytes = file.bytes;
    if (bytes != null) return bytes;

    final stream = file.readStream;
    if (stream != null) {
      final builder = BytesBuilder(copy: false);
      await for (final chunk in stream) {
        builder.add(chunk);
      }
      return builder.takeBytes();
    }

    if (!kIsWeb && (file.path?.isNotEmpty ?? false)) {
      return file.xFile.readAsBytes();
    }

    throw StateError('No readable data source was returned for ${file.name}.');
  }

  Future<void> _addLink(LearningResourceType type) async {
    final resource = await showDialog<_ResourceDraft>(
      context: context,
      builder: (_) => _LearningResourceLinkDialog(type: type),
    );
    if (resource != null && mounted) {
      setState(() => widget.draft.resources.add(resource));
    }
  }

  void _move<T>(List<T> items, int index, int direction) => setState(() {
        final item = items.removeAt(index);
        items.insert(index + direction, item);
      });
}

class _LearningResourceLinkDialog extends StatefulWidget {
  const _LearningResourceLinkDialog({required this.type});

  final LearningResourceType type;

  @override
  State<_LearningResourceLinkDialog> createState() =>
      _LearningResourceLinkDialogState();
}

class _LearningResourceLinkDialogState
    extends State<_LearningResourceLinkDialog> {
  final _title = TextEditingController();
  final _url = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(
          context.t(
            widget.type == LearningResourceType.youtube
                ? 'learning.add_youtube_link'
                : 'learning.add_external_link',
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(
                controller: _title,
                label: context.t('common.title'),
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _url,
                label: context.t('learning.resource_url'),
                keyboardType: TextInputType.url,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.t('common.cancel')),
          ),
          FilledButton(
            onPressed: _submit,
            child: Text(context.t('common.add')),
          ),
        ],
      );

  void _submit() {
    final title = _title.text.trim();
    final url = _url.text.trim();
    final uri = Uri.tryParse(url);
    final validHttp =
        uri != null && (uri.scheme == 'https' || uri.scheme == 'http');
    final validYoutube = widget.type != LearningResourceType.youtube ||
        (uri != null && FeedLinkUtils.extractYoutubeVideoId(uri) != null);
    if (title.isEmpty || !validHttp || !validYoutube) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('learning.link_invalid'))),
      );
      return;
    }
    Navigator.pop(
      context,
      _ResourceDraft.link(name: title, url: url, type: widget.type),
    );
  }
}

class _OrderAndDeleteActions extends StatelessWidget {
  const _OrderAndDeleteActions({
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onDelete,
  });

  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onMoveUp,
            icon: const Icon(Icons.arrow_upward_rounded),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onMoveDown,
            icon: const Icon(Icons.arrow_downward_rounded),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onDelete,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      );
}

class _ResourceChoiceTile extends StatelessWidget {
  const _ResourceChoiceTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          tileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          leading: Icon(icon),
          title: Text(label),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onTap,
        ),
      );
}

IconData _resourceIcon(LearningResourceType type) => switch (type) {
      LearningResourceType.pdf => Icons.picture_as_pdf_outlined,
      LearningResourceType.image => Icons.image_outlined,
      LearningResourceType.youtube => Icons.play_circle_outline_rounded,
      LearningResourceType.externalLink => Icons.link_rounded,
    };

String _resourceTypeLabel(
  BuildContext context,
  LearningResourceType type,
) =>
    switch (type) {
      LearningResourceType.pdf => context.t('learning.resource_type_pdf'),
      LearningResourceType.image => context.t('learning.resource_type_image'),
      LearningResourceType.youtube =>
        context.t('learning.resource_type_youtube'),
      LearningResourceType.externalLink =>
        context.t('learning.resource_type_externalLink'),
    };

class _QuestionEditor extends StatelessWidget {
  const _QuestionEditor({
    required this.index,
    required this.draft,
    required this.canDelete,
    required this.onDelete,
  });

  final int index;
  final _QuestionDraft draft;
  final bool canDelete;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border:
              Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.t(
                      'learning.question_number',
                      parameters: {'count': index + 1},
                    ),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  onPressed: canDelete ? onDelete : null,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            AppTextField(
              controller: draft.prompt,
              label: context.t('faith.question_prompt'),
              validator: _required(context),
            ),
            const SizedBox(height: 10),
            for (var option = 0; option < draft.options.length; option++) ...[
              AppTextField(
                controller: draft.options[option],
                label: context.t(
                  'learning.option_number',
                  parameters: {'count': option + 1},
                ),
                validator: _required(context),
              ),
              const SizedBox(height: 8),
            ],
            DropdownButtonFormField<int>(
              initialValue: draft.correctOptionIndex,
              decoration: appTextFieldDecoration(
                context,
                labelText: context.t('faith.correct_answer'),
              ),
              items: List.generate(
                draft.options.length,
                (index) => DropdownMenuItem(
                  value: index,
                  child: Text(
                    context.t(
                      'learning.option_number',
                      parameters: {'count': index + 1},
                    ),
                  ),
                ),
              ),
              onChanged: (value) => draft.correctOptionIndex = value ?? 0,
            ),
          ],
        ),
      );

  FormFieldValidator<String> _required(BuildContext context) =>
      (value) => value == null || value.trim().isEmpty
          ? context.t('common.required_field')
          : null;
}

class _EditorHeading extends StatelessWidget {
  const _EditorHeading({required this.title, required this.action});
  final String title;
  final Widget action;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          action,
        ],
      );
}

class _SectionDraft {
  _SectionDraft({
    required this.id,
    required this.title,
    required this.description,
    required this.passages,
    required this.resources,
  });

  factory _SectionDraft.empty(String id) => _SectionDraft(
        id: id,
        title: TextEditingController(),
        description: TextEditingController(),
        passages: [],
        resources: [],
      );

  factory _SectionDraft.fromSection(LearningSection section) => _SectionDraft(
        id: section.id,
        title: TextEditingController(text: section.title),
        description: TextEditingController(text: section.description),
        passages:
            section.effectivePassages.map(_PassageDraft.fromPassage).toList(),
        resources: ([...section.resources]
              ..sort((left, right) => left.order.compareTo(right.order)))
            .map(_ResourceDraft.fromResource)
            .toList(),
      );

  final String id;
  final TextEditingController title;
  final TextEditingController description;
  final List<_PassageDraft> passages;
  final List<_ResourceDraft> resources;

  List<LearningResource> get existingResources => resources
      .map((resource) => resource.existing)
      .whereType<LearningResource>()
      .toList(growable: false);

  bool get isConfigured => title.text.trim().isNotEmpty && passages.isNotEmpty;

  LearningSection build({
    required int index,
    required List<LearningResource> resources,
  }) =>
      LearningSection(
        id: id,
        title: title.text.trim(),
        description: description.text.trim(),
        scriptureBook: passages.first.book,
        scriptureChapter: passages.first.chapter,
        scriptureStartVerse: passages.first.startVerse,
        scriptureEndVerse: passages.first.endVerse,
        passages: [
          for (var passageIndex = 0;
              passageIndex < passages.length;
              passageIndex++)
            passages[passageIndex].build((passageIndex + 1) * 10),
        ],
        resources: resources,
        questions: const [],
        order: (index + 1) * 10,
        passingPercentage: 70,
      );

  void dispose() {
    title.dispose();
    description.dispose();
  }
}

class _PassageDraft {
  const _PassageDraft({
    required this.book,
    required this.chapter,
    required this.startVerse,
    required this.endVerse,
  });

  factory _PassageDraft.fromPassage(LearningPassage passage) => _PassageDraft(
        book: passage.book,
        chapter: passage.chapter,
        startVerse: passage.startVerse,
        endVerse: passage.endVerse,
      );

  final String book;
  final int chapter;
  final int startVerse;
  final int endVerse;

  String get reference {
    final verses =
        startVerse == endVerse ? '$startVerse' : '$startVerse-$endVerse';
    return '$book $chapter:$verses';
  }

  LearningPassage build(int order) => LearningPassage(
        book: book,
        chapter: chapter,
        startVerse: startVerse,
        endVerse: endVerse,
        order: order,
      );
}

class _ResourceDraft {
  const _ResourceDraft({
    required this.name,
    required this.url,
    required this.type,
    required this.bytes,
    required this.existing,
  });

  factory _ResourceDraft.fromResource(LearningResource resource) =>
      _ResourceDraft(
        name: resource.name,
        url: resource.downloadUrl,
        type: resource.type,
        bytes: null,
        existing: resource,
      );

  factory _ResourceDraft.pending({
    required String name,
    required Uint8List bytes,
    required LearningResourceType type,
  }) =>
      _ResourceDraft(
        name: name,
        url: '',
        type: type,
        bytes: bytes,
        existing: null,
      );

  factory _ResourceDraft.link({
    required String name,
    required String url,
    required LearningResourceType type,
  }) =>
      _ResourceDraft(
        name: name,
        url: url,
        type: type,
        bytes: null,
        existing: null,
      );

  final String name;
  final String url;
  final LearningResourceType type;
  final Uint8List? bytes;
  final LearningResource? existing;

  String get contentType => type == LearningResourceType.pdf
      ? 'application/pdf'
      : switch (name.split('.').last.toLowerCase()) {
          'png' => 'image/png',
          'webp' => 'image/webp',
          _ => 'image/jpeg',
        };

  LearningResource build(int order) => LearningResource(
        name: name,
        downloadUrl: url,
        storagePath: '',
        type: type,
        order: order,
      );
}

class _QuestionDraft {
  _QuestionDraft({
    required this.prompt,
    required this.options,
    required this.correctOptionIndex,
  });

  factory _QuestionDraft.empty() => _QuestionDraft(
        prompt: TextEditingController(),
        options: List.generate(4, (_) => TextEditingController()),
        correctOptionIndex: 0,
      );

  factory _QuestionDraft.fromQuestion(LearningQuizQuestion question) =>
      _QuestionDraft(
        prompt: TextEditingController(text: question.prompt),
        options: List.generate(
          4,
          (index) => TextEditingController(
            text:
                index < question.options.length ? question.options[index] : '',
          ),
        ),
        correctOptionIndex: question.correctOptionIndex.clamp(0, 3),
      );

  final TextEditingController prompt;
  final List<TextEditingController> options;
  int correctOptionIndex;

  bool get isConfigured =>
      prompt.text.trim().isNotEmpty &&
      options.every((option) => option.text.trim().isNotEmpty);

  LearningQuizQuestion build() => LearningQuizQuestion(
        prompt: prompt.text.trim(),
        options: options.map((option) => option.text.trim()).toList(),
        correctOptionIndex: correctOptionIndex,
      );

  void dispose() {
    prompt.dispose();
    for (final option in options) {
      option.dispose();
    }
  }
}
