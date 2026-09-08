import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/models/app_user_model.dart';
import 'package:flutter_application/church_app/models/feed_model.dart';
import 'package:flutter_application/church_app/models/picked_image_data.dart';
import 'package:flutter_application/church_app/providers/app_config_provider.dart';
import 'package:flutter_application/church_app/providers/community_upload_provider.dart';
import 'package:flutter_application/church_app/services/analytics/firebase_analytics_helper.dart';
import 'package:flutter_application/church_app/providers/feed_post_modal_provider.dart';
import 'package:flutter_application/church_app/providers/user_provider.dart';
import 'package:flutter_application/church_app/widgets/app_profile_avatar.dart';
import 'package:flutter_application/church_app/widgets/feed_image_crop_preview_screen.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_application/church_app/widgets/app_text_field.dart';

const feedCaptionMaxLength = 500;

/// Instagram-style full-screen post composer: one merged caption field (no
/// separate title/description), an audience dropdown that decides Your
/// Church vs All Churches, and a tap-the-avatar sheet for personal-details
/// visibility on global posts.
class CreatePostModal extends ConsumerStatefulWidget {
  final FeedPost? post;
  final bool edit;
  final bool initialIsGlobal;

  const CreatePostModal({
    super.key,
    this.post,
    this.edit = false,
    this.initialIsGlobal = false,
  });

  @override
  ConsumerState<CreatePostModal> createState() => _CreatePostModalState();
}

class _CreatePostModalState extends ConsumerState<CreatePostModal> {
  final _captionController = TextEditingController();
  bool _sharePersonalDetails = false;
  bool _isGlobal = false;
  int _previewIndex = 0;
  final List<PickedImageData> _selectedImages = [];

  bool get _isEditMode => widget.post != null || widget.edit;

  @override
  void initState() {
    super.initState();
    _isGlobal = widget.initialIsGlobal;
    _captionController.addListener(_handleCaptionChanged);

    if (widget.post != null) {
      final title = widget.post!.title.trim();
      final description = widget.post!.description.trim();
      _captionController.text = [
        title,
        description,
      ].where((part) => part.isNotEmpty).join('\n\n');
      _sharePersonalDetails = widget.post!.sharePersonalDetails;
      _isGlobal = widget.post!.isGlobal;
    }
  }

  @override
  void dispose() {
    _captionController.removeListener(_handleCaptionChanged);
    _captionController.dispose();
    super.dispose();
  }

  void _handleCaptionChanged() => setState(() {});

  Future<void> _pickImages() async {
    final confirmed = await pickAndPreviewFeedImages(context);
    if (confirmed.isEmpty || !mounted) return;

    setState(() {
      _selectedImages
        ..clear()
        ..addAll(confirmed);
      _previewIndex = 0;
    });
  }

  Future<void> _showVisibilitySheet(bool globalFeedEnabled) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ref.t('feed.visibility_sheet_title'),
                      style: Theme.of(sheetContext)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      ref.t('feed.visibility_sheet_subtitle'),
                      style: Theme.of(sheetContext).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _sharePersonalDetails,
                      onChanged: !globalFeedEnabled
                          ? null
                          : (value) {
                              setSheetState(() {});
                              setState(() => _sharePersonalDetails = value);
                            },
                      title: Text(ref.t('feed.global_share_details_title')),
                      subtitle: Text(
                        _sharePersonalDetails
                            ? ref.t('feed.global_share_details_enabled')
                            : ref.t('feed.global_share_details_disabled'),
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

  Future<void> _submit(bool globalFeedEnabled) async {
    final state = ref.read(feedPostModalControllerProvider);
    if (state.isLoading) return;

    final caption = _captionController.text.trim();
    final messenger = ScaffoldMessenger.of(context);

    if (caption.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(ref.t('feed.validation_all_fields_required'))),
      );
      return;
    }

    final isGlobal = globalFeedEnabled && _isGlobal;

    if (widget.post == null) {
      // Create: hand off to the caller immediately instead of blocking this
      // screen on the upload — it closes now, and a floating banner tracks
      // progress from wherever the user ends up, Instagram/LinkedIn-style.
      await logChurchAnalyticsEvent(
        ref,
        name: 'feed_post_create_submitted',
        parameters: {'scope': isGlobal ? 'global' : 'church'},
      );
      if (!mounted) return;
      Navigator.of(context).pop(
        PendingCommunityPost(
          caption: caption,
          images: List.of(_selectedImages),
          isGlobal: isGlobal,
          sharePersonalDetails: _sharePersonalDetails,
        ),
      );
      return;
    }

    final navigator = Navigator.of(context);
    try {
      if (!widget.post!.canEditAt(DateTime.now())) {
        messenger.showSnackBar(
          SnackBar(content: Text(ref.t('feed.edit_window_expired'))),
        );
        return;
      }
      await ref.read(feedPostModalControllerProvider.notifier).updatePost(
            postId: widget.post!.id,
            createdAt: widget.post!.createdAt,
            title: '',
            description: caption,
            imageFile: null,
            existingImageUrl: widget.post!.imageUrl,
            sharePersonalDetails: _sharePersonalDetails,
            isGlobal: isGlobal,
          );
      await logChurchAnalyticsEvent(
        ref,
        name: 'feed_post_updated',
        parameters: {
          'post_id': widget.post!.id,
          'scope': isGlobal ? 'global' : 'church',
        },
      );

      navigator.pop();
    } on FeedEditWindowExpiredException {
      messenger.showSnackBar(
        SnackBar(content: Text(ref.t('feed.edit_window_expired'))),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _confirmDelete() async {
    final post = widget.post;
    if (post == null) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ref.t('feed.delete_confirm_title')),
        content: Text(ref.t('feed.delete_confirm_message')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ref.t('settings.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              ref.t('feed.delete_action'),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    try {
      await ref.read(feedPostModalControllerProvider.notifier).deletePost(
            postId: post.id,
            imageUrl: post.imageUrl,
            imageUrls: post.imageUrls,
            isGlobal: post.isGlobal,
          );
      navigator.pop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(feedPostModalControllerProvider);
    final currentUser = ref.watch(appUserProvider).asData?.value;
    final globalFeedEnabled =
        ref.watch(appConfigProvider).value?.globalFeedEnabled ?? false;
    if (!globalFeedEnabled && _isGlobal) {
      _isGlobal = false;
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(theme, globalFeedEnabled, state.isLoading, currentUser),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppTextField(
                      controller: _captionController,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      minLines: 4,
                      maxLines: null,
                      maxLength: feedCaptionMaxLength,
                      autofocus: !_isEditMode,
                      decoration: InputDecoration(
                        hintText: ref.t('feed.caption_hint'),
                        border: InputBorder.none,
                        counterText: '',
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${_captionController.text.length}/$feedCaptionMaxLength',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (_selectedImages.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: _buildImagePreview(theme),
                      ),
                  ],
                ),
              ),
            ),
            _buildBottomToolbar(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(
    ThemeData theme,
    bool globalFeedEnabled,
    bool isSubmitting,
    AppUser? currentUser,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _showVisibilitySheet(globalFeedEnabled),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: AppProfileAvatar(
                name: currentUser?.name ?? '',
                imageUrl: currentUser?.profilePhotoUrl,
                radius: 16,
              ),
            ),
          ),
          const SizedBox(width: 6),
          if (globalFeedEnabled)
            Flexible(
              child: PopupMenuButton<bool>(
                initialValue: _isGlobal,
                onSelected: (value) => setState(() => _isGlobal = value),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: false,
                    child: Text(ref.t('ui.feed.your_church')),
                  ),
                  PopupMenuItem(
                    value: true,
                    child: Text(ref.t('ui.feed.all_churches')),
                  ),
                ],
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        _isGlobal
                            ? ref.t('ui.feed.all_churches')
                            : ref.t('ui.feed.your_church'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down_rounded),
                  ],
                ),
              ),
            )
          else
            Flexible(
              child: Text(
                ref.t('ui.feed.your_church'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          const Spacer(),
          FilledButton(
            onPressed: isSubmitting ? null : () => _submit(globalFeedEnabled),
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            child: isSubmitting
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    widget.post == null
                        ? ref.t('feed.post_action')
                        : ref.t('feed.update_action'),
                  ),
          ),
          if (widget.post != null)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
              onPressed: isSubmitting ? null : _confirmDelete,
            ),
        ],
      ),
    );
  }

  Widget _buildImagePreview(ThemeData theme) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: PageView.builder(
              itemCount: _selectedImages.length,
              onPageChanged: (index) => setState(() => _previewIndex = index),
              itemBuilder: (context, index) => Image.memory(
                _selectedImages[index].bytes,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        if (_selectedImages.length > 1)
          Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_selectedImages.length, (index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  height: 6,
                  width: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(
                      alpha: index == _previewIndex ? 0.95 : 0.45,
                    ),
                  ),
                );
              }),
            ),
          ),
        Positioned(
          top: 8,
          right: 8,
          child: Row(
            children: [
              _RoundIconButton(
                icon: Icons.edit_outlined,
                onTap: _pickImages,
              ),
              const SizedBox(width: 8),
              _RoundIconButton(
                icon: Icons.close_rounded,
                onTap: () => setState(() {
                  _selectedImages.clear();
                  _previewIndex = 0;
                }),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomToolbar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: ref.t('feed.add_image_optional'),
            icon: const Icon(Icons.image_outlined),
            onPressed: _pickImages,
          ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Icon(icon, size: 18, color: Colors.white),
        ),
      ),
    );
  }
}
