import 'package:flutter_application/church_app/models/picked_image_data.dart';
import 'package:flutter_application/church_app/providers/app_config_provider.dart';
import 'package:flutter_application/church_app/services/side_drawer/bible_book_repository.dart';
import 'package:flutter_application/church_app/widgets/modals/verse_share_modal.dart'
    show
        DailyVerseCacheKey,
        fetchDailyVerseCards,
        fetchDailyVerseGenerationUsed;
import 'package:flutter_riverpod/flutter_riverpod.dart';

final dailyVerseProviderLocal =
    FutureProvider.autoDispose<Map<String, String>>((ref) async {
  final config = await ref.watch(appConfigProvider.future);
  final refData = config.dailyVerseRef;

  final repo = BibleRepository();

  return repo.getVerse(
    book: refData.book,
    chapter: refData.chapter,
    verse: refData.verse,
  );
});

/// The church's pre-generated Daily Verse cards for one language.
///
/// Read-only: members never generate these, so watching this provider costs
/// the church nothing. An empty list means the admin hasn't generated
/// today's images yet, or has changed the verse since generating — either
/// way the card shows a "not ready" message rather than offering to make
/// them. See KT Files/architecture/daily-verse-card-caching.md.
final dailyVerseCardsProvider = FutureProvider.autoDispose
    .family<List<PickedImageData>, DailyVerseCacheKey>((ref, key) async {
  final verse = await ref.watch(dailyVerseProviderLocal.future);
  final isTamil = key.language.name == 'tamil';
  return fetchDailyVerseCards(
    key: key,
    verseText: (isTamil ? verse['tamil'] : verse['english']) ?? '',
    reference:
        (isTamil ? verse['referenceTamil'] : verse['reference']) ?? '',
  );
});

/// Whether this church's one Daily Verse generation for today has been spent.
///
/// Mirrors `dailyGenerationUsed` on the server: both languages `ready` means
/// done, whatever their fingerprints, so editing the verse after a successful
/// run does not buy a second one. Studio disables its Generate button on this
/// and explains why.
///
/// Answered by the callable, not by reading the cache doc — see
/// [fetchDailyVerseGenerationUsed] for why a client-side Firestore read is
/// denied for some admins. Invalidate it after a generation to refresh.
final dailyVerseGenerationUsedProvider =
    FutureProvider.autoDispose.family<bool, DailyVerseCacheKey>(
        (ref, key) async {
  final verse = await ref.watch(dailyVerseProviderLocal.future);
  final isTamil = key.language.name == 'tamil';
  return fetchDailyVerseGenerationUsed(
    key: key,
    verseText: (isTamil ? verse['tamil'] : verse['english']) ?? '',
    reference: (isTamil ? verse['referenceTamil'] : verse['reference']) ?? '',
  );
});
