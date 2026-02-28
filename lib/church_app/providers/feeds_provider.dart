import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application/church_app/models/feed_model.dart';
import 'package:flutter_application/church_app/providers/church_provider.dart';
import 'package:flutter_application/church_app/services/feed_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final feedRepositoryProvider = Provider(
  (ref) => FeedRepository(FirebaseFirestore.instance),
);

final feedStreamProvider =
    StreamProvider.autoDispose<List<FeedPost>>((ref) {

  final churchAsync = ref.watch(currentChurchIdProvider);

  if (!churchAsync.hasValue) {
    return const Stream.empty();
  }

  final churchId = churchAsync.value!;

  return ref
      .watch(feedRepositoryProvider)
      .watchFeed(churchId);
});