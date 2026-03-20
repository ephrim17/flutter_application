import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/models/app_config_model.dart';
import 'package:flutter_application/church_app/models/bible_book_model.dart';
import 'package:flutter_application/church_app/models/picked_image_data.dart';
import 'package:flutter_application/church_app/providers/app_config_provider.dart';
import 'package:flutter_application/church_app/providers/authentication/admin_provider.dart';
import 'package:flutter_application/church_app/providers/church_provider.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_provider.dart';
import 'package:flutter_application/church_app/services/side_drawer/bible_book_repository.dart';
import 'package:flutter_application/church_app/services/studio/studio_repository.dart';
import 'package:flutter_application/church_app/widgets/app_bar_title_widget.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class StudioScreen extends ConsumerWidget {
  const StudioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);
    final churchIdAsync = ref.watch(currentChurchIdProvider);

    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(title: Text(ref.t('studio.title', fallback: 'Studio'))),
        body: Center(
          child: Text(ref.t('studio.admin_only',
              fallback: 'Studio is available only for admins.')),
        ),
      );
    }

    return churchIdAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: Text(ref.t('studio.title', fallback: 'Studio'))),
        body: Center(
            child: Text(
                '${ref.t('common.error_prefix', fallback: 'Error')}: $error')),
      ),
      data: (churchId) {
        if (churchId == null) {
          return Scaffold(
            appBar:
                AppBar(title: Text(ref.t('studio.title', fallback: 'Studio'))),
            body: Center(
                child: Text(ref.t('studio.no_church_selected',
                    fallback: 'No church selected.'))),
          );
        }

        final repository = StudioRepository(
          firestore: ref.read(firestoreProvider),
          churchId: churchId,
        );

        return DefaultTabController(
          length: 8,
          child: Scaffold(
            appBar: AppBar(
              title: Text(ref.t('studio.title', fallback: 'Studio')),
              bottom: TabBar(
                isScrollable: true,
                tabs: [
                  Tab(text: ref.t('studio.tab_events', fallback: 'Events')),
                  Tab(
                      text: ref.t('studio.tab_announcements',
                          fallback: 'Announcements')),
                  Tab(
                      text: ref.t('studio.tab_daily_verse',
                          fallback: 'Daily Verse')),
                  Tab(text: ref.t('studio.tab_articles', fallback: 'Articles')),
                  Tab(text: ref.t('studio.tab_promise', fallback: 'Promise')),
                  Tab(
                      text: ref.t('studio.tab_notifications',
                          fallback: 'Notifications')),
                  Tab(text: ref.t('studio.tab_admins', fallback: 'Admins')),
                  Tab(text: ref.t('studio.tab_prompt', fallback: 'Prompt')),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _CollectionEditor(
                  title: ref.t('studio.tab_events', fallback: 'Events'),
                  stream: repository.watchEvents(),
                  addLabel: ref.t('studio.add_event', fallback: 'Add event'),
                  emptyText:
                      ref.t('studio.no_events', fallback: 'No events yet.'),
                  tileTitle: (data) => (data['title'] ?? '') as String,
                  tileSubtitle: (data) {
                    final parts = <String>[
                      if ((data['type'] ?? '').toString().isNotEmpty)
                        '${ref.t('studio.event_type_prefix', fallback: 'Type')}: ${data['type']}',
                      if ((data['contact'] ?? '').toString().isNotEmpty)
                        '${ref.t('studio.event_contact_prefix', fallback: 'Contact')}: ${data['contact']}',
                      if ((data['location'] ?? '').toString().isNotEmpty)
                        '${ref.t('studio.event_location_prefix', fallback: 'Location')}: ${data['location']}',
                    ];
                    return parts.join('\n');
                  },
                  onAdd: () => _showEventEditor(context, repository),
                  onEdit: (doc) => _showEventEditor(
                    context,
                    repository,
                    doc: doc,
                  ),
                  onDelete: (doc) => repository.deleteEvent(doc.id),
                ),
                _CollectionEditor(
                  title: ref.t('studio.tab_announcements',
                      fallback: 'Announcements'),
                  stream: repository.watchAnnouncements(),
                  addLabel: ref.t('studio.add_announcement',
                      fallback: 'Add announcement'),
                  emptyText: ref.t('studio.no_announcements',
                      fallback: 'No announcements yet.'),
                  tileTitle: (data) => (data['title'] ?? '') as String,
                  tileSubtitle: (data) =>
                      '${ref.t('studio.announcement_priority_prefix', fallback: 'Priority')}: ${data['priority'] ?? 0}\n${data['body'] ?? ''}',
                  onAdd: () => _showAnnouncementEditor(context, repository),
                  onEdit: (doc) => _showAnnouncementEditor(
                    context,
                    repository,
                    doc: doc,
                  ),
                  onDelete: (doc) => repository.deleteAnnouncement(
                    doc.id,
                    imageUrl: (doc.data()['imageUrl'] ?? '') as String,
                  ),
                ),
                _ConfigVerseEditor(
                  title:
                      ref.t('studio.tab_daily_verse', fallback: 'Daily Verse'),
                  configSelector: (config) => config.dailyVerseRef,
                  onSave: ({required book, required chapter, required verse}) {
                    return repository.updateDailyVerse(
                      book: book,
                      chapter: chapter,
                      verse: verse,
                    );
                  },
                ),
                _CollectionEditor(
                  title: ref.t('studio.tab_articles', fallback: 'Articles'),
                  stream: repository.watchArticles(),
                  addLabel:
                      ref.t('studio.add_article', fallback: 'Add article'),
                  emptyText:
                      ref.t('studio.no_articles', fallback: 'No articles yet.'),
                  tileTitle: (data) => (data['title'] ?? '') as String,
                  tileSubtitle: (data) => (data['description'] ?? '') as String,
                  onAdd: () => _showArticleEditor(context, repository),
                  onEdit: (doc) => _showArticleEditor(
                    context,
                    repository,
                    doc: doc,
                  ),
                  onDelete: (doc) => repository.deleteArticle(doc.id),
                ),
                _ConfigVerseEditor(
                  title: ref.t('studio.tab_promise', fallback: 'Promise'),
                  configSelector: (config) => config.promiseVerseRef,
                  onSave: ({required book, required chapter, required verse}) {
                    return repository.updatePromiseWord(
                      book: book,
                      chapter: chapter,
                      verse: verse,
                    );
                  },
                ),
                _NotificationComposer(
                  churchId: churchId,
                  onSend: ({required title, required body, required topic}) {
                    return repository.queueTopicNotification(
                      title: title,
                      body: body,
                      topic: topic,
                    );
                  },
                ),
                _AdminsEditor(
                  onSave: repository.updateAdmins,
                ),
                _PromptSheetEditor(
                  onSave: ({
                    required title,
                    required desc,
                    required enabled,
                  }) {
                    return repository.updatePromptSheet(
                      title: title,
                      desc: desc,
                      enabled: enabled,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CollectionEditor extends StatelessWidget {
  const _CollectionEditor({
    required this.title,
    required this.stream,
    required this.addLabel,
    required this.emptyText,
    required this.tileTitle,
    required this.tileSubtitle,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  final String title;
  final Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> stream;
  final String addLabel;
  final String emptyText;
  final String Function(Map<String, dynamic>) tileTitle;
  final String Function(Map<String, dynamic>) tileSubtitle;
  final Future<void> Function() onAdd;
  final Future<void> Function(QueryDocumentSnapshot<Map<String, dynamic>> doc)
      onEdit;
  final Future<void> Function(QueryDocumentSnapshot<Map<String, dynamic>> doc)
      onDelete;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
                '${context.t('common.error_prefix', fallback: 'Error')}: ${snapshot.error}'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: Text(addLabel),
            ),
            const SizedBox(height: 16),
            if (docs.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 32),
                child: Center(child: Text(emptyText)),
              ),
            ...docs.map((doc) {
              final data = doc.data();
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(tileTitle(data)),
                  subtitle: Text(tileSubtitle(data)),
                  isThreeLine: tileSubtitle(data).contains('\n'),
                  trailing: Wrap(
                    spacing: 8,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => onEdit(doc),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: AppBarTitle(
                                text: context.t('studio.delete_title',
                                    fallback: 'Delete'),
                              ),
                              content: Text(
                                '${context.t('studio.delete_confirm_remove_prefix', fallback: 'Remove')} "${tileTitle(data)}"?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: Text(context.t('settings.cancel',
                                      fallback: 'Cancel')),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: Text(context.t('common.delete',
                                      fallback: 'Delete')),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true) {
                            if (!context.mounted) return;
                            await _runWithBlockingLoader(
                              context,
                              () => onDelete(doc),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

class _ConfigVerseEditor extends ConsumerWidget {
  const _ConfigVerseEditor({
    required this.title,
    required this.configSelector,
    required this.onSave,
  });

  final String title;
  final dynamic Function(AppConfig config) configSelector;
  final Future<void> Function({
    required String book,
    required int chapter,
    required int verse,
  }) onSave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(appConfigProvider);

    return configAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text(
            '${context.t('common.error_prefix', fallback: 'Error')}: $error'),
      ),
      data: (config) {
        final verseRef = configSelector(config);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${verseRef.book}:${verseRef.chapter}:${verseRef.verse}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => _showVerseEditor(
                        context,
                        title: title,
                        initialBook: verseRef.book,
                        initialChapter: verseRef.chapter,
                        initialVerse: verseRef.verse,
                        onSave: onSave,
                      ),
                      icon: const Icon(Icons.edit_outlined),
                      label: Text(
                        '${context.t('studio.edit_item_prefix', fallback: 'Edit')} $title',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _NotificationComposer extends StatefulWidget {
  const _NotificationComposer({
    required this.churchId,
    required this.onSend,
  });

  final String churchId;
  final Future<void> Function({
    required String title,
    required String body,
    required String topic,
  }) onSend;

  @override
  State<_NotificationComposer> createState() => _NotificationComposerState();
}

class _NotificationComposerState extends State<_NotificationComposer> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topic = 'church_${widget.churchId}';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t('studio.notification_title',
                      fallback: 'Church Topic Notification'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                    '${context.t('studio.notification_topic_prefix', fallback: 'Topic')}: $topic'),
                const SizedBox(height: 16),
                TextField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: context.t(
                      'studio.notification_title_label',
                      fallback: 'Notification title',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _bodyController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: context.t(
                      'studio.notification_body_label',
                      fallback: 'Notification body',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isSending
                        ? null
                        : () async {
                            setState(() => _isSending = true);
                            try {
                              await widget.onSend(
                                title: _titleController.text.trim(),
                                body: _bodyController.text.trim(),
                                topic: topic,
                              );
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    context.t(
                                      'studio.notification_queued',
                                      fallback: 'Notification request queued',
                                    ),
                                  ),
                                ),
                              );
                            } finally {
                              if (mounted) {
                                setState(() => _isSending = false);
                              }
                            }
                          },
                    child: _isSending
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            context.t(
                              'studio.notification_send',
                              fallback: 'Send Notification',
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AdminsEditor extends ConsumerWidget {
  const _AdminsEditor({
    required this.onSave,
  });

  final Future<void> Function(List<String> admins) onSave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(appConfigProvider);

    return configAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text(
            '${context.t('common.error_prefix', fallback: 'Error')}: $error'),
      ),
      data: (config) => _AdminsEditorForm(
        initialAdmins: config.admins,
        onSave: onSave,
      ),
    );
  }
}

class _AdminsEditorForm extends StatefulWidget {
  const _AdminsEditorForm({
    required this.initialAdmins,
    required this.onSave,
  });

  final List<String> initialAdmins;
  final Future<void> Function(List<String> admins) onSave;

  @override
  State<_AdminsEditorForm> createState() => _AdminsEditorFormState();
}

class _AdminsEditorFormState extends State<_AdminsEditorForm> {
  late final TextEditingController _controller;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialAdmins.join('\n'),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t('studio.tab_admins', fallback: 'Admins'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  context.t('studio.admins_hint',
                      fallback: 'Enter one admin email per line.'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _controller,
                  maxLines: 10,
                  decoration: InputDecoration(
                    labelText: context.t('studio.admins_label',
                        fallback: 'Admin emails'),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isSaving
                        ? null
                        : () async {
                            setState(() => _isSaving = true);
                            try {
                              final admins = _controller.text
                                  .split('\n')
                                  .map((value) => value.trim())
                                  .where((value) => value.isNotEmpty)
                                  .toList();
                              await widget.onSave(admins);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    context.t('studio.admins_updated',
                                        fallback: 'Admins updated'),
                                  ),
                                ),
                              );
                            } finally {
                              if (mounted) {
                                setState(() => _isSaving = false);
                              }
                            }
                          },
                    child: _isSaving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            context.t('studio.admins_save',
                                fallback: 'Save Admins'),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PromptSheetEditor extends ConsumerWidget {
  const _PromptSheetEditor({
    required this.onSave,
  });

  final Future<void> Function({
    required String title,
    required String desc,
    required bool enabled,
  }) onSave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(appConfigProvider);

    return configAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text(
            '${context.t('common.error_prefix', fallback: 'Error')}: $error'),
      ),
      data: (config) => _PromptSheetEditorForm(
        promptSheet: config.promptSheet,
        onSave: onSave,
      ),
    );
  }
}

class _PromptSheetEditorForm extends StatefulWidget {
  const _PromptSheetEditorForm({
    required this.promptSheet,
    required this.onSave,
  });

  final PromptSheetModel promptSheet;
  final Future<void> Function({
    required String title,
    required String desc,
    required bool enabled,
  }) onSave;

  @override
  State<_PromptSheetEditorForm> createState() => _PromptSheetEditorFormState();
}

class _PromptSheetEditorFormState extends State<_PromptSheetEditorForm> {
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  late bool _enabled;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.promptSheet.title);
    _descController = TextEditingController(text: widget.promptSheet.desc);
    _enabled = widget.promptSheet.enabled;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t('studio.prompt_title', fallback: 'Important'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  context.t(
                    'studio.prompt_description',
                    fallback:
                        'This controls the important pop-up card shown to members for urgent announcements or special updates.',
                  ),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: context.t('common.title', fallback: 'Title'),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: context.t('common.description',
                        fallback: 'Description'),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.t('common.enabled', fallback: 'Enabled')),
                  value: _enabled,
                  onChanged: (value) => setState(() => _enabled = value),
                ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isSaving
                        ? null
                        : () async {
                            setState(() => _isSaving = true);
                            try {
                              await widget.onSave(
                                title: _titleController.text.trim(),
                                desc: _descController.text.trim(),
                                enabled: _enabled,
                              );
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    context.t(
                                      'studio.prompt_updated',
                                      fallback: 'Important updated',
                                    ),
                                  ),
                                ),
                              );
                            } finally {
                              if (mounted) {
                                setState(() => _isSaving = false);
                              }
                            }
                          },
                    child: _isSaving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            context.t(
                              'studio.prompt_save',
                              fallback: 'Save Important',
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

Future<void> _showEventEditor(
  BuildContext context,
  StudioRepository repository, {
  QueryDocumentSnapshot<Map<String, dynamic>>? doc,
}) {
  final data = doc?.data() ?? <String, dynamic>{};
  final titleController =
      TextEditingController(text: (data['title'] ?? '') as String);
  final descriptionController =
      TextEditingController(text: (data['description'] ?? '') as String);
  final contactController =
      TextEditingController(text: (data['contact'] ?? '') as String);
  final locationController =
      TextEditingController(text: (data['location'] ?? '') as String);
  final timingController =
      TextEditingController(text: (data['timing'] ?? '') as String);
  String type = (data['type'] ?? 'family') as String;
  bool isActive = (data['isActive'] ?? true) as bool;
  var isSaving = false;

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.t(
                      doc == null ? 'studio.event_create' : 'studio.event_edit',
                      fallback: doc == null ? 'Create event' : 'Edit event',
                    ),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: context.t('common.title', fallback: 'Title'),
                    ),
                  ),
                  TextField(
                    controller: descriptionController,
                    decoration: InputDecoration(
                      labelText: context.t('common.description',
                          fallback: 'Description'),
                    ),
                    maxLines: 3,
                  ),
                  DropdownButtonFormField<String>(
                    value: type,
                    decoration: InputDecoration(
                      labelText:
                          context.t('studio.event_type', fallback: 'Type'),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'family',
                        child: Text(context.t('studio.event_type_family',
                            fallback: 'family')),
                      ),
                      DropdownMenuItem(
                        value: 'kids',
                        child: Text(context.t('studio.event_type_kids',
                            fallback: 'kids')),
                      ),
                      DropdownMenuItem(
                        value: 'youth',
                        child: Text(context.t('studio.event_type_youth',
                            fallback: 'youth')),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => type = value);
                      }
                    },
                  ),
                  TextField(
                    controller: contactController,
                    decoration: InputDecoration(
                      labelText: context.t('studio.event_contact',
                          fallback: 'Contact'),
                    ),
                  ),
                  TextField(
                    controller: locationController,
                    decoration: InputDecoration(
                      labelText: context.t('studio.event_location',
                          fallback: 'Location'),
                    ),
                  ),
                  TextField(
                    controller: timingController,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText:
                          context.t('studio.event_timing', fallback: 'Timing'),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (timingController.text.trim().isNotEmpty)
                            IconButton(
                              onPressed: isSaving
                                  ? null
                                  : () {
                                      setState(() {
                                        timingController.clear();
                                      });
                                    },
                              icon: const Icon(Icons.clear),
                            ),
                          IconButton(
                            onPressed: isSaving
                                ? null
                                : () async {
                                    final now = DateTime.now();
                                    final pickedDate = await showDatePicker(
                                      context: context,
                                      initialDate: now,
                                      firstDate: DateTime(now.year - 1),
                                      lastDate: DateTime(now.year + 10),
                                    );
                                    if (pickedDate == null ||
                                        !context.mounted) {
                                      return;
                                    }

                                    final pickedTime = await showTimePicker(
                                      context: context,
                                      initialTime: TimeOfDay.fromDateTime(now),
                                    );

                                    var formatted =
                                        _formatHumanReadableDate(pickedDate);
                                    if (pickedTime != null) {
                                      final dateTime = DateTime(
                                        pickedDate.year,
                                        pickedDate.month,
                                        pickedDate.day,
                                        pickedTime.hour,
                                        pickedTime.minute,
                                      );
                                      formatted =
                                          '$formatted, ${DateFormat('h:mm a').format(dateTime)}';
                                    }

                                    if (!context.mounted) return;
                                    setState(() {
                                      timingController.text = formatted;
                                    });
                                  },
                            icon: const Icon(Icons.event_outlined),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(context.t('common.active', fallback: 'Active')),
                    value: isActive,
                    onChanged: (value) => setState(() => isActive = value),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            setState(() => isSaving = true);
                            try {
                              final payload = {
                                'title': titleController.text.trim(),
                                'description':
                                    descriptionController.text.trim(),
                                'type': type,
                                'contact': contactController.text.trim(),
                                'location': locationController.text.trim(),
                                'timing': timingController.text.trim(),
                                'isActive': isActive,
                              };
                              if (doc == null) {
                                await repository.createEvent(payload);
                              } else {
                                await repository.updateEvent(doc.id, payload);
                              }
                              if (context.mounted) Navigator.pop(context);
                            } finally {
                              if (context.mounted) {
                                setState(() => isSaving = false);
                              }
                            }
                          },
                    child: isSaving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            context.t(
                              doc == null ? 'common.create' : 'common.save',
                              fallback: doc == null ? 'Create' : 'Save',
                            ),
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

Future<void> _showAnnouncementEditor(
  BuildContext context,
  StudioRepository repository, {
  QueryDocumentSnapshot<Map<String, dynamic>>? doc,
}) {
  final data = doc?.data() ?? <String, dynamic>{};
  final titleController =
      TextEditingController(text: (data['title'] ?? '') as String);
  final bodyController =
      TextEditingController(text: (data['body'] ?? '') as String);
  final priorityController =
      TextEditingController(text: '${(data['priority'] ?? 0) as int}');
  final existingImageUrl = (data['imageUrl'] ?? '') as String;
  PickedImageData? selectedImage;
  bool isActive = (data['isActive'] ?? true) as bool;
  var isSaving = false;

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return FractionallySizedBox(
        heightFactor: 0.95,
        child: StatefulBuilder(builder: (context, setState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.max,
                children: [
                  Row(
                    children: [
                      Text(
                        context.t(
                          doc == null
                              ? 'studio.announcement_create'
                              : 'studio.announcement_edit',
                          fallback: doc == null
                              ? 'Create announcement'
                              : 'Edit announcement',
                        ),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Spacer(),
                      OutlinedButton(
                        onPressed:
                            isSaving ? null : () => Navigator.of(context).pop(),
                        child: Text(
                            context.t('settings.cancel', fallback: 'Cancel')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: context.t('common.title', fallback: 'Title'),
                    ),
                  ),
                  TextField(
                    controller: bodyController,
                    decoration: InputDecoration(
                      labelText: context.t('studio.announcement_body',
                          fallback: 'Body'),
                    ),
                    maxLines: 4,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picker = ImagePicker();
                      final picked = await picker.pickImage(
                        source: ImageSource.gallery,
                        imageQuality: 85,
                      );
                      if (picked != null) {
                        final imageData =
                            await PickedImageData.fromXFile(picked);
                        if (imageData == null) return;
                        setState(() {
                          selectedImage = imageData;
                        });
                      }
                    },
                    icon: const Icon(Icons.image_outlined),
                    label: Text(
                      selectedImage == null
                          ? (existingImageUrl.isEmpty
                              ? context.t(
                                  'studio.announcement_upload_image',
                                  fallback: 'Upload image',
                                )
                              : context.t(
                                  'studio.announcement_replace_image',
                                  fallback: 'Replace image',
                                ))
                          : context.t(
                              'studio.announcement_change_image',
                              fallback: 'Change image',
                            ),
                    ),
                  ),
                  if (selectedImage != null) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(maxHeight: 280),
                        color: Colors.black12,
                        child: Image.memory(
                          selectedImage!.bytes,
                          width: double.infinity,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ] else if (existingImageUrl.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(maxHeight: 280),
                        color: Colors.black12,
                        child: Image.network(
                          existingImageUrl,
                          width: double.infinity,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ],
                  TextField(
                    controller: priorityController,
                    decoration: InputDecoration(
                      labelText: context.t('studio.priority_label',
                          fallback: 'Priority'),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(context.t('common.active', fallback: 'Active')),
                    value: isActive,
                    onChanged: (value) => setState(() => isActive = value),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: isSaving
                          ? null
                          : () async {
                              setState(() => isSaving = true);
                              try {
                                final payload = {
                                  'title': titleController.text.trim(),
                                  'body': bodyController.text.trim(),
                                  'priority': int.tryParse(
                                          priorityController.text.trim()) ??
                                      0,
                                  'isActive': isActive,
                                };
                                if (doc == null) {
                                  await repository.createAnnouncement(
                                    data: payload,
                                    imageFile: selectedImage,
                                  );
                                } else {
                                  await repository.updateAnnouncement(
                                    id: doc.id,
                                    data: payload,
                                    imageFile: selectedImage,
                                    existingImageUrl: existingImageUrl,
                                  );
                                }
                                if (context.mounted) Navigator.pop(context);
                              } catch (error) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(error.toString())),
                                );
                              } finally {
                                if (context.mounted) {
                                  setState(() => isSaving = false);
                                }
                              }
                            },
                      child: isSaving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              context.t(
                                doc == null ? 'common.create' : 'common.save',
                                fallback: doc == null ? 'Create' : 'Save',
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      );
    },
  );
}

Future<void> _showArticleEditor(
  BuildContext context,
  StudioRepository repository, {
  QueryDocumentSnapshot<Map<String, dynamic>>? doc,
}) {
  final data = doc?.data() ?? <String, dynamic>{};
  final titleController =
      TextEditingController(text: (data['title'] ?? '') as String);
  final descriptionController =
      TextEditingController(text: (data['description'] ?? '') as String);
  final contentController =
      TextEditingController(text: (data['content'] ?? '') as String);
  var isSaving = false;

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.t(
                      doc == null
                          ? 'studio.article_create'
                          : 'studio.article_edit',
                      fallback: doc == null ? 'Create article' : 'Edit article',
                    ),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: context.t('common.title', fallback: 'Title'),
                    ),
                  ),
                  TextField(
                    controller: descriptionController,
                    decoration: InputDecoration(
                      labelText: context.t('common.description',
                          fallback: 'Description'),
                    ),
                    maxLines: 3,
                  ),
                  TextField(
                    controller: contentController,
                    decoration: InputDecoration(
                      labelText:
                          context.t('common.content', fallback: 'Content'),
                    ),
                    maxLines: 8,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            setState(() => isSaving = true);
                            try {
                              final payload = {
                                'title': titleController.text.trim(),
                                'description':
                                    descriptionController.text.trim(),
                                'content': contentController.text.trim(),
                              };
                              if (doc == null) {
                                await repository.createArticle(payload);
                              } else {
                                await repository.updateArticle(doc.id, payload);
                              }
                              if (context.mounted) Navigator.pop(context);
                            } finally {
                              if (context.mounted) {
                                setState(() => isSaving = false);
                              }
                            }
                          },
                    child: isSaving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            context.t(
                              doc == null ? 'common.create' : 'common.save',
                              fallback: doc == null ? 'Create' : 'Save',
                            ),
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

Future<void> _showVerseEditor(
  BuildContext context, {
  required String title,
  required String initialBook,
  required int initialChapter,
  required int initialVerse,
  required Future<void> Function({
    required String book,
    required int chapter,
    required int verse,
  }) onSave,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _VerseEditorSheet(
      title: title,
      initialBook: initialBook,
      initialChapter: initialChapter,
      initialVerse: initialVerse,
      onSave: onSave,
    ),
  );
}

class _VerseEditorSheet extends StatefulWidget {
  const _VerseEditorSheet({
    required this.title,
    required this.initialBook,
    required this.initialChapter,
    required this.initialVerse,
    required this.onSave,
  });

  final String title;
  final String initialBook;
  final int initialChapter;
  final int initialVerse;
  final Future<void> Function({
    required String book,
    required int chapter,
    required int verse,
  }) onSave;

  @override
  State<_VerseEditorSheet> createState() => _VerseEditorSheetState();
}

class _VerseEditorSheetState extends State<_VerseEditorSheet> {
  final BibleRepository _bibleRepository = BibleRepository();

  late BibleBook _selectedBook;
  late int _selectedChapter;
  late int _selectedVerse;
  int _chapterCount = 1;
  int _verseCount = 1;
  bool _isLoadingStructure = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedBook = bibleBooks.firstWhere(
      (book) => book.key == widget.initialBook,
      orElse: () => bibleBooks.first,
    );
    _selectedChapter = widget.initialChapter;
    _selectedVerse = widget.initialVerse;
    _loadStructure();
  }

  Future<void> _loadStructure() async {
    setState(() {
      _isLoadingStructure = true;
    });

    final data = await _bibleRepository.loadBook(_selectedBook.key);
    final chapters = (data['chapters'] as List<dynamic>? ?? const []).toList();
    final safeChapterCount = chapters.isEmpty ? 1 : chapters.length;
    final safeChapter = _selectedChapter.clamp(1, safeChapterCount);
    final verses =
        (chapters[safeChapter - 1]['verses'] as List<dynamic>? ?? const [])
            .toList();
    final safeVerseCount = verses.isEmpty ? 1 : verses.length;
    final safeVerse = _selectedVerse.clamp(1, safeVerseCount);

    if (!mounted) return;
    setState(() {
      _chapterCount = safeChapterCount;
      _verseCount = safeVerseCount;
      _selectedChapter = safeChapter;
      _selectedVerse = safeVerse;
      _isLoadingStructure = false;
    });
  }

  Future<void> _reloadVerseCount() async {
    setState(() {
      _isLoadingStructure = true;
    });

    final data = await _bibleRepository.loadBook(_selectedBook.key);
    final chapters = (data['chapters'] as List<dynamic>? ?? const []).toList();
    final safeChapterCount = chapters.isEmpty ? 1 : chapters.length;
    final safeChapter = _selectedChapter.clamp(1, safeChapterCount);
    final verses =
        (chapters[safeChapter - 1]['verses'] as List<dynamic>? ?? const [])
            .toList();
    final safeVerseCount = verses.isEmpty ? 1 : verses.length;
    final safeVerse = _selectedVerse.clamp(1, safeVerseCount);

    if (!mounted) return;
    setState(() {
      _chapterCount = safeChapterCount;
      _verseCount = safeVerseCount;
      _selectedChapter = safeChapter;
      _selectedVerse = safeVerse;
      _isLoadingStructure = false;
    });
  }

  Future<void> _pickBook() async {
    final pickedBook = await showModalBottomSheet<BibleBook>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: bibleBooks.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final book = bibleBooks[index];
              return ListTile(
                title: Text(book.key),
                subtitle: Text(book.name),
                trailing: book.key == _selectedBook.key
                    ? Icon(
                        Icons.check_circle,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                onTap: () => Navigator.of(context).pop(book),
              );
            },
          ),
        );
      },
    );

    if (pickedBook == null || pickedBook.key == _selectedBook.key) return;

    setState(() {
      _selectedBook = pickedBook;
      _selectedChapter = 1;
      _selectedVerse = 1;
    });
    await _loadStructure();
  }

  Future<void> _pickChapter() async {
    if (_isLoadingStructure) return;

    final pickedChapter = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: _chapterCount,
            itemBuilder: (context, index) {
              final chapter = index + 1;
              return ListTile(
                title: Text('Chapter $chapter'),
                trailing: chapter == _selectedChapter
                    ? Icon(
                        Icons.check_circle,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                onTap: () => Navigator.of(context).pop(chapter),
              );
            },
          ),
        );
      },
    );

    if (pickedChapter == null || pickedChapter == _selectedChapter) return;

    setState(() {
      _selectedChapter = pickedChapter;
      _selectedVerse = 1;
    });
    await _reloadVerseCount();
  }

  Future<void> _pickVerse() async {
    if (_isLoadingStructure) return;

    final pickedVerse = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: _verseCount,
            itemBuilder: (context, index) {
              final verse = index + 1;
              return ListTile(
                title: Text('Verse $verse'),
                trailing: verse == _selectedVerse
                    ? Icon(
                        Icons.check_circle,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                onTap: () => Navigator.of(context).pop(verse),
              );
            },
          ),
        );
      },
    );

    if (pickedVerse == null) return;

    setState(() {
      _selectedVerse = pickedVerse;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${context.t('studio.edit_item_prefix', fallback: 'Edit')} ${widget.title}',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Choose a book, chapter, and verse from the Bible list.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selected Reference',
                      style: theme.textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_selectedBook.key}:$_selectedChapter:$_selectedVerse',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _selectedBook.name,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _VersePickerTile(
                label: context.t('studio.verse_book', fallback: 'Book'),
                value: _selectedBook.key,
                subtitle: _selectedBook.name,
                onTap: _pickBook,
              ),
              const SizedBox(height: 12),
              _VersePickerTile(
                label: context.t('studio.verse_chapter', fallback: 'Chapter'),
                value: '$_selectedChapter',
                subtitle: _isLoadingStructure
                    ? 'Loading chapters...'
                    : '$_chapterCount chapters available',
                onTap: _pickChapter,
              ),
              const SizedBox(height: 12),
              _VersePickerTile(
                label: context.t('studio.verse_verse', fallback: 'Verse'),
                value: '$_selectedVerse',
                subtitle: _isLoadingStructure
                    ? 'Loading verses...'
                    : '$_verseCount verses available',
                onTap: _pickVerse,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSaving || _isLoadingStructure
                      ? null
                      : () async {
                          setState(() => _isSaving = true);
                          try {
                            await widget.onSave(
                              book: _selectedBook.key,
                              chapter: _selectedChapter,
                              verse: _selectedVerse,
                            );
                            if (context.mounted) Navigator.pop(context);
                          } finally {
                            if (mounted) {
                              setState(() => _isSaving = false);
                            }
                          }
                        },
                  child: _isSaving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(context.t('common.save', fallback: 'Save')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VersePickerTile extends StatelessWidget {
  const _VersePickerTile({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.onTap,
  });

  final String label;
  final String value;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      value,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _runWithBlockingLoader(
  BuildContext context,
  Future<void> Function() action,
) async {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(
      child: CircularProgressIndicator(),
    ),
  );

  try {
    await action();
  } finally {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }
}

String _formatHumanReadableDate(DateTime date) {
  final day = date.day;
  final suffix = switch (day) {
    1 || 21 || 31 => 'st',
    2 || 22 => 'nd',
    3 || 23 => 'rd',
    _ => 'th',
  };

  return '$day$suffix ${DateFormat('MMMM yyyy').format(date)}';
}
