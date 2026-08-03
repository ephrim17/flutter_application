import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/helpers/church_group_definitions.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';
import 'package:flutter_application/church_app/services/faith_engagement_repository.dart';
import 'package:flutter_application/church_app/widgets/app_loading_indicator.dart';
import 'package:flutter_application/church_app/widgets/app_modal_bottom_sheet.dart';
import 'package:flutter_application/church_app/widgets/app_popup_menu.dart';
import 'package:flutter_application/church_app/widgets/app_text_field.dart';
import 'package:flutter_application/church_app/widgets/bible_verse_picker_sheet.dart';
import 'package:intl/intl.dart';

enum _FaithContentType { circle, reflection }

class FaithEngagementStudioScreen extends StatelessWidget {
  const FaithEngagementStudioScreen({
    super.key,
    required this.repository,
  });

  final FaithEngagementRepository repository;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: TabBar(
              isScrollable: true,
              tabs: [
                Tab(text: context.t('faith.circles_studio_tab')),
                Tab(text: context.t('faith.studio_daily')),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _FaithContentList(
                  type: _FaithContentType.circle,
                  stream: repository.watchAdminCircles(),
                  repository: repository,
                ),
                _FaithContentList(
                  type: _FaithContentType.reflection,
                  stream: repository.watchAdminReflections(),
                  repository: repository,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FaithContentList extends StatelessWidget {
  const _FaithContentList({
    required this.type,
    required this.stream,
    required this.repository,
  });

  final _FaithContentType type;
  final Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> stream;
  final FaithEngagementRepository repository;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: AppLoadingIndicator());
        }
        final items = snapshot.data ?? const [];
        return Stack(
          children: [
            if (items.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_iconFor(type), size: 52),
                      const SizedBox(height: 14),
                      Text(
                        context.t(_emptyKeyFor(type)),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final doc = items[index];
                  final data = doc.data();
                  return Container(
                    decoration: carouselBoxDecoration(context),
                    child: ListTile(
                      leading: CircleAvatar(child: Icon(_iconFor(type))),
                      title: Text(
                        (data['title'] ?? '').toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        _subtitleFor(type, data, context),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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
                        onSelected: (value) {
                          if (value == 'edit') {
                            _showEditor(context, doc: doc);
                          } else {
                            _confirmDelete(context, doc.id);
                          }
                        },
                      ),
                      onTap: () => _showEditor(context, doc: doc),
                    ),
                  );
                },
              ),
            Positioned(
              right: 18,
              bottom: 18,
              child: FloatingActionButton.extended(
                heroTag: 'faith-studio-${type.name}',
                onPressed: () => _showEditor(context),
                icon: const Icon(Icons.add_rounded),
                label: Text(context.t('common.create')),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showEditor(
    BuildContext context, {
    QueryDocumentSnapshot<Map<String, dynamic>>? doc,
  }) async {
    await showAppModalBottomSheet<void>(
      context: context,
      heightFactor: 0.92,
      builder: (_) => _FaithContentEditor(
        type: type,
        repository: repository,
        doc: doc,
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, String id) async {
    final messenger = ScaffoldMessenger.of(context);
    final failureMessage = context.t('faith.delete_failed');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.t('faith.delete_title')),
        content: Text(context.t('faith.delete_message')),
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
    if (confirmed != true) return;
    try {
      switch (type) {
        case _FaithContentType.circle:
          await repository.deleteCircle(id);
        case _FaithContentType.reflection:
          await repository.deleteReflection(id);
      }
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(failureMessage)));
    }
  }
}

class _FaithContentEditor extends StatefulWidget {
  const _FaithContentEditor({
    required this.type,
    required this.repository,
    this.doc,
  });

  final _FaithContentType type;
  final FaithEngagementRepository repository;
  final QueryDocumentSnapshot<Map<String, dynamic>>? doc;

  @override
  State<_FaithContentEditor> createState() => _FaithContentEditorState();
}

class _FaithContentEditorState extends State<_FaithContentEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _prayerPoints;
  late final TextEditingController _liveItOut;
  String _scriptureBook = '';
  int _scriptureChapter = 1;
  int _scriptureStartVerse = 1;
  int _scriptureEndVerse = 1;
  String _audienceGroupId = '';
  late DateTime _activeDate;
  bool _enabled = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final data = widget.doc?.data() ?? const <String, dynamic>{};
    _title = TextEditingController(text: (data['title'] ?? '').toString());
    _description = TextEditingController(
      text: (data[_descriptionKey] ?? '').toString(),
    );
    final rawPrayerPoints = data['prayerPoints'];
    _prayerPoints = TextEditingController(
      text: rawPrayerPoints is Iterable
          ? rawPrayerPoints.map((item) => item.toString()).join('\n')
          : (rawPrayerPoints ?? '').toString(),
    );
    _liveItOut = TextEditingController(
      text: (data['liveItOut'] ?? '').toString(),
    );
    final legacyScripture = _parseScriptureReference(
      (data['scriptureReference'] ?? '').toString(),
    );
    _scriptureBook = (data['scriptureBook'] ?? '').toString().trim();
    if (_scriptureBook.isEmpty) {
      _scriptureBook = legacyScripture?.book ?? '';
    }
    _scriptureChapter =
        _positiveInt(data['scriptureChapter']) ?? legacyScripture?.chapter ?? 1;
    _scriptureStartVerse = _positiveInt(data['scriptureStartVerse']) ??
        legacyScripture?.startVerse ??
        1;
    _scriptureEndVerse = _positiveInt(data['scriptureEndVerse']) ??
        legacyScripture?.endVerse ??
        _scriptureStartVerse;
    _audienceGroupId = (data['audienceGroupId'] ?? '').toString();
    if (_audienceGroupId.isNotEmpty &&
        !churchGroupDefinitions.any(
          (group) => group.id == _audienceGroupId,
        )) {
      _audienceGroupId = '';
    }
    final now = DateTime.now();
    _activeDate = _readDate(data['activeDate']) ?? now;
    _enabled = data['enabled'] != false;
  }

  String get _descriptionKey =>
      widget.type == _FaithContentType.reflection ? 'body' : 'description';
  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _prayerPoints.dispose();
    _liveItOut.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
          children: [
            Text(
              context.t(_editorTitleKey(widget.type)),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 18),
            AppTextField(
              controller: _title,
              label: context.t('common.title'),
              validator: _requiredValidator,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _description,
              label: context.t(
                widget.type == _FaithContentType.reflection
                    ? 'common.content'
                    : 'common.description',
              ),
              maxLines: 5,
              validator: _requiredValidator,
            ),
            if (widget.type == _FaithContentType.circle) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue:
                    _audienceGroupId.isEmpty ? null : _audienceGroupId,
                decoration: appTextFieldDecoration(
                  context,
                  labelText: context.t('faith.audience_group'),
                ),
                items: [
                  ...churchGroupDefinitions.map(
                    (group) => DropdownMenuItem(
                      value: group.id,
                      child: Text(group.label),
                    ),
                  ),
                ],
                onChanged: (value) =>
                    setState(() => _audienceGroupId = value ?? ''),
                validator: (value) => value == null || value.isEmpty
                    ? context.t('faith.group_required')
                    : null,
              ),
            ],
            if (widget.type == _FaithContentType.reflection) ...[
              const SizedBox(height: 12),
              AppTextField(
                controller: _prayerPoints,
                label: context.t('faith.prayer_points'),
                decoration: appTextFieldDecoration(
                  context,
                  labelText: context.t('faith.prayer_points'),
                  helperText: context.t('faith.prayer_points_helper'),
                ),
                maxLines: 5,
                validator: _requiredValidator,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _liveItOut,
                label: context.t('faith.live_it_out_action'),
                decoration: appTextFieldDecoration(
                  context,
                  labelText: context.t('faith.live_it_out_action'),
                  helperText: context.t('faith.live_it_out_helper'),
                ),
                maxLines: 3,
                validator: _requiredValidator,
              ),
              const SizedBox(height: 12),
              ListTile(
                shape: RoundedRectangleBorder(
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  borderRadius: BorderRadius.circular(22),
                ),
                title: Text(context.t('faith.bible_passage')),
                subtitle: Text(
                  _scriptureBook.isEmpty
                      ? context.t('faith.choose_bible_passage')
                      : _scriptureReference,
                ),
                trailing: const Icon(Icons.menu_book_outlined),
                onTap: _pickScripture,
              ),
              const SizedBox(height: 10),
              _DateTile(
                label: context.t('faith.active_date'),
                date: _activeDate,
                onTap: () =>
                    _pickDate(_activeDate, (value) => _activeDate = value),
              ),
            ],
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              value: _enabled,
              contentPadding: EdgeInsets.zero,
              title: Text(context.t('common.enabled')),
              onChanged: (value) => setState(() => _enabled = value),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(context.t('common.save')),
            ),
          ],
        ),
      ),
    );
  }

  String? _requiredValidator(String? value) =>
      (value ?? '').trim().isEmpty ? context.t('faith.field_required') : null;

  Future<void> _pickDate(
    DateTime initial,
    void Function(DateTime value) assign,
  ) async {
    final value = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (value == null || !mounted) return;
    setState(() => assign(value));
  }

  String get _scriptureReference {
    if (_scriptureBook.isEmpty) return '';
    final verses = _scriptureStartVerse == _scriptureEndVerse
        ? '$_scriptureStartVerse'
        : '$_scriptureStartVerse-$_scriptureEndVerse';
    return '$_scriptureBook $_scriptureChapter:$verses';
  }

  Future<void> _pickScripture() => showBibleVerseRangePickerSheet(
        context,
        title: context.t('faith.bible_passage'),
        initialBook: _scriptureBook,
        initialChapter: _scriptureChapter,
        initialStartVerse: _scriptureStartVerse,
        initialEndVerse: _scriptureEndVerse,
        onSave: ({
          required book,
          required chapter,
          required startVerse,
          required endVerse,
        }) async {
          if (!mounted) return;
          setState(() {
            _scriptureBook = book;
            _scriptureChapter = chapter;
            _scriptureStartVerse = startVerse;
            _scriptureEndVerse = endVerse;
          });
        },
      );

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (widget.type == _FaithContentType.reflection && _scriptureBook.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('faith.choose_passage_required'))),
      );
      return;
    }
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final notificationBody = context.t(_notificationBodyKey(widget.type));
    final notificationFailedMessage = context.t('faith.notification_failed');
    var notificationFailed = false;
    final data = <String, dynamic>{
      'title': _title.text.trim(),
      _descriptionKey: _description.text.trim(),
      'enabled': _enabled,
      if (widget.type == _FaithContentType.circle) ...{
        'audienceGroupId': _audienceGroupId,
        'order': 100,
      },
      if (widget.type == _FaithContentType.reflection) ...{
        'activeDate': Timestamp.fromDate(_activeDate),
        'scriptureBook': _scriptureBook,
        'scriptureChapter': _scriptureChapter,
        'scriptureStartVerse': _scriptureStartVerse,
        'scriptureEndVerse': _scriptureEndVerse,
        'scriptureReference': _scriptureReference,
        'prayerPoints': _prayerPoints.text
            .split('\n')
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList(growable: false),
        'liveItOut': _liveItOut.text.trim(),
      },
    };
    try {
      switch (widget.type) {
        case _FaithContentType.circle:
          await widget.repository.saveCircle(widget.doc?.id, data);
        case _FaithContentType.reflection:
          await widget.repository.saveReflection(widget.doc?.id, data);
      }
      final shouldNotifyChurch = widget.doc == null &&
          _enabled &&
          (widget.type != _FaithContentType.circle || _audienceGroupId.isEmpty);
      if (shouldNotifyChurch) {
        try {
          await widget.repository.queueFaithNotification(
            title: _title.text.trim(),
            body: notificationBody,
            kind: switch (widget.type) {
              _FaithContentType.reflection => 'faith_daily_loop',
              _FaithContentType.circle => 'faith_circles',
            },
          );
        } catch (_) {
          notificationFailed = true;
        }
      }
      if (notificationFailed) {
        messenger.showSnackBar(
          SnackBar(content: Text(notificationFailedMessage)),
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t('faith.save_failed'))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.label,
    required this.date,
    required this.onTap,
  });
  final String label;
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        shape: RoundedRectangleBorder(
          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(22),
        ),
        title: Text(label),
        subtitle: Text(DateFormat.yMMMMd().format(date)),
        trailing: const Icon(Icons.calendar_month_outlined),
        onTap: onTap,
      );
}

DateTime? _readDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

int? _positiveInt(dynamic value) {
  final parsed = value is num
      ? value.toInt()
      : int.tryParse(value?.toString().trim() ?? '');
  return parsed != null && parsed > 0 ? parsed : null;
}

({String book, int chapter, int startVerse, int endVerse})?
    _parseScriptureReference(String value) {
  final match =
      RegExp(r'^(.+?)\s+(\d+):(\d+)(?:-(\d+))?$').firstMatch(value.trim());
  if (match == null) return null;
  final chapter = int.tryParse(match.group(2) ?? '');
  final start = int.tryParse(match.group(3) ?? '');
  final end = int.tryParse(match.group(4) ?? '') ?? start;
  if (chapter == null || start == null || end == null) return null;
  return (
    book: match.group(1)?.trim() ?? '',
    chapter: chapter,
    startVerse: start,
    endVerse: end,
  );
}

IconData _iconFor(_FaithContentType type) => switch (type) {
      _FaithContentType.circle => Icons.groups_2_outlined,
      _FaithContentType.reflection => Icons.bolt_outlined,
    };

String _emptyKeyFor(_FaithContentType type) => switch (type) {
      _FaithContentType.circle => 'faith.circles_empty',
      _FaithContentType.reflection => 'faith.no_reflections',
    };

String _editorTitleKey(_FaithContentType type) => switch (type) {
      _FaithContentType.circle => 'faith.circle_editor_title',
      _FaithContentType.reflection => 'faith.edit_reflection',
    };

String _notificationBodyKey(_FaithContentType type) => switch (type) {
      _FaithContentType.circle => 'faith.circles_notification_body',
      _FaithContentType.reflection => 'faith.reflection_notification_body',
    };

String _subtitleFor(
  _FaithContentType type,
  Map<String, dynamic> data,
  BuildContext context,
) {
  if (type == _FaithContentType.reflection) {
    final date = _readDate(data['activeDate']);
    return date == null
        ? context.t('faith.date_not_set')
        : DateFormat.yMMMd().format(date);
  }
  return (data['description'] ?? '').toString();
}
