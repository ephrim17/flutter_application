import 'package:flutter_application/church_app/models/for_you_section_models/daily_verse_model.dart';
import 'package:flutter_application/church_app/providers/app_config_provider.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_provider.dart';
import 'package:flutter_application/church_app/services/for_you_section/daily_verse_repository.dart';
import 'package:flutter_application/church_app/services/side_drawer/bible_book_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final dailyVerseProvider = StreamProvider<List<DailyVerse>>((ref) {
  final repo = DailyVerseRepository(ref.read(firestoreProvider));
  return repo.watchAllActive(now: DateTime.now(), limit: 100);
});


final dailyVerseProviderLocal =
    FutureProvider<Map<String, String>>((ref) async {
  final config = await ref.watch(appConfigProvider.future);
  final refData = config.dailyVerseRef;

  final repo = BibleRepository();

  return repo.getVerse(
    book: refData.book,
    chapter: refData.chapter,
    verse: refData.verse,
  );
});
