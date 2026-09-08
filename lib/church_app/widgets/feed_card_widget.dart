import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/widgets/app_confirm_dialog.dart';
import 'package:flutter_application/church_app/widgets/app_popup_menu.dart';
import 'package:flutter_application/church_app/widgets/app_profile_avatar.dart';
import 'package:flutter_application/church_app/widgets/app_image_gallery_viewer.dart';
import 'package:flutter_application/church_app/providers/app_config_provider.dart';
import 'package:flutter_application/church_app/providers/authentication/admin_provider.dart';
import 'package:flutter_application/church_app/providers/church_provider.dart';
import 'package:flutter_application/church_app/providers/feeds_provider.dart';
import 'package:flutter_application/church_app/helpers/feed_link_utils.dart';
import 'package:flutter_application/church_app/helpers/contact_launcher.dart';
import 'package:flutter_application/church_app/services/analytics/firebase_analytics_helper.dart';
import 'package:flutter_application/church_app/services/feed_repository.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_provider.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_paths.dart';
import 'package:flutter_application/church_app/widgets/feed_post_modal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';
import 'package:flutter_application/church_app/models/app_user_model.dart';
import 'package:flutter_application/church_app/models/church_model.dart';
import 'package:flutter_application/church_app/models/feed_model.dart';
import 'package:flutter_application/church_app/widgets/linkified_text_widget.dart';
import 'package:flutter_application/church_app/widgets/shimmer_image.dart';
import 'package:flutter_application/church_app/widgets/user_quick_card_widget.dart';
import 'package:intl/intl.dart';

class FeedCard extends ConsumerStatefulWidget {
  static final DateFormat _feedDateFormat = DateFormat('MMM d');
  static final DateFormat _feedTimeFormat = DateFormat('h:mm a');

  final FeedPost post;
  final String? currentUid;
  final bool isAdmin;
  final bool isGlobal;
  final bool fullBleed;
  final ValueChanged<String>? onHashtagTap;
  final VoidCallback? onPostChanged;
  final VoidCallback? onDescriptionTap;
  final VoidCallback? onTap;

  const FeedCard({
    super.key,
    required this.post,
    required this.currentUid,
    required this.isAdmin,
    this.isGlobal = false,
    this.fullBleed = false,
    this.onHashtagTap,
    this.onPostChanged,
    this.onDescriptionTap,
    this.onTap,
  });

  @override
  ConsumerState<FeedCard> createState() => _FeedCardState();
}

class _FeedCardState extends ConsumerState<FeedCard> {
  static DateFormat get _feedDateFormat => FeedCard._feedDateFormat;
  static DateFormat get _feedTimeFormat => FeedCard._feedTimeFormat;

  bool _isBusy = false;

  FeedPost get post => widget.post;
  String? get currentUid => widget.currentUid;
  bool get isAdmin => widget.isAdmin;
  bool get isGlobal => widget.isGlobal;
  ValueChanged<String>? get onHashtagTap => widget.onHashtagTap;
  VoidCallback? get onPostChanged => widget.onPostChanged;
  VoidCallback? get onDescriptionTap => widget.onDescriptionTap;
  VoidCallback? get onTap => widget.onTap;

  @override
  Widget build(BuildContext context) {
    final postChurchId = post.churchId?.trim() ?? '';
    final isPostChurchAdmin = isGlobal && postChurchId.isNotEmpty
        ? ref.watch(churchAdminProvider(postChurchId))
        : false;

    final isOwner = currentUid != null && currentUid == post.userId;
    final isPromotedGlobal = isGlobal &&
        post.sourceChurchId.isNotEmpty &&
        post.sourcePostId.isNotEmpty;
    final globalFeedEnabled =
        ref.watch(appConfigProvider).value?.globalFeedEnabled ?? false;
    final canManageGlobal = (globalFeedEnabled || post.isGlobal) &&
        (isGlobal ? isPostChurchAdmin && isPromotedGlobal : isAdmin);
    final canDelete = !isPromotedGlobal &&
        (isOwner || (isGlobal ? isPostChurchAdmin : isAdmin));
    final canEdit =
        isOwner && !isPromotedGlobal && post.canEditAt(DateTime.now());
    final theme = Theme.of(context);
    final hasImage = post.imageUrls.isNotEmpty;
    final youtubePreview = FeedLinkUtils.youtubePreviewFromText(
      '${post.title}\n${post.description}',
    );

    final actions = <AppPopupMenuAction<_FeedPostAction>>[
      if (canEdit)
        AppPopupMenuAction(
          value: _FeedPostAction.edit,
          icon: Icons.edit_outlined,
          label: ref.t('feed.edit_post'),
        ),
      if (canManageGlobal && !post.isGlobal)
        AppPopupMenuAction(
          value: _FeedPostAction.makeGlobal,
          icon: Icons.public_rounded,
          label: ref.t('feed.make_global_action'),
        ),
      if (canManageGlobal && post.isGlobal)
        AppPopupMenuAction(
          value: _FeedPostAction.removeGlobal,
          icon: Icons.public_off_outlined,
          label: ref.t('feed.remove_global_action'),
        ),
      if (canDelete)
        AppPopupMenuAction(
          value: _FeedPostAction.delete,
          icon: Icons.delete_outline_rounded,
          label: ref.t('feed.delete_post'),
          color: theme.colorScheme.error,
        ),
    ];

    Future<void> handlePostAction(_FeedPostAction action) async {
      setState(() => _isBusy = true);
      try {
        switch (action) {
          case _FeedPostAction.edit:
            await _editPost(context, ref);
            break;
          case _FeedPostAction.makeGlobal:
            await _setPostGlobal(context, ref, makeGlobal: true);
            break;
          case _FeedPostAction.removeGlobal:
            await _setPostGlobal(context, ref, makeGlobal: false);
            break;
          case _FeedPostAction.delete:
            await _confirmAndDeletePost(context, ref);
            break;
        }
      } finally {
        if (mounted) setState(() => _isBusy = false);
      }
    }

    if (widget.fullBleed) {
      return _buildFullBleed(
        context,
        theme: theme,
        hasImage: hasImage,
        actions: actions,
        onAction: handlePostAction,
      );
    }

    final card = Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: carouselBoxDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 8, 10),
            child: Row(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () => _showPostAuthorDetails(context, ref),
                  child: AppProfileAvatar(
                    name: post.userName,
                    imageUrl: post.userPhoto,
                    radius: 21,
                    backgroundColor:
                        theme.colorScheme.primary.withValues(alpha: 0.10),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.userName,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            humanFormatDate(post.createdAt),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                          ),
                          if (!isGlobal && post.isGlobal)
                            _GlobalFeedBadge(
                              label: ref.t('feed.global_badge'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (_isBusy)
                  const Padding(
                    padding: EdgeInsets.all(9),
                    child: SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else if (actions.isNotEmpty)
                  AppPopupMenu<_FeedPostAction>(
                    onSelected: handlePostAction,
                    actions: actions,
                  ),
              ],
            ),
          ),
          if (hasImage)
            _FeedImageGallery(
              imageUrls: post.imageUrls,
              aspectRatio: post.clampedImageAspectRatio ?? 1,
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                if (post.title.trim().isNotEmpty)
                  LinkifiedText(
                    text: post.title,
                    onHashtagTap: onHashtagTap,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                if (post.description.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _ExpandableDescription(
                    text: post.description,
                    onHashtagTap: onHashtagTap,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                  ),
                ],
                if (youtubePreview != null) ...[
                  const SizedBox(height: 12),
                  _YoutubePreviewCard(preview: youtubePreview),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return card;
    return InkWell(
      borderRadius: BorderRadius.circular(cornerRadius),
      onTap: onTap,
      child: card,
    );
  }

  String humanFormatDate(DateTime createdAt) {
    final datePart = _feedDateFormat.format(createdAt);
    final timePart = _feedTimeFormat.format(createdAt);
    return "$datePart at $timePart";
  }

  Widget _buildFullBleed(
    BuildContext context, {
    required ThemeData theme,
    required bool hasImage,
    required List<AppPopupMenuAction<_FeedPostAction>> actions,
    required Future<void> Function(_FeedPostAction) onAction,
  }) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: hasImage
              ? _FeedFullBleedImages(imageUrls: post.imageUrls)
              : ColoredBox(
                  color: Colors.black,
                  child: Center(
                    child: Icon(
                      Icons.church_outlined,
                      size: 72,
                      color: Colors.white.withValues(alpha: 0.25),
                    ),
                  ),
                ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.78),
                ],
              ),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                // A little bottom clearance keeps the caption just clear of
                // the floating (frosted, extended-body) bottom nav bar that
                // sits over this layout in the Community tab.
                padding: const EdgeInsets.fromLTRB(16, 70, 12, 56),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            borderRadius: BorderRadius.circular(24),
                            onTap: () => _showPostAuthorDetails(context, ref),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AppProfileAvatar(
                                  name: post.userName,
                                  imageUrl: post.userPhoto,
                                  radius: 16,
                                  backgroundColor:
                                      Colors.white.withValues(alpha: 0.16),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    post.userName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                if (!isGlobal && post.isGlobal) ...[
                                  const SizedBox(width: 8),
                                  _GlobalFeedBadge(
                                      label: ref.t('feed.global_badge')),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: onDescriptionTap,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (post.title.trim().isNotEmpty)
                                  Text(
                                    post.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        theme.textTheme.titleMedium?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      height: 1.2,
                                    ),
                                  ),
                                if (post.description.trim().isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      post.description,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style:
                                          theme.textTheme.bodyMedium?.copyWith(
                                        color:
                                            Colors.white.withValues(alpha: 0.92),
                                        height: 1.3,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_isBusy)
                      const Padding(
                        padding: EdgeInsets.all(9),
                        child: SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                      )
                    else if (actions.isNotEmpty)
                      AppPopupMenu<_FeedPostAction>(
                        onSelected: onAction,
                        trigger: const Icon(
                          Icons.more_vert_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        actions: actions,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _editPost(BuildContext context, WidgetRef ref) async {
    if (!post.canEditAt(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ref.t('feed.edit_window_expired'),
          ),
        ),
      );
      return;
    }

    await logChurchAnalyticsEvent(
      ref,
      name: 'feed_post_edit_started',
      parameters: {
        'post_id': post.id,
        'scope': isGlobal ? 'global' : 'church',
      },
    );
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => CreatePostModal(post: post, edit: true),
      ),
    );

    await _refreshFeed(ref);
    onPostChanged?.call();
  }


  Future<void> _setPostGlobal(
    BuildContext context,
    WidgetRef ref, {
    required bool makeGlobal,
  }) async {
    final currentChurchId = ref.read(currentChurchIdProvider).value;
    final sourceChurchId = isGlobal
        ? post.sourceChurchId
        : (post.churchId?.trim().isNotEmpty ?? false)
            ? post.churchId!.trim()
            : currentChurchId?.trim() ?? '';
    final sourcePostId = isGlobal ? post.sourcePostId : post.id;
    if (sourceChurchId.isEmpty || sourcePostId.isEmpty) return;

    final churchFeedController =
        ref.read(feedPaginationControllerProvider(sourceChurchId).notifier);
    final globalFeedController =
        ref.read(globalFeedPaginationControllerProvider.notifier);
    final repository = ref.read(feedRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);

    churchFeedController.setChurchPostGlobal(
      postId: sourcePostId,
      isGlobal: makeGlobal,
    );
    if (makeGlobal) {
      globalFeedController.upsertPromotedPost(
        source: post,
        sourceChurchId: sourceChurchId,
      );
    } else {
      globalFeedController.removePromotedPost(
        sourceChurchId: sourceChurchId,
        sourcePostId: sourcePostId,
      );
    }

    try {
      await repository.setPostGlobal(
        churchId: sourceChurchId,
        postId: sourcePostId,
        isGlobal: makeGlobal,
      );
      unawaited(
        logAnalyticsEvent(
          name: makeGlobal
              ? 'feed_post_made_global'
              : 'feed_post_removed_from_global',
          parameters: {
            'post_id': sourcePostId,
            'church_id': sourceChurchId,
          },
        ),
      );
      unawaited(
        Future.wait([
          churchFeedController.refreshSilently(),
          globalFeedController.refreshSilently(),
        ]),
      );
      onPostChanged?.call();

      if (!messenger.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            makeGlobal
                ? ref.t('feed.global_success')
                : ref.t('feed.global_removed'),
          ),
        ),
      );
    } catch (error) {
      await Future.wait([
        churchFeedController.refreshSilently(),
        globalFeedController.refreshSilently(),
      ]);
      if (!messenger.mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _confirmAndDeletePost(
      BuildContext context, WidgetRef ref) async {
    final shouldDelete = await showAppConfirmDialog(
      context: context,
      title: ref.t('feed.delete_confirm_title'),
      message: ref.t('feed.delete_confirm_message'),
      cancelLabel: ref.t('settings.cancel'),
      confirmLabel: ref.t('common.delete'),
      isDestructive: true,
    );

    if (!shouldDelete) return;

    final churchId = ref.read(currentChurchIdProvider).value;
    if (!isGlobal && churchId == null) return;

    final repository = FeedRepository(ref.read(firestoreProvider));
    await repository.deletePost(
      churchId: post.churchId ?? churchId,
      postId: post.id,
      imageUrl: post.imageUrl,
      imageUrls: post.imageUrls,
      isGlobal: isGlobal,
    );
    await logChurchAnalyticsEvent(
      ref,
      name: 'feed_post_deleted',
      parameters: {
        'post_id': post.id,
        'scope': isGlobal ? 'global' : 'church',
      },
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ref.t('feed.post_deleted'),
        ),
      ),
    );

    await _refreshFeed(ref);
    onPostChanged?.call();
  }

  Future<void> _refreshFeed(WidgetRef ref) async {
    if (isGlobal) {
      await ref.read(globalFeedPaginationControllerProvider.notifier).refresh();
      return;
    }

    final churchId = ref.read(currentChurchIdProvider).value;
    if (churchId == null) return;
    await ref
        .read(feedPaginationControllerProvider(churchId).notifier)
        .refresh();
  }

  Future<void> _showPostAuthorDetails(
      BuildContext context, WidgetRef ref) async {
    final currentChurchId = ref.read(currentChurchIdProvider).value;
    final postChurchId = (post.churchId?.trim().isNotEmpty ?? false)
        ? post.churchId!.trim()
        : (!isGlobal ? currentChurchId?.trim() ?? '' : '');
    if (postChurchId.isEmpty) return;
    var churchName = post.churchName?.trim() ?? '';
    var churchPastorName = post.churchPastorName?.trim() ?? '';

    if (churchName.isEmpty || churchPastorName.isEmpty) {
      final churchDoc = await FirestorePaths.churchDoc(
        ref.read(firestoreProvider),
        postChurchId,
      ).get();

      if (churchDoc.exists) {
        final church = Church.fromFirestore(
          churchDoc.id,
          churchDoc.data() as Map<String, dynamic>? ?? {},
        );
        if (churchName.isEmpty) {
          churchName = church.name;
        }
        if (churchPastorName.isEmpty) {
          churchPastorName = church.pastorName;
        }
      }
    }

    if (!isGlobal) {
      final user = await _loadAuthorFromChurch(ref, postChurchId) ??
          AppUser(
            uid: post.userId,
            name: post.userName,
            profilePhotoUrl: post.userPhoto ?? '',
            email: '',
            role: 'user',
            approved: true,
            phone: '',
            contact: '',
            location: '',
            address: '',
            gender: '',
            category: '',
            familyId: '',
            maritalStatus: '',
            weddingDay: null,
            financialStabilityRating: 0,
            financialSupportRequired: false,
            educationalQualification: '',
            talentsAndGifts: const [],
            churchGroupIds: const [],
            authToken: '',
            dob: null,
          );

      if (!context.mounted) return;
      await showUserQuickCardWithChurch(
        context,
        user,
        churchName: churchName,
        churchPastorName: churchPastorName,
      );
      return;
    }

    if (!context.mounted) return;
    if (!post.sharePersonalDetails) {
      await showUserQuickCardWithChurch(
        context,
        AppUser(
          uid: post.userId,
          name: post.userName,
          profilePhotoUrl: post.userPhoto ?? '',
          email: '',
          role: 'user',
          approved: true,
          phone: '',
          contact: '',
          location: '',
          address: '',
          gender: '',
          category: '',
          familyId: '',
          maritalStatus: '',
          weddingDay: null,
          financialStabilityRating: 0,
          financialSupportRequired: false,
          educationalQualification: '',
          talentsAndGifts: const [],
          churchGroupIds: const [],
          authToken: '',
          dob: null,
        ),
        churchName: churchName,
        churchPastorName: churchPastorName,
        showCategory: false,
        showAddress: false,
        showDob: false,
        showEmail: false,
        showPhone: false,
      );
      return;
    }

    final postHasStoredPersonalDetails =
        (post.userCategory?.trim().isNotEmpty ?? false) ||
            (post.userAddress?.trim().isNotEmpty ?? false) ||
            (post.userEmail?.trim().isNotEmpty ?? false) ||
            (post.userPhone?.trim().isNotEmpty ?? false) ||
            post.userDob != null;

    final user = postHasStoredPersonalDetails
        ? AppUser(
            uid: post.userId,
            name: post.userName,
            profilePhotoUrl: post.userPhoto ?? '',
            email: post.userEmail ?? '',
            role: 'user',
            approved: true,
            phone: post.userPhone ?? '',
            contact: '',
            location: '',
            address: post.userAddress ?? '',
            gender: '',
            category: post.userCategory ?? '',
            familyId: '',
            maritalStatus: '',
            weddingDay: null,
            financialStabilityRating: 0,
            financialSupportRequired: false,
            educationalQualification: '',
            talentsAndGifts: const [],
            churchGroupIds: const [],
            authToken: '',
            dob: post.userDob,
          )
        : await _loadAuthorFromChurch(ref, postChurchId);

    if (user == null || !context.mounted) return;
    await showUserQuickCardWithChurch(
      context,
      user,
      churchName: churchName,
      churchPastorName: churchPastorName,
    );
  }

  Future<AppUser?> _loadAuthorFromChurch(WidgetRef ref, String churchId) async {
    final doc = await FirestorePaths.churchUserDoc(
      ref.read(firestoreProvider),
      churchId,
      post.userId,
    ).get();

    if (!doc.exists) return null;
    return AppUser.fromJson(doc.data() as Map<String, dynamic>);
  }
}

/// LinkedIn-style truncation: shows the first [previewLength] characters
/// with an inline "more" toggle that expands to the full post in place.
class _ExpandableDescription extends StatefulWidget {
  const _ExpandableDescription({
    required this.text,
    required this.onHashtagTap,
    required this.style,
    this.previewLength = 200,
  });

  final String text;
  final ValueChanged<String>? onHashtagTap;
  final TextStyle? style;
  final int previewLength;

  @override
  State<_ExpandableDescription> createState() =>
      _ExpandableDescriptionState();
}

class _ExpandableDescriptionState extends State<_ExpandableDescription> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trimmed = widget.text.trim();
    final isLong = trimmed.length > widget.previewLength;
    final displayText = !isLong || _expanded
        ? trimmed
        : '${trimmed.substring(0, widget.previewLength).trimRight()}…';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinkifiedText(
          text: displayText,
          onHashtagTap: widget.onHashtagTap,
          style: widget.style,
        ),
        if (isLong)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                _expanded
                    ? context.t('ui.feed_card.show_less')
                    : context.t('ui.feed_card.show_more'),
                style: widget.style?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _FeedImageGallery extends StatefulWidget {
  const _FeedImageGallery({required this.imageUrls, required this.aspectRatio});

  final List<String> imageUrls;

  /// Instagram/LinkedIn-style: the card's height follows the image's real
  /// shape (clamped to a sane portrait/landscape range) instead of forcing
  /// every photo into a fixed square crop.
  final double aspectRatio;

  @override
  State<_FeedImageGallery> createState() => _FeedImageGalleryState();
}

class _FeedImageGalleryState extends State<_FeedImageGallery> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.black.withValues(alpha: 0.04),
      ),
      child: AspectRatio(
        aspectRatio: widget.aspectRatio,
        child: Stack(
          children: [
            PageView.builder(
              itemCount: widget.imageUrls.length,
              onPageChanged: (value) => setState(() => _page = value),
              itemBuilder: (context, index) {
                final imageUrl = widget.imageUrls[index];
                return InkWell(
                  onTap: () => showAppImageGallery(
                    context,
                    imageUrls: widget.imageUrls,
                    initialIndex: index,
                    heroTagBuilder: (url, _) => 'feed-gallery-$url',
                  ),
                  // The Hero's own child stays a bare, unconstrained image —
                  // no nested AspectRatio/ClipRRect — so the flight can
                  // resize it smoothly frame-by-frame instead of fighting a
                  // locked ratio as the bounds morph toward full screen.
                  child: Hero(
                    tag: 'feed-gallery-$imageUrl',
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                    ),
                  ),
                );
              },
            ),
            if (widget.imageUrls.length > 1)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.68),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '${_page + 1}/${widget.imageUrls.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
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

/// Fills the entire post frame edge-to-edge, cropping any image whose aspect
/// ratio doesn't match — the Instagram-Reels look this layout is built for.
class _FeedFullBleedImages extends StatefulWidget {
  const _FeedFullBleedImages({required this.imageUrls});

  final List<String> imageUrls;

  @override
  State<_FeedFullBleedImages> createState() => _FeedFullBleedImagesState();
}

class _FeedFullBleedImagesState extends State<_FeedFullBleedImages> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          itemCount: widget.imageUrls.length,
          onPageChanged: (value) => setState(() => _page = value),
          itemBuilder: (context, index) {
            final imageUrl = widget.imageUrls[index];
            // A raw CachedNetworkImage (not the shimmer-wrapped helper) so
            // this full-bleed feed shows posts as they naturally arrive —
            // no fade-in and no shimmer sweep — and caps decode size to the
            // device's own pixel width so swiping doesn't stall on
            // full-resolution camera photos.
            final devicePixelWidth =
                (MediaQuery.of(context).size.width *
                        MediaQuery.of(context).devicePixelRatio)
                    .round();
            return GestureDetector(
              onTap: () => showAppImageGallery(
                context,
                imageUrls: widget.imageUrls,
                initialIndex: index,
                heroTagBuilder: (url, _) => 'feed-gallery-$url',
              ),
              child: Hero(
                tag: 'feed-gallery-$imageUrl',
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  memCacheWidth: devicePixelWidth,
                  fadeInDuration: Duration.zero,
                  fadeOutDuration: Duration.zero,
                  placeholder: (context, url) =>
                      const ColoredBox(color: Colors.black),
                  errorWidget: (context, url, error) => const ColoredBox(
                    color: Colors.black,
                    child: Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white38,
                        size: 40,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        if (widget.imageUrls.length > 1)
          Positioned(
            top: 56,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.imageUrls.length, (index) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  height: 4,
                  width: index == _page ? 16 : 4,
                  decoration: BoxDecoration(
                    color: Colors.white
                        .withValues(alpha: index == _page ? 0.95 : 0.45),
                    borderRadius: BorderRadius.circular(999),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}

class _YoutubePreviewCard extends StatelessWidget {
  const _YoutubePreviewCard({required this.preview});

  final YoutubePreviewData preview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openYoutubeLink(context),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.18),
            ),
            color: theme.colorScheme.surface,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  ShimmerImage(
                    imageUrl: preview.thumbnailUrl,
                    aspectRatio: 16 / 9,
                    borderRadius: 0,
                    fit: BoxFit.cover,
                  ),
                  Container(
                    height: 54,
                    width: 54,
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.22),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(
                      Icons.ondemand_video_rounded,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.t('ui.feed_card.watch_on_youtube'),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const Icon(Icons.open_in_new_rounded, size: 18),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openYoutubeLink(BuildContext context) async {
    final launched = await launchExternalUri(context, preview.url);

    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(context.t('ui.feed_card.unable_to_open_youtube_link'))),
      );
    }
  }
}

class _GlobalFeedBadge extends StatelessWidget {
  const _GlobalFeedBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.tertiary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.public_rounded, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

enum _FeedPostAction {
  edit,
  makeGlobal,
  removeGlobal,
  delete,
}
