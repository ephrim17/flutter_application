import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/models/feed_model.dart';
import 'package:flutter_application/church_app/models/picked_image_data.dart';
import 'package:flutter_application/church_app/providers/app_config_provider.dart';
import 'package:flutter_application/church_app/services/analytics/firebase_analytics_helper.dart';
import 'package:flutter_application/church_app/providers/feed_post_modal_provider.dart';
import 'package:flutter_application/church_app/widgets/color_text_widget.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_application/church_app/widgets/app_text_field.dart';

class CreatePostModal extends ConsumerStatefulWidget {
  final FeedPost? post;
  final bool? edit; // 👈 if not null → edit mode
  final String? initialTitle;
  final String? initialDescription;
  final PickedImageData? initialImage;
  final bool requireImage;
  final bool allowImagePicking;
  final bool isGlobal;

  const CreatePostModal({
    super.key,
    this.post,
    this.edit,
    this.initialTitle,
    this.initialDescription,
    this.initialImage,
    this.requireImage = false,
    this.allowImagePicking = true,
    this.isGlobal = false,
  });

  @override
  ConsumerState<CreatePostModal> createState() => _CreatePostModalState();
}

class _CreatePostModalState extends ConsumerState<CreatePostModal> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _sharePersonalDetails = false;
  final List<PickedImageData> _selectedImages = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialImage != null) {
      _selectedImages.add(widget.initialImage!);
    }

    if (widget.post != null) {
      _titleController.text = widget.post!.title;
      _descriptionController.text = widget.post!.description;
      _sharePersonalDetails = widget.post!.sharePersonalDetails;
    } else {
      _titleController.text = widget.initialTitle ?? '';
      _descriptionController.text = widget.initialDescription ?? '';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final images = await picker.pickMultiImage(imageQuality: 80);
    if (images.isEmpty) return;
    final pickedImages = <PickedImageData>[];
    for (final image in images.take(10)) {
      final picked = await PickedImageData.fromXFile(image);
      if (picked != null) pickedImages.add(picked);
    }
    if (!mounted) return;
    setState(() {
      _selectedImages
        ..clear()
        ..addAll(pickedImages);
    });
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
              AppTextField(
                controller: _titleController,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: ref.t('feed.title_label', fallback: 'Title'),
                ),
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _descriptionController,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                minLines: 3,
                maxLines: null, // 👈 This makes it grow infinitely
                decoration: InputDecoration(
                  labelText:
                      ref.t('feed.description_label', fallback: 'Description'),
                  alignLabelWithHint: true,
                ),
              ),
              if (widget.isGlobal) ...[
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _sharePersonalDetails,
                  onChanged: (value) {
                    setState(() {
                      _sharePersonalDetails = value;
                    });
                  },
                  title: Text(
                    ref.t(
                      'feed.global_share_details_title',
                      fallback: 'Share personal details',
                    ),
                  ),
                  subtitle: Text(
                    _sharePersonalDetails
                        ? ref.t(
                            'feed.global_share_details_enabled',
                            fallback:
                                'Name, category, address, DOB, email, and phone will be available from this global post.',
                          )
                        : ref.t(
                            'feed.global_share_details_disabled',
                            fallback:
                                'Only name, church, and church pastor will be shown from this global post.',
                          ),
                  ),
                ),
              ],
              Align(
                alignment: Alignment.centerLeft,
                child: isCreateMode && widget.allowImagePicking
                    ? TextButton.icon(
                        onPressed: _pickImages,
                        icon: const Icon(Icons.photo_library_outlined),
                        label: Text(
                          widget.requireImage
                              ? ref.t(
                                  'feed.change_image',
                                  fallback: 'Change Images',
                                )
                              : ref.t(
                                  'feed.add_image_optional',
                                  fallback: 'Add Images (Optional)',
                                ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(
                height: 10,
              ),
              if (_selectedImages.isNotEmpty && isCreateMode)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SizedBox(
                    height: 112,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _selectedImages.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        return Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.memory(
                                _selectedImages[index].bytes,
                                width: 112,
                                height: 112,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: IconButton.filled(
                                visualDensity: VisualDensity.compact,
                                onPressed: () => setState(
                                  () => _selectedImages.removeAt(index),
                                ),
                                icon: const Icon(Icons.close_rounded, size: 16),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              const SizedBox(
                height: 10,
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: state.isLoading
                      ? null
                      : () async {
                          final title = _titleController.text.trim();
                          final description =
                              _descriptionController.text.trim();
                          final messenger = ScaffoldMessenger.of(context);

                          if (title.isEmpty || description.isEmpty) {
                            messenger.showSnackBar(
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

                          if (widget.requireImage && _selectedImages.isEmpty) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  ref.t(
                                    'feed.image_required',
                                    fallback:
                                        'An image is required for this post',
                                  ),
                                ),
                              ),
                            );
                            return;
                          }

                          final navigator = Navigator.of(context);
                          try {
                            if (widget.post == null) {
                              /// CREATE
                              await ref
                                  .read(
                                      feedPostModalControllerProvider.notifier)
                                  .createPost(
                                    title: title,
                                    description: description,
                                    imageFiles: _selectedImages,
                                    sharePersonalDetails: _sharePersonalDetails,
                                    isGlobal: widget.isGlobal,
                                  );
                              await logChurchAnalyticsEvent(
                                ref,
                                name: 'feed_post_created',
                                parameters: {
                                  'scope':
                                      widget.isGlobal ? 'global' : 'church',
                                },
                              );
                            } else {
                              /// UPDATE
                              if (!widget.post!.canEditAt(DateTime.now())) {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      ref.t(
                                        'feed.edit_window_expired',
                                        fallback:
                                            'Posts can only be edited within 30 minutes of publishing.',
                                      ),
                                    ),
                                  ),
                                );
                                return;
                              }
                              await ref
                                  .read(
                                      feedPostModalControllerProvider.notifier)
                                  .updatePost(
                                    postId: widget.post!.id,
                                    createdAt: widget.post!.createdAt,
                                    title: title,
                                    description: description,
                                    imageFile: null,
                                    existingImageUrl: widget.post!.imageUrl,
                                    sharePersonalDetails: _sharePersonalDetails,
                                    isGlobal: widget.isGlobal,
                                  );
                              await logChurchAnalyticsEvent(
                                ref,
                                name: 'feed_post_updated',
                                parameters: {
                                  'post_id': widget.post!.id,
                                  'scope':
                                      widget.isGlobal ? 'global' : 'church',
                                },
                              );
                            }

                            navigator.pop();
                          } on FeedEditWindowExpiredException {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  ref.t(
                                    'feed.edit_window_expired',
                                    fallback:
                                        'Posts can only be edited within 30 minutes of publishing.',
                                  ),
                                ),
                              ),
                            );
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
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(false),
                                    child: Text(
                                      ref.t('settings.cancel',
                                          fallback: 'Cancel'),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(true),
                                    child: Text(
                                      ref.t('feed.delete_action',
                                          fallback: 'Delete Post'),
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
                              ),
                            );

                            if (shouldDelete != true) return;

                            try {
                              await ref
                                  .read(
                                      feedPostModalControllerProvider.notifier)
                                  .deletePost(
                                    postId: widget.post!.id,
                                    imageUrl: widget.post!.imageUrl,
                                    imageUrls: widget.post!.imageUrls,
                                    isGlobal: widget.isGlobal,
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
