import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/models/app_user_model.dart';
import 'package:flutter_application/church_app/models/picked_image_data.dart';
import 'package:flutter_application/church_app/providers/feed_post_modal_provider.dart';
import 'package:flutter_application/church_app/providers/for_you_sections/bible_swipe_verse_provider.dart';
import 'package:flutter_application/church_app/widgets/prompts/birthday_card_widget.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
                          subtitle: Text(_formatDob(member.dob)),
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
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final GlobalKey _cardKey = GlobalKey();

  Map<String, String>? _selectedVerse;
  PickedImageData? _generatedImage;
  bool _captureQueued = false;

  @override
  void initState() {
    super.initState();
    _titleController.text = buildBirthdayPostTitle(widget.member.name);
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
        const SnackBar(content: Text('Title and description are required')),
      );
      return;
    }

    if (_generatedImage == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Birthday image is still being prepared')),
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
            TextField(
              controller: _titleController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              minLines: 3,
              maxLines: null,
              decoration: const InputDecoration(
                labelText: 'Description',
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
                    Text(
                      context.t(
                        'birthday.image_preview',
                        fallback: 'Image preview',
                      ),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    RepaintBoundary(
                      key: _cardKey,
                      child: BirthdayBlessingCard(
                        userName: widget.member.name,
                        verse: _selectedVerse!,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _generatedImage == null
                          ? context.t(
                              'birthday.image_preparing',
                              fallback: 'Preparing image...',
                            )
                          : context.t(
                              'birthday.image_ready',
                              fallback: 'Birthday image ready',
                            ),
                      style: Theme.of(context).textTheme.bodySmall,
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

String _formatDob(DateTime? dob) {
  if (dob == null) return 'Birthday date unavailable';
  return 'Birthday: ${dob.day}/${dob.month}';
}
