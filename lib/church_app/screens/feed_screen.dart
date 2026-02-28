import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/providers/feeds_provider.dart';
import 'package:flutter_application/church_app/widgets/feed_card_widget.dart';
import 'package:flutter_application/church_app/widgets/feed_post_modal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(feedStreamProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openCreatePostModal(context, ref),
        child: const Icon(Icons.add),
      ),
      body: feedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(child: CircularProgressIndicator()),
        data: (posts) {
          if (posts.isEmpty) {
            return const Center(
              child: Text("No posts yet"),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              return FeedCard(post: post);
            },
          );
        },
      ),
    );
  }

  void _openCreatePostModal(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const CreatePostModal(),
    );
  }
}