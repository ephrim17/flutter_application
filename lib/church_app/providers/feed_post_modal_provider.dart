import 'dart:io';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
import 'package:flutter_application/church_app/providers/church_provider.dart';
import 'package:flutter_application/church_app/providers/feeds_provider.dart';
import 'package:flutter_application/church_app/providers/user_provider.dart';
import 'package:flutter_application/church_app/services/feed_repository.dart';
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
      await _repository.createPost(
        churchId: churchId!,
        userId: currentUid,
        userName: user.name,
        title: title,
        description: description,
        imageFile: selectedImage,
      );
    });
  }

  Future<void> updatePost({
    required String postId,
    required String title,
    required String description,
    File? imageFile,
    String? existingImageUrl,
  }) async {
    final churchAsync = _ref.read(currentChurchIdProvider);
    final churchId = churchAsync.value;

    if (churchId == null) return;

    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      await _repository.updatePost(
        churchId: churchId,
        postId: postId,
        title: title,
        description: description,
        imageFile: imageFile,
        existingImageUrl: existingImageUrl,
      );
    });
  }
}

File? selectedImage;
final picker = ImagePicker();
