import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
import 'package:flutter_application/church_app/widgets/feed_post_modal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';
import 'package:flutter_application/church_app/models/feed_model.dart';
import 'package:flutter_application/church_app/widgets/shimmer_image.dart';
import 'package:intl/intl.dart';

class FeedCard extends ConsumerWidget {
  final FeedPost post;

  const FeedCard({super.key, required this.post});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firebaseUser = ref.watch(firebaseAuthProvider).currentUser;
    final currentUid = firebaseUser?.uid;

    final isOwner = currentUid != null && currentUid == post.userId;

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
                CircleAvatar(
                  radius: 20,
                  backgroundImage: post.userPhoto != null
                      ? NetworkImage(post.userPhoto!)
                      : null,
                  child: post.userPhoto == null
                      ? Text(post.userName[0].toUpperCase())
                      : null,
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

                /// 👇 Show only if current user owns the post
                if (isOwner)
                  IconButton.filledTonal(
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => CreatePostModal(post: post),
                      );
                    },
                    icon: const Icon(Icons.edit_note),
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
            Text(
              post.description,
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
}
