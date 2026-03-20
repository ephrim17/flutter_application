import 'package:flutter_application/church_app/models/picked_image_data.dart';
import 'package:flutter_application/church_app/models/church_model.dart';
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

  Future<void> createPost({
    required String title,
    required String description,
    PickedImageData? imageFile,
    bool sharePersonalDetails = false,
    bool isGlobal = false,
  }) async {
    final churchAsync = _ref.read(currentChurchIdProvider);
    final churchId = churchAsync.value;
    final userAsync = _ref.read(getCurrentUserProvider);

    final firebaseUser = _ref.watch(firebaseAuthProvider).currentUser;
    final currentUid = firebaseUser?.uid;

    final user = userAsync.value;

    if (user == null) return;
    if (currentUid == null) return;

    state = const AsyncLoading();

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

      await _repository.createPost(
        churchId: churchId,
        userId: currentUid,
        userName: user.name,
        userPhoto: null,
        churchName: church?.name,
        churchPastorName: church?.pastorName,
        sharePersonalDetails: isGlobal && sharePersonalDetails,
        userCategory: user.category,
        userAddress: user.address,
        userEmail: user.email,
        userPhone: user.phone,
        userDob: user.dob,
        title: title,
        description: description,
        imageFile: imageFile,
        isGlobal: isGlobal,
      );
    });
  }

  Future<void> updatePost({
    required String postId,
    required String title,
    required String description,
    PickedImageData? imageFile,
    String? existingImageUrl,
    bool? sharePersonalDetails,
    bool isGlobal = false,
  }) async {
    final churchAsync = _ref.read(currentChurchIdProvider);
    final churchId = churchAsync.value;

    if (!isGlobal && churchId == null) return;

    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      final user = _ref.read(getCurrentUserProvider).value;
      await _repository.updatePost(
        churchId: churchId,
        postId: postId,
        title: title,
        description: description,
        imageFile: imageFile,
        existingImageUrl: existingImageUrl,
        sharePersonalDetails: isGlobal ? (sharePersonalDetails ?? false) : null,
        userCategory: user?.category,
        userAddress: user?.address,
        userEmail: user?.email,
        userPhone: user?.phone,
        userDob: user?.dob,
        isGlobal: isGlobal,
      );
    });
  }

  Future<void> deletePost({
    required String postId,
    String? imageUrl,
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
        isGlobal: isGlobal,
      );
    });
  }
}

PickedImageData? selectedImage;
final picker = ImagePicker();
