import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/models/app_user_model.dart';
import 'package:flutter_application/church_app/models/picked_image_data.dart';
import 'package:flutter_application/church_app/providers/feed_post_modal_provider.dart';
import 'package:flutter_application/church_app/providers/for_you_sections/bible_swipe_verse_provider.dart';
import 'package:flutter_application/church_app/services/side_drawer/bible_book_repository.dart';
import 'package:flutter_application/church_app/widgets/prompts/birthday_card_widget.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application/church_app/widgets/app_text_field.dart';
import 'package:flutter_application/church_app/widgets/bible_verse_picker_sheet.dart';
import 'package:image_picker/image_picker.dart';

Future<void> showTodayBirthdaysModal(
  BuildContext context, {
  required List<AppUser> members,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.8,
      child: _TodayBirthdaysModal(members: members),
    ),
  );
}

class _TodayBirthdaysModal extends StatelessWidget {
  const _TodayBirthdaysModal({required this.members});

  final List<AppUser> members;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.t('birthday.today_title', fallback: "Today's Birthdays"),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            members.isEmpty
                ? context.t(
                    'birthday.none_subtitle',
                    fallback: 'No members have birthdays today.',
                  )
                : context.t(
                    'birthday.pick_member_subtitle',
                    fallback: 'Choose a member to prepare a birthday post.',
                  ),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: members.isEmpty
                ? Center(
                    child: Text(
                      context.t(
                        'birthday.none_today',
                        fallback: 'No birthdays today',
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: members.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final member = members[index];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              member.name.isNotEmpty
                                  ? member.name[0].toUpperCase()
                                  : '?',
                            ),
                          ),
                          title: Text(member.name),
                          subtitle:
                              Text(_formatBirthdayMoment(context, member.dob)),
                          trailing: FilledButton(
                            onPressed: () {
                              showModalBottomSheet<void>(
                                context: context,
                                isScrollControlled: true,
                                builder: (_) => FractionallySizedBox(
                                  heightFactor: 0.95,
                                  child:
                                      BirthdayPostComposerModal(member: member),
                                ),
                              );
                            },
                            child: Text(
                              context.t('common.send', fallback: 'Send'),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class BirthdayPostComposerModal extends ConsumerStatefulWidget {
  const BirthdayPostComposerModal({
    super.key,
    required this.member,
  });

  final AppUser member;

  @override
  ConsumerState<BirthdayPostComposerModal> createState() =>
      _BirthdayPostComposerModalState();
}

class _BirthdayPostComposerModalState
    extends ConsumerState<BirthdayPostComposerModal> {
  final BibleRepository _bibleRepository = BibleRepository();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final GlobalKey _cardKey = GlobalKey();
  final ImagePicker _imagePicker = ImagePicker();

  Map<String, String>? _selectedVerse;
  PickedImageData? _generatedImage;
  PickedImageData? _selectedBackgroundImage;
  bool _captureQueued = false;

  @override
  void initState() {
    super.initState();
    _titleController.text =
        buildBirthdayPostTitle(widget.member.name, widget.member.dob);
    _descriptionController.text =
        'Wishing ${widget.member.name} a joyful and blessed birthday.';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _pickVerse(List<Map<String, String>> verses) {
    if (_selectedVerse != null || verses.isEmpty) return;
    _selectedVerse = verses[Random().nextInt(verses.length)];
  }

  Future<void> _pickBackgroundImage() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (picked == null) return;

    final imageData = await PickedImageData.fromXFile(picked);
    if (!mounted || imageData == null) return;

    setState(() {
      _selectedBackgroundImage = imageData;
      _generatedImage = null;
      _captureQueued = false;
    });
    _queueCapture();
  }

  Future<void> _changeVerse() async {
    final currentVerse = _selectedVerse;
    final initialBook = currentVerse?['book'] ?? 'John';
    final initialChapter = int.tryParse(currentVerse?['chapter'] ?? '') ?? 3;
    final initialVerse = int.tryParse(currentVerse?['verse'] ?? '') ?? 16;

    await showBibleVersePickerSheet(
      context,
      title: context.t(
        'birthday.change_verse',
        fallback: 'Birthday Verse',
      ),
      initialBook: initialBook,
      initialChapter: initialChapter,
      initialVerse: initialVerse,
      onSave: ({
        required String book,
        required int chapter,
        required int verse,
      }) async {
        final verseData = await _bibleRepository.getVerse(
          book: book,
          chapter: chapter,
          verse: verse,
        );

        if (!mounted) return;
        setState(() {
          _selectedVerse = {
            'book': book,
            'chapter': '$chapter',
            'verse': '$verse',
            'tamil': verseData['tamil'] ?? verseData['text'] ?? '',
            'english': verseData['english'] ?? '',
            'reference': '$book $chapter:$verse',
          };
          _generatedImage = null;
          _captureQueued = false;
        });
        _queueCapture();
      },
    );
  }

  void _queueCapture() {
    if (_captureQueued || _selectedVerse == null || _generatedImage != null) {
      return;
    }

    _captureQueued = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final bytes = await captureBoundaryPng(_cardKey);
      if (!mounted) return;

      if (bytes != null) {
        setState(() {
          _generatedImage = PickedImageData(
            bytes: bytes,
            name: 'birthday-${widget.member.uid}.png',
          );
        });
      }

      _captureQueued = false;
    });
  }

  Future<void> _submitPost() async {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    if (title.isEmpty || description.isEmpty) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            context.t(
              'birthday.title_required',
              fallback: 'Title and description are required',
            ),
          ),
        ),
      );
      return;
    }

    if (_generatedImage == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            context.t(
              'birthday.image_pending',
              fallback: 'Birthday image is still being prepared',
            ),
          ),
        ),
      );
      return;
    }

    try {
      await ref.read(feedPostModalControllerProvider.notifier).createPost(
            title: title,
            description: description,
            imageFile: _generatedImage,
          );

      if (!mounted) return;
      navigator.pop();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(feedPostModalControllerProvider);
    final swipeVersesAsync = ref.watch(swipeVersesProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  context.t('birthday.post_title', fallback: 'Birthday Post'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                TextButton(
                  onPressed: state.isLoading
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: Text(
                    context.t('birthday.close', fallback: 'Close'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _titleController,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: context.t(
                  'birthday.title_label',
                  fallback: 'Title',
                ),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _descriptionController,
              minLines: 3,
              maxLines: null,
              decoration: InputDecoration(
                labelText: context.t(
                  'birthday.description_label',
                  fallback: 'Description',
                ),
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            swipeVersesAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  '${context.t('birthday.verse_load_error', fallback: 'Unable to load birthday verse:')} $error',
                ),
              ),
              data: (verses) {
                _pickVerse(verses);
                _queueCapture();

                if (_selectedVerse == null) {
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      context.t(
                        'birthday.no_verse_available',
                        fallback:
                            'No verse available for birthday posts right now.',
                      ),
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          _selectedVerse?['reference'] ?? '',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        OutlinedButton.icon(
                          onPressed: _changeVerse,
                          icon: const Icon(Icons.edit_outlined),
                          label: Text(
                            context.t(
                              'birthday.change_verse',
                              fallback: 'Change verse',
                            ),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _pickBackgroundImage,
                          icon: const Icon(Icons.image_outlined),
                          label: Text(
                            _selectedBackgroundImage == null
                                ? context.t(
                                    'birthday.choose_image',
                                    fallback: 'Choose image',
                                  )
                                : context.t(
                                    'birthday.change_image',
                                    fallback: 'Change image',
                                  ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    RepaintBoundary(
                      key: _cardKey,
                      child: BirthdayBlessingCard(
                        userName: widget.member.name,
                        verse: _selectedVerse!,
                        backgroundImageBytes: _selectedBackgroundImage?.bytes,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: state.isLoading ? null : _submitPost,
                child: state.isLoading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        context.t(
                          'birthday.post_wish',
                          fallback: 'Post Birthday Wish',
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

bool isBirthdayToday(DateTime? dob) {
  if (dob == null) return false;

  final now = DateTime.now();
  return dob.month == now.month && dob.day == now.day;
}

String _formatDob(BuildContext context, DateTime? dob) {
  if (dob == null) {
    return context.t(
      'birthday.date_unavailable',
      fallback: 'Birthday date unavailable',
    );
  }
  return '${context.t('birthday.date_prefix', fallback: 'Birthday')}: ${dob.day}/${dob.month}';
}

String _formatBirthdayMoment(BuildContext context, DateTime? dob) {
  if (dob == null) {
    return _formatDob(context, dob);
  }

  final now = DateTime.now();
  final turningAge = now.year - dob.year;

  return '${context.t('birthday.turning_prefix', fallback: 'Turning')} $turningAge';
}
