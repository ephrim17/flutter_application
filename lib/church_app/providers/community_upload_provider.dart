import 'package:flutter_application/church_app/models/picked_image_data.dart';
import 'package:flutter_application/church_app/providers/feed_post_modal_provider.dart';
import 'package:flutter_application/church_app/providers/feeds_provider.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hooks_riverpod/legacy.dart';

/// The composer hands this back immediately on "Post" — the actual upload
/// happens afterward, tracked by [CommunityUploadController], so the
/// composer can close right away instead of blocking on the network call.
class PendingCommunityPost {
  const PendingCommunityPost({
    required this.caption,
    required this.images,
    required this.isGlobal,
    required this.sharePersonalDetails,
  });

  final String caption;
  final List<PickedImageData> images;
  final bool isGlobal;
  final bool sharePersonalDetails;
}

enum CommunityUploadStatus { idle, uploading, success, error }

class CommunityUploadState {
  const CommunityUploadState({
    this.status = CommunityUploadStatus.idle,
    this.errorMessage,
  });

  final CommunityUploadStatus status;
  final String? errorMessage;
}

final communityUploadControllerProvider =
    StateNotifierProvider<CommunityUploadController, CommunityUploadState>(
  (ref) => CommunityUploadController(ref),
);

/// Shared across the Community list and the full-screen viewer (both have
/// their own "+" button), so the floating progress banner shows up wherever
/// the user happens to be once the post finishes, regardless of which
/// screen started it.
class CommunityUploadController extends StateNotifier<CommunityUploadState> {
  CommunityUploadController(this._ref) : super(const CommunityUploadState());

  final Ref _ref;

  Future<void> submit({
    required String churchId,
    required PendingCommunityPost pending,
  }) async {
    state = const CommunityUploadState(status: CommunityUploadStatus.uploading);
    try {
      final createdPost =
          await _ref.read(feedPostModalControllerProvider.notifier).createPost(
                title: '',
                description: pending.caption,
                imageFiles: pending.images,
                sharePersonalDetails: pending.sharePersonalDetails,
                isGlobal: pending.isGlobal,
              );

      if (createdPost == null) {
        throw Exception('Post could not be created.');
      }
      if (createdPost.isGlobal) {
        _ref
            .read(globalFeedPaginationControllerProvider.notifier)
            .insertLocalPost(createdPost);
      } else {
        _ref
            .read(feedPaginationControllerProvider(churchId).notifier)
            .insertLocalPost(createdPost);
      }
      state = const CommunityUploadState(status: CommunityUploadStatus.success);
    } catch (e) {
      state = CommunityUploadState(
        status: CommunityUploadStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  void dismiss() {
    state = const CommunityUploadState();
  }
}
