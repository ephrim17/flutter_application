import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/providers/app_config_provider.dart';
import 'package:flutter_application/church_app/providers/authentication/admin_provider.dart';
import 'package:flutter_application/church_app/providers/church_provider.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
import 'package:flutter_application/church_app/providers/feeds_provider.dart';
import 'package:flutter_application/church_app/services/feed_repository.dart';
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

class FeedCard extends ConsumerWidget {
  final FeedPost post;
  final bool isGlobal;

  const FeedCard({
    super.key,
    required this.post,
    this.isGlobal = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firebaseUser = ref.watch(firebaseAuthProvider).currentUser;
    final currentUid = firebaseUser?.uid;
    final isAdmin = ref.watch(isAdminProvider);
    final postChurchId = post.churchId?.trim() ?? '';
    final isPostChurchAdmin = isGlobal && postChurchId.isNotEmpty
        ? ref.watch(churchAdminProvider(postChurchId))
        : false;

    final isOwner = currentUid != null && currentUid == post.userId;
    final canDelete = isOwner || (isGlobal ? isPostChurchAdmin : isAdmin);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: carouselBoxDecoration(context),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// HEADER
            Row(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: isGlobal
                      ? () => _showPostAuthorDetails(context, ref)
                      : null,
                  child: CircleAvatar(
                    radius: 20,
                    backgroundImage: post.userPhoto != null
                        ? NetworkImage(post.userPhoto!)
                        : null,
                    child: post.userPhoto == null
                        ? Text(post.userName[0].toUpperCase())
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.userName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      humanFormatDate(post.createdAt),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                if (isOwner || canDelete)
                  PopupMenuButton<_FeedPostAction>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (action) async {
                      switch (action) {
                        case _FeedPostAction.edit:
                          await _editPost(context, ref);
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

            const SizedBox(height: 12),

            /// TITLE
            Text(
              post.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 8),

            /// DESCRIPTION
            LinkifiedText(
              text: post.description,
              style: const TextStyle(fontSize: 14),
            ),

            const SizedBox(height: 8),

            /// IMAGE (OPTIONAL)
            if (post.imageUrl != null)
              ShimmerImage(
                imageUrl: post.imageUrl!,
                fit: BoxFit.fill,
                aspectRatio: 1,
              ),
          ],
        ),
      ),
    );
  }

  String humanFormatDate(DateTime createdAt) {
    final datePart = DateFormat('MMM d').format(createdAt);
    final timePart = DateFormat('h:mm a').format(createdAt);
    return "$datePart at $timePart";
  }

  Future<void> _editPost(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => CreatePostModal(
        post: post,
        edit: true,
        isGlobal: isGlobal,
      ),
    );

    await _refreshFeed(ref);
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
      isGlobal: isGlobal,
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
    final postChurchId = post.churchId?.trim() ?? '';
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

enum _FeedPostAction {
  edit,
  delete,
}
