import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/widgets/app_modal_bottom_sheet.dart';
import 'package:flutter_application/church_app/providers/app_config_provider.dart';
import 'package:flutter_application/church_app/providers/authentication/admin_provider.dart';
import 'package:flutter_application/church_app/providers/church_provider.dart';
import 'package:flutter_application/church_app/providers/feed_post_modal_provider.dart';
import 'package:flutter_application/church_app/providers/feeds_provider.dart';
import 'package:flutter_application/church_app/helpers/feed_link_utils.dart';
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
import 'package:url_launcher/url_launcher.dart';

class FeedCard extends ConsumerWidget {
  static final DateFormat _feedDateFormat = DateFormat('MMM d');
  static final DateFormat _feedTimeFormat = DateFormat('h:mm a');

  final FeedPost post;
  final String? currentUid;
  final bool isAdmin;
  final bool isGlobal;
  final ValueChanged<String>? onHashtagTap;
  final VoidCallback? onPostChanged;

  const FeedCard({
    super.key,
    required this.post,
    required this.currentUid,
    required this.isAdmin,
    this.isGlobal = false,
    this.onHashtagTap,
    this.onPostChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postChurchId = post.churchId?.trim() ?? '';
    final isPostChurchAdmin = isGlobal && postChurchId.isNotEmpty
        ? ref.watch(churchAdminProvider(postChurchId))
        : false;

    final isOwner = currentUid != null && currentUid == post.userId;
    final canDelete = isOwner || (isGlobal ? isPostChurchAdmin : isAdmin);
    final canPin = canDelete;
    final theme = Theme.of(context);
    final hasImage = post.imageUrls.isNotEmpty;
    final youtubePreview = FeedLinkUtils.youtubePreviewFromText(
      '${post.title}\n${post.description}',
    );

    return Container(
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
                  child: CircleAvatar(
                    radius: 21,
                    backgroundColor:
                        theme.colorScheme.primary.withValues(alpha: 0.10),
                    backgroundImage: post.userPhoto != null
                        ? NetworkImage(post.userPhoto!)
                        : null,
                    child: post.userPhoto == null
                        ? Text(
                            post.userName[0].toUpperCase(),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.primary,
                            ),
                          )
                        : null,
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
                          if (post.isPinned)
                            _PinnedBadge(
                              label: ref.t(
                                'feed.pinned_badge',
                                fallback: 'Pinned',
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (isOwner || canDelete || canPin)
                  PopupMenuButton<_FeedPostAction>(
                    icon: const Icon(Icons.more_horiz_rounded),
                    onSelected: (action) async {
                      switch (action) {
                        case _FeedPostAction.edit:
                          await _editPost(context, ref);
                          break;
                        case _FeedPostAction.pin:
                          await _setPinnedPost(context, ref, pinned: true);
                          break;
                        case _FeedPostAction.unpin:
                          await _setPinnedPost(context, ref, pinned: false);
                          break;
                        case _FeedPostAction.delete:
                          await _confirmAndDeletePost(context, ref);
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      if (isOwner)
                        PopupMenuItem(
                          value: _FeedPostAction.edit,
                          child: Text(
                            ref.t('feed.edit_post', fallback: 'Edit post'),
                          ),
                        ),
                      if (canPin)
                        PopupMenuItem(
                          value: post.isPinned
                              ? _FeedPostAction.unpin
                              : _FeedPostAction.pin,
                          child: Text(
                            post.isPinned
                                ? ref.t(
                                    'feed.unpin_post',
                                    fallback: 'Unpin post',
                                  )
                                : ref.t(
                                    'feed.pin_post',
                                    fallback: 'Pin post',
                                  ),
                          ),
                        ),
                      if (canDelete)
                        PopupMenuItem(
                          value: _FeedPostAction.delete,
                          child: Text(
                            ref.t('feed.delete_post', fallback: 'Delete post'),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
          if (hasImage) _FeedImageGallery(imageUrls: post.imageUrls),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
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
                  LinkifiedText(
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
  }

  String humanFormatDate(DateTime createdAt) {
    final datePart = _feedDateFormat.format(createdAt);
    final timePart = _feedTimeFormat.format(createdAt);
    return "$datePart at $timePart";
  }

  Future<void> _editPost(BuildContext context, WidgetRef ref) async {
    await logChurchAnalyticsEvent(
      ref,
      name: 'feed_post_edit_started',
      parameters: {
        'post_id': post.id,
        'scope': isGlobal ? 'global' : 'church',
      },
    );
    if (!context.mounted) return;
    await showAppModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => CreatePostModal(
        post: post,
        edit: true,
        isGlobal: isGlobal,
      ),
    );

    await _refreshFeed(ref);
    onPostChanged?.call();
  }

  Future<void> _setPinnedPost(
    BuildContext context,
    WidgetRef ref, {
    required bool pinned,
  }) async {
    await ref.read(feedPostModalControllerProvider.notifier).setPinnedPost(
          postId: post.id,
          pinned: pinned,
          isGlobal: isGlobal,
        );

    await logChurchAnalyticsEvent(
      ref,
      name: pinned ? 'feed_post_pinned' : 'feed_post_unpinned',
      parameters: {
        'post_id': post.id,
        'scope': isGlobal ? 'global' : 'church',
      },
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          pinned
              ? ref.t('feed.post_pinned', fallback: 'Post pinned')
              : ref.t('feed.post_unpinned', fallback: 'Post unpinned'),
        ),
      ),
    );

    await _refreshFeed(ref);
    onPostChanged?.call();
  }

  Future<void> _confirmAndDeletePost(
      BuildContext context, WidgetRef ref) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          ref.t('feed.delete_confirm_title', fallback: 'Delete post?'),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        content: Text(
          ref.t(
            'feed.delete_confirm_message',
            fallback: 'This will permanently delete the post and its image.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              ref.t('settings.cancel', fallback: 'Cancel'),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              ref.t('common.delete', fallback: 'Delete'),
            ),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

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
          ref.t('feed.post_deleted', fallback: 'Post deleted'),
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

class _FeedImageGallery extends StatefulWidget {
  const _FeedImageGallery({required this.imageUrls});

  final List<String> imageUrls;

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
        aspectRatio: 1,
        child: Stack(
          children: [
            PageView.builder(
              itemCount: widget.imageUrls.length,
              onPageChanged: (value) => setState(() => _page = value),
              itemBuilder: (context, index) {
                final imageUrl = widget.imageUrls[index];
                return InkWell(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => _FeedImagePreviewScreen(
                        imageUrls: widget.imageUrls,
                        initialIndex: index,
                      ),
                      fullscreenDialog: true,
                    ),
                  ),
                  child: Hero(
                    tag: 'feed-gallery-$imageUrl',
                    child: ShimmerImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      aspectRatio: 1,
                      borderRadius: 0,
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

class _FeedImagePreviewScreen extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const _FeedImagePreviewScreen({
    required this.imageUrls,
    required this.initialIndex,
  });

  @override
  State<_FeedImagePreviewScreen> createState() =>
      _FeedImagePreviewScreenState();
}

class _FeedImagePreviewScreenState extends State<_FeedImagePreviewScreen> {
  static const double _minScale = 1.0;
  static const double _maxScale = 5.0;
  late final PageController _pageController =
      PageController(initialPage: widget.initialIndex);
  late int _page = widget.initialIndex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.imageUrls.length > 1
              ? '${_page + 1} of ${widget.imageUrls.length}'
              : '',
          style: const TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.imageUrls.length,
        onPageChanged: (value) => setState(() => _page = value),
        itemBuilder: (context, index) {
          final imageUrl = widget.imageUrls[index];
          return Center(
            child: Hero(
              tag: 'feed-gallery-$imageUrl',
              child: InteractiveViewer(
                minScale: _minScale,
                maxScale: _maxScale,
                panEnabled: true,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  width: MediaQuery.sizeOf(context).width,
                  loadingBuilder: (context, child, progress) => progress == null
                      ? child
                      : const Center(child: CircularProgressIndicator()),
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.broken_image,
                    color: Colors.white70,
                    size: 48,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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
                        'Watch on YouTube',
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
    final launched = await launchUrl(
      preview.url,
      mode: LaunchMode.externalApplication,
    );

    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open YouTube link')),
      );
    }
  }
}

class _PinnedBadge extends StatelessWidget {
  const _PinnedBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final highlightColor = theme.colorScheme.secondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: highlightColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.push_pin_outlined,
            size: 13,
            color: highlightColor,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: highlightColor,
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
  pin,
  unpin,
  delete,
}
