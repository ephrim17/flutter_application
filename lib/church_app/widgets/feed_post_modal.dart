import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/models/feed_model.dart';
import 'package:flutter_application/church_app/providers/app_config_provider.dart';
import 'package:flutter_application/church_app/providers/feed_post_modal_provider.dart';
import 'package:flutter_application/church_app/widgets/color_text_widget.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';

class CreatePostModal extends ConsumerStatefulWidget {
  final FeedPost? post;
  final bool? edit; // 👈 if not null → edit mode

  const CreatePostModal({super.key, this.post, this.edit});

  @override
  ConsumerState<CreatePostModal> createState() => _CreatePostModalState();
}

class _CreatePostModalState extends ConsumerState<CreatePostModal> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    selectedImage = null;

    if (widget.post != null) {
      _titleController.text = widget.post!.title;
      _descriptionController.text = widget.post!.description;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    selectedImage = null;
    super.dispose();
  }

  Future<void> _pickImage() async {
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (image != null) {
      setState(() {
        selectedImage = File(image.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(feedPostModalControllerProvider);
    final isEditMode = widget.post != null || widget.edit == true;
    final isCreateMode = widget.post == null;
    final cardtitle = isEditMode
        ? ref.t('feed.edit_title', fallback: 'Edit Post')
        : ref.t('feed.create_title', fallback: 'Create Post');

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              Row(
                children: [
                  Text(
                    cardtitle,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Spacer(),
                  OutlinedButton(
                      onPressed: () => {
                            if (mounted) {Navigator.of(context).pop()}
                          },
                      child: ColorText(
                        badgeText: ref.t('feed.cancel', fallback: 'Cancel'),
                      ))
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _titleController,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: "Title",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                minLines: 3,
                maxLines: null, // 👈 This makes it grow infinitely
                decoration: InputDecoration(
                  labelText: "Description",
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    ),
                  ),
                ),
              ),
              
              Align(
                alignment: Alignment.centerLeft,
                child: isCreateMode
                    ? TextButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.image),
                        label: Text(
                          ref.t(
                            'feed.add_image_optional',
                            fallback: 'Add Image (Optional)',
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 10,),
              if (selectedImage != null && isCreateMode)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      selectedImage!,
                      //height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              const SizedBox(height: 10,),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: state.isLoading
                      ? null
                      : () async {
                          final title = _titleController.text.trim();
                          final description =
                              _descriptionController.text.trim();

                          if (title.isEmpty || description.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  ref.t(
                                    'feed.validation_all_fields_required',
                                    fallback: 'All fields are required',
                                  ),
                                ),
                              ),
                            );
                            return;
                          }

                          final navigator = Navigator.of(context);
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            if (widget.post == null) {
                              /// CREATE
                              await ref
                                  .read(feedPostModalControllerProvider.notifier)
                                  .createPost(
                                    title: title,
                                    description: description,
                                  );
                            } else {
                              /// UPDATE
                              await ref
                                  .read(feedPostModalControllerProvider.notifier)
                                  .updatePost(
                                    postId: widget.post!.id,
                                    title: title,
                                    description: description,
                                    imageFile: selectedImage,
                                    existingImageUrl: widget.post!.imageUrl,
                                  );
                            }

                            navigator.pop();
                          } catch (e) {
                            messenger.showSnackBar(
                              SnackBar(content: Text(e.toString())),
                            );
                          }
                        },
                  child: state.isLoading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          widget.post == null
                              ? ref.t('feed.post_action', fallback: 'Post')
                              : ref.t('feed.update_action', fallback: 'Update'),
                        ),
                ),
              ),
              if (widget.post != null) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    label: Text(
                      ref.t('feed.delete_action', fallback: 'Delete Post'),
                      style: const TextStyle(color: Colors.red),
                    ),
                    onPressed: state.isLoading
                        ? null
                        : () async {
                            final navigator = Navigator.of(context);
                            final messenger = ScaffoldMessenger.of(context);
                            final shouldDelete = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: Text(
                                  ref.t(
                                    'feed.delete_confirm_title',
                                    fallback: 'Delete post?',
                                  ),
                                ),
                                content: Text(
                                  ref.t(
                                    'feed.delete_confirm_message',
                                    fallback:
                                        'This will permanently delete the post and its image.',
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(ctx).pop(false),
                                    child: Text(
                                      ref.t('settings.cancel', fallback: 'Cancel'),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.of(ctx).pop(true),
                                    child: Text(
                                      ref.t('feed.delete_action', fallback: 'Delete Post'),
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
                              ),
                            );

                            if (shouldDelete != true) return;

                            try {
                              await ref
                                  .read(feedPostModalControllerProvider.notifier)
                                  .deletePost(
                                    postId: widget.post!.id,
                                    imageUrl: widget.post!.imageUrl,
                                  );
                              navigator.pop();
                            } catch (e) {
                              messenger.showSnackBar(
                                SnackBar(content: Text(e.toString())),
                              );
                            }
                          },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
