import 'package:flutter_application/church_app/providers/app_config_provider.dart';
import 'package:flutter_application/church_app/services/side_drawer/bible_book_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
