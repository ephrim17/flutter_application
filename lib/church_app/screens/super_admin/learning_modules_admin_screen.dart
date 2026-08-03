import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';
import 'package:flutter_application/church_app/models/learning_module_models.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
import 'package:flutter_application/church_app/services/learning_module_repository.dart';
import 'package:flutter_application/church_app/widgets/app_loading_indicator.dart';
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
                      if (action == 'edit') {
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
  late final TextEditingController _order;
  late final List<_SectionDraft> _sections;
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
    _order = TextEditingController(text: '${module?.order ?? 100}');
    _enabled = module?.enabled ?? true;
    _sections = module?.sections.map(_SectionDraft.fromSection).toList() ??
        [_SectionDraft.empty(widget.repository.createModuleId())];
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _order.dispose();
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
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _order,
                      label: context.t('learning.module_order'),
                      keyboardType: TextInputType.number,
                      validator: _positiveNumber,
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

  String? _positiveNumber(String? value) => int.tryParse(value ?? '') == null
      ? context.t('learning.number_required')
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
    setState(() => _saving = true);
    final newlyUploaded = <LearningResource>[];
    try {
      final builtSections = <LearningSection>[];
      for (var index = 0; index < _sections.length; index++) {
        final draft = _sections[index];
        final resources = <LearningResource>[];
        for (final existing in draft.existingResources) {
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
            resources.add(copied);
          } else {
            resources.add(existing);
          }
        }
        for (final pending in draft.pendingResources) {
          final uploaded = await widget.repository.uploadPdf(
            moduleId: _moduleId,
            sectionId: draft.id,
            fileName: pending.name,
            bytes: pending.bytes,
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
          order: int.parse(_order.text),
          enabled: _enabled,
          sections: builtSections,
        );
      } else {
        await widget.repository.saveChurchModule(
          churchId: churchId,
          id: _moduleId,
          title: _title.text,
          description: _description.text,
          order: int.parse(_order.text),
          enabled: _enabled,
          sections: builtSections,
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
          draft.scriptureBook.isEmpty
              ? context.t('learning.passage_not_selected')
              : draft.scriptureReference,
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
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.menu_book_outlined),
            title: Text(context.t('learning.bible_passage')),
            subtitle: Text(
              draft.scriptureBook.isEmpty
                  ? context.t('learning.passage_not_selected')
                  : draft.scriptureReference,
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => showBibleVerseRangePickerSheet(
              context,
              title: context.t('learning.choose_passage'),
              initialBook:
                  draft.scriptureBook.isEmpty ? 'Genesis' : draft.scriptureBook,
              initialChapter: draft.scriptureChapter,
              initialStartVerse: draft.scriptureStartVerse,
              initialEndVerse: draft.scriptureEndVerse,
              onSave: ({
                required book,
                required chapter,
                required startVerse,
                required endVerse,
              }) async {
                setState(() {
                  draft.scriptureBook = book;
                  draft.scriptureChapter = chapter;
                  draft.scriptureStartVerse = startVerse;
                  draft.scriptureEndVerse = endVerse;
                });
              },
            ),
          ),
          const Divider(),
          _EditorHeading(
            title: context.t('learning.supporting_documents'),
            action: TextButton.icon(
              onPressed: _pickingFile ? null : _pickPdf,
              icon: const Icon(Icons.upload_file_outlined),
              label: Text(context.t('learning.upload_pdf')),
            ),
          ),
          if (draft.existingResources.isEmpty && draft.pendingResources.isEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(context.t('learning.documents_optional')),
            ),
          for (var index = 0; index < draft.existingResources.length; index++)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: Text(draft.existingResources[index].name),
              trailing: IconButton(
                onPressed: () => setState(() {
                  widget.onResourceRemoved(draft.existingResources[index]);
                  draft.existingResources.removeAt(index);
                }),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
          for (var index = 0; index < draft.pendingResources.length; index++)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: Text(draft.pendingResources[index].name),
              trailing: IconButton(
                onPressed: () => setState(
                  () => draft.pendingResources.removeAt(index),
                ),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
          const Divider(),
          _EditorHeading(
            title: context.t('learning.section_quiz'),
            action: TextButton.icon(
              onPressed: () => setState(
                () => draft.questions.add(_QuestionDraft.empty()),
              ),
              icon: const Icon(Icons.add_rounded),
              label: Text(context.t('faith.add_question')),
            ),
          ),
          for (var index = 0; index < draft.questions.length; index++) ...[
            _QuestionEditor(
              index: index,
              draft: draft.questions[index],
              canDelete: draft.questions.length > 1,
              onDelete: () => setState(() {
                draft.questions.removeAt(index).dispose();
              }),
            ),
            const SizedBox(height: 10),
          ],
          AppTextField(
            controller: draft.passingPercentage,
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
    );
  }

  String? _required(String? value) => value == null || value.trim().isEmpty
      ? context.t('common.required_field')
      : null;

  Future<void> _pickPdf() async {
    setState(() => _pickingFile = true);
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        withData: true,
      );
      if (result == null || !mounted) return;
      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null) throw StateError('PDF bytes were unavailable.');
      if (bytes.lengthInBytes > 15 * 1024 * 1024) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t('learning.pdf_too_large'))),
        );
        return;
      }
      setState(() {
        widget.draft.pendingResources.add(
          _PendingResource(name: file.name, bytes: bytes),
        );
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('learning.pdf_pick_failed'))),
      );
    } finally {
      if (mounted) setState(() => _pickingFile = false);
    }
  }
}

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
    required this.scriptureBook,
    required this.scriptureChapter,
    required this.scriptureStartVerse,
    required this.scriptureEndVerse,
    required this.existingResources,
    required this.questions,
    required this.passingPercentage,
  });

  factory _SectionDraft.empty(String id) => _SectionDraft(
        id: id,
        title: TextEditingController(),
        description: TextEditingController(),
        scriptureBook: '',
        scriptureChapter: 1,
        scriptureStartVerse: 1,
        scriptureEndVerse: 1,
        existingResources: [],
        questions: [_QuestionDraft.empty()],
        passingPercentage: TextEditingController(text: '70'),
      );

  factory _SectionDraft.fromSection(LearningSection section) => _SectionDraft(
        id: section.id,
        title: TextEditingController(text: section.title),
        description: TextEditingController(text: section.description),
        scriptureBook: section.scriptureBook,
        scriptureChapter: section.scriptureChapter,
        scriptureStartVerse: section.scriptureStartVerse,
        scriptureEndVerse: section.scriptureEndVerse,
        existingResources: [...section.resources],
        questions: section.questions.map(_QuestionDraft.fromQuestion).toList(),
        passingPercentage:
            TextEditingController(text: '${section.passingPercentage}'),
      );

  final String id;
  final TextEditingController title;
  final TextEditingController description;
  String scriptureBook;
  int scriptureChapter;
  int scriptureStartVerse;
  int scriptureEndVerse;
  final List<LearningResource> existingResources;
  final List<_PendingResource> pendingResources = [];
  final List<_QuestionDraft> questions;
  final TextEditingController passingPercentage;

  String get scriptureReference {
    final verses = scriptureStartVerse == scriptureEndVerse
        ? '$scriptureStartVerse'
        : '$scriptureStartVerse-$scriptureEndVerse';
    return '$scriptureBook $scriptureChapter:$verses';
  }

  bool get isConfigured =>
      title.text.trim().isNotEmpty &&
      scriptureBook.isNotEmpty &&
      questions.isNotEmpty &&
      questions.every((question) => question.isConfigured) &&
      int.tryParse(passingPercentage.text) != null;

  LearningSection build({
    required int index,
    required List<LearningResource> resources,
  }) =>
      LearningSection(
        id: id,
        title: title.text.trim(),
        description: description.text.trim(),
        scriptureBook: scriptureBook,
        scriptureChapter: scriptureChapter,
        scriptureStartVerse: scriptureStartVerse,
        scriptureEndVerse: scriptureEndVerse,
        resources: resources,
        questions: questions.map((question) => question.build()).toList(),
        order: (index + 1) * 10,
        passingPercentage: int.parse(passingPercentage.text),
      );

  void dispose() {
    title.dispose();
    description.dispose();
    passingPercentage.dispose();
    for (final question in questions) {
      question.dispose();
    }
  }
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

class _PendingResource {
  const _PendingResource({required this.name, required this.bytes});
  final String name;
  final Uint8List bytes;
}
