import 'package:flutter_application/church_app/models/picked_image_data.dart';
import 'package:flutter_application/church_app/models/church_model.dart';
import 'package:flutter_application/church_app/models/feed_model.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
import 'package:flutter_application/church_app/providers/church_provider.dart';
import 'package:flutter_application/church_app/providers/feeds_provider.dart';
import 'package:flutter_application/church_app/providers/user_provider.dart';
import 'package:flutter_application/church_app/services/feed_repository.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_paths.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hooks_riverpod/legacy.dart';
import 'package:image_picker/image_picker.dart';

final feedPostModalControllerProvider =
    StateNotifierProvider<FeedController, AsyncValue<void>>(
  (ref) => FeedController(
    ref.read(feedRepositoryProvider),
    ref,
  ),
);

class FeedController extends StateNotifier<AsyncValue<void>> {
  final FeedRepository _repository;
  final Ref _ref;

  FeedController(this._repository, this._ref) : super(const AsyncData(null));

  Future<FeedPost?> createPost({
    required String title,
    required String description,
    List<PickedImageData> imageFiles = const [],
    bool sharePersonalDetails = false,
    bool isGlobal = false,
  }) async {
    final churchAsync = _ref.read(currentChurchIdProvider);
    final churchId = churchAsync.value;
    final identity = _ref.read(userIdentityProvider).value;
    final membership = _ref.read(currentMembershipProvider).value;

    final firebaseUser = _ref.watch(firebaseAuthProvider).currentUser;
    final currentUid = firebaseUser?.uid;

    if (identity == null) return null;
    if (currentUid == null) return null;

    state = const AsyncLoading();

    FeedPost? createdPost;
    state = await AsyncValue.guard(() async {
      Church? church;
      if (churchId != null) {
        final churchDoc = await FirestorePaths.churchDoc(
                _ref.read(firestoreProvider), churchId)
            .get();
        if (churchDoc.exists) {
          final data = churchDoc.data() as Map<String, dynamic>? ?? {};
          church = Church.fromFirestore(churchDoc.id, data);
        }
      }

      createdPost = await _repository.createPost(
        churchId: churchId,
        userId: currentUid,
        userName: identity.name,
        userPhoto: identity.profilePhotoUrl,
        churchName: church?.name,
        churchPastorName: church?.pastorName,
        sharePersonalDetails: isGlobal && sharePersonalDetails,
        userCategory: membership?.category ?? '',
        userAddress: identity.address,
        userEmail: identity.email,
        userPhone: identity.phone,
        userDob: identity.dob,
        title: title,
        description: description,
        imageFiles: imageFiles,
        isGlobal: isGlobal,
      );
    });
    return createdPost;
  }

  Future<void> updatePost({
    required String postId,
    required DateTime createdAt,
    required String title,
    required String description,
    PickedImageData? imageFile,
    String? existingImageUrl,
    bool? sharePersonalDetails,
    bool isGlobal = false,
  }) async {
    if (DateTime.now().isAfter(createdAt.add(FeedPost.editWindow))) {
      throw const FeedEditWindowExpiredException();
    }

    final churchAsync = _ref.read(currentChurchIdProvider);
    final churchId = churchAsync.value;

    if (!isGlobal && churchId == null) return;

    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      final identity = _ref.read(userIdentityProvider).value;
      final membership = _ref.read(currentMembershipProvider).value;
      await _repository.updatePost(
        churchId: churchId,
        postId: postId,
        title: title,
        description: description,
        imageFile: imageFile,
        existingImageUrl: existingImageUrl,
        sharePersonalDetails: isGlobal ? (sharePersonalDetails ?? false) : null,
        userCategory: membership?.category,
        userAddress: identity?.address,
        userEmail: identity?.email,
        userPhone: identity?.phone,
        userDob: identity?.dob,
        isGlobal: isGlobal,
      );
    });
  }

  Future<void> deletePost({
    required String postId,
    String? imageUrl,
    List<String> imageUrls = const [],
    bool isGlobal = false,
  }) async {
    final churchAsync = _ref.read(currentChurchIdProvider);
    final churchId = churchAsync.value;

    if (!isGlobal && churchId == null) return;

    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      await _repository.deletePost(
        churchId: churchId,
        postId: postId,
        imageUrl: imageUrl,
        imageUrls: imageUrls,
        isGlobal: isGlobal,
      );
    });
  }

}

class FeedEditWindowExpiredException implements Exception {
  const FeedEditWindowExpiredException();
}

final picker = ImagePicker();
