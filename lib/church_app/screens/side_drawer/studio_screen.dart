import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/models/app_config_model.dart';
import 'package:flutter_application/church_app/providers/app_config_provider.dart';
import 'package:flutter_application/church_app/providers/authentication/admin_provider.dart';
import 'package:flutter_application/church_app/providers/church_provider.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_provider.dart';
import 'package:flutter_application/church_app/services/studio/studio_repository.dart';
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
        appBar: AppBar(title: const Text('Studio')),
        body: const Center(
          child: Text('Studio is available only for admins.'),
        ),
      );
    }

    return churchIdAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('Studio')),
        body: Center(child: Text('Error: $error')),
      ),
      data: (churchId) {
        if (churchId == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Studio')),
            body: const Center(child: Text('No church selected.')),
          );
        }

        final repository = StudioRepository(
          firestore: ref.read(firestoreProvider),
          churchId: churchId,
        );

        return DefaultTabController(
          length: 5,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Studio'),
              bottom: const TabBar(
                isScrollable: true,
                tabs: [
                  Tab(text: 'Events'),
                  Tab(text: 'Announcements'),
                  Tab(text: 'Daily Verse'),
                  Tab(text: 'Articles'),
                  Tab(text: 'Promise'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _CollectionEditor(
                  title: 'Events',
                  stream: repository.watchEvents(),
                  addLabel: 'Add event',
                  emptyText: 'No events yet.',
                  tileTitle: (data) => (data['title'] ?? '') as String,
                  tileSubtitle: (data) {
                    final parts = <String>[
                      if ((data['type'] ?? '').toString().isNotEmpty)
                        'Type: ${data['type']}',
                      if ((data['contact'] ?? '').toString().isNotEmpty)
                        'Contact: ${data['contact']}',
                      if ((data['location'] ?? '').toString().isNotEmpty)
                        'Location: ${data['location']}',
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
                  title: 'Announcements',
                  stream: repository.watchAnnouncements(),
                  addLabel: 'Add announcement',
                  emptyText: 'No announcements yet.',
                  tileTitle: (data) => (data['title'] ?? '') as String,
                  tileSubtitle: (data) =>
                      'Priority: ${data['priority'] ?? 0}\n${data['body'] ?? ''}',
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
                  title: 'Daily Verse',
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
                  title: 'Daily Articles',
                  stream: repository.watchArticles(),
                  addLabel: 'Add article',
                  emptyText: 'No articles yet.',
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
                  title: 'Promise Word',
                  configSelector: (config) => config.promiseVerseRef,
                  onSave: ({required book, required chapter, required verse}) {
                    return repository.updatePromiseWord(
                      book: book,
                      chapter: chapter,
                      verse: verse,
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
  final Future<void> Function(QueryDocumentSnapshot<Map<String, dynamic>> doc) onEdit;
  final Future<void> Function(QueryDocumentSnapshot<Map<String, dynamic>> doc) onDelete;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
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
                              title: const Text('Delete item?'),
                              content: Text('Remove "${tileTitle(data)}"?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Delete'),
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
      error: (error, _) => Center(child: Text('Error: $error')),
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
                      '${verseRef.book} ${verseRef.chapter}:${verseRef.verse}',
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
                      label: Text('Edit $title'),
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

Future<void> _showEventEditor(
  BuildContext context,
  StudioRepository repository, {
  QueryDocumentSnapshot<Map<String, dynamic>>? doc,
}) {
  final data = doc?.data() ?? <String, dynamic>{};
  final titleController = TextEditingController(text: (data['title'] ?? '') as String);
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
                    doc == null ? 'Create event' : 'Edit event',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Title')),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(labelText: 'Description'),
                    maxLines: 3,
                  ),
                  DropdownButtonFormField<String>(
                    value: type,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: const [
                      DropdownMenuItem(value: 'family', child: Text('family')),
                      DropdownMenuItem(value: 'kids', child: Text('kids')),
                      DropdownMenuItem(value: 'youth', child: Text('youth')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => type = value);
                      }
                    },
                  ),
                  TextField(controller: contactController, decoration: const InputDecoration(labelText: 'Contact')),
                  TextField(controller: locationController, decoration: const InputDecoration(labelText: 'Location')),
                  TextField(
                    controller: timingController,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Timing',
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
                                    if (pickedDate == null || !context.mounted) {
                                      return;
                                    }

                                    final pickedTime = await showTimePicker(
                                      context: context,
                                      initialTime: TimeOfDay.fromDateTime(now),
                                    );

                                    var formatted = _formatHumanReadableDate(pickedDate);
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
                    title: const Text('Active'),
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
                        'description': descriptionController.text.trim(),
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
                        : Text(doc == null ? 'Create' : 'Save'),
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
  final titleController = TextEditingController(text: (data['title'] ?? '') as String);
  final bodyController = TextEditingController(text: (data['body'] ?? '') as String);
  final priorityController =
      TextEditingController(text: '${(data['priority'] ?? 0) as int}');
  final existingImageUrl = (data['imageUrl'] ?? '') as String;
  File? selectedImage;
  bool isActive = (data['isActive'] ?? true) as bool;
  var isSaving = false;

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return FractionallySizedBox(
        heightFactor: 0.95,
        child: StatefulBuilder(
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
                mainAxisSize: MainAxisSize.max,
                children: [
                  Row(
                    children: [
                      Text(
                        doc == null ? 'Create announcement' : 'Edit announcement',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Spacer(),
                      OutlinedButton(
                        onPressed: isSaving ? null : () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Title')),
                  TextField(
                    controller: bodyController,
                    decoration: const InputDecoration(labelText: 'Body'),
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
                        setState(() {
                          selectedImage = File(picked.path);
                        });
                      }
                    },
                    icon: const Icon(Icons.image_outlined),
                    label: Text(
                      selectedImage == null
                          ? (existingImageUrl.isEmpty ? 'Upload image' : 'Replace image')
                          : 'Change image',
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
                        child: Image.file(
                          selectedImage!,
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
                    decoration: const InputDecoration(labelText: 'Priority'),
                    keyboardType: TextInputType.number,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Active'),
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
                          'priority': int.tryParse(priorityController.text.trim()) ?? 0,
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
                          : Text(doc == null ? 'Create' : 'Save'),
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
  final titleController = TextEditingController(text: (data['title'] ?? '') as String);
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
                    doc == null ? 'Create article' : 'Edit article',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Title')),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(labelText: 'Description'),
                    maxLines: 3,
                  ),
                  TextField(
                    controller: contentController,
                    decoration: const InputDecoration(labelText: 'Content'),
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
                    'description': descriptionController.text.trim(),
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
                        : Text(doc == null ? 'Create' : 'Save'),
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
  final bookController = TextEditingController(text: initialBook);
  final chapterController = TextEditingController(text: '$initialChapter');
  final verseController = TextEditingController(text: '$initialVerse');
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
                    'Edit $title',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  TextField(controller: bookController, decoration: const InputDecoration(labelText: 'Book')),
                  TextField(
                    controller: chapterController,
                    decoration: const InputDecoration(labelText: 'Chapter'),
                    keyboardType: TextInputType.number,
                  ),
                  TextField(
                    controller: verseController,
                    decoration: const InputDecoration(labelText: 'Verse'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            setState(() => isSaving = true);
                            try {
                  await onSave(
                    book: bookController.text.trim(),
                    chapter: int.tryParse(chapterController.text.trim()) ?? 1,
                    verse: int.tryParse(verseController.text.trim()) ?? 1,
                  );
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
                        : const Text('Save'),
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
