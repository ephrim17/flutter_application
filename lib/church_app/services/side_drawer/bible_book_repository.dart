import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application/church_app/models/bible_version_model.dart';
import 'package:flutter_application/church_app/services/side_drawer/bible_catalog.dart'
    as catalog;
import 'package:flutter_application/church_app/services/side_drawer/bible_download_repository.dart';

export 'package:flutter_application/church_app/services/side_drawer/bible_catalog.dart'
    show bibleBooks;

class BibleRepository {
  static final Map<String, Future<Map<String, dynamic>>> _bookCache = {};
  final BibleDownloadRepository _downloadRepository = BibleDownloadRepository();

  Future<Map<String, dynamic>> loadBook(
    String bookKey, {
    BibleVersion? version,
    bool requireDownloaded = false,
  }) async {
    final selectedVersion =
        version ?? await _downloadRepository.selectedVersion();
    final cacheKey = '${selectedVersion.id}:$bookKey:$requireDownloaded';

    return _bookCache.putIfAbsent(cacheKey, () async {
      final raw = await _loadRawBook(
        bookKey: bookKey,
        version: selectedVersion,
        requireDownloaded: requireDownloaded,
      );
      return compute(_decodeBookJson, raw);
    });
  }

  Future<String> _loadRawBook({
    required String bookKey,
    required BibleVersion version,
    required bool requireDownloaded,
  }) async {
    if (await _downloadRepository.hasAllDownloadedFiles(version)) {
      return _downloadRepository.loadDownloadedBook(
        version: version,
        bookKey: bookKey,
      );
    }

    if (requireDownloaded) {
      throw StateError('${version.title} is not fully downloaded.');
    }

    if (version.hasStorageSource || version.hasRemoteSource) {
      return _downloadRepository.loadSourceBook(
        version: version,
        bookKey: bookKey,
      );
    }

    final assetBasePath = version.assetBasePath ?? 'assets/bible';
    final path = '$assetBasePath/$bookKey.json';
    return rootBundle.loadString(path).timeout(
          const Duration(seconds: 15),
        );
  }

  Future<Map<String, String>> getVerse({
    required String book,
    required int chapter,
    required int verse,
  }) async {
    final data = await loadBook(book);

    final chapters = data['chapters'];
    if (chapters is! List || chapter < 1 || chapter > chapters.length) {
      throw FormatException('Invalid Bible chapter: $book $chapter');
    }
    final chapterData = chapters[chapter - 1];
    if (chapterData is! Map) {
      throw FormatException('Invalid Bible chapter data: $book $chapter');
    }
    final verses = chapterData['verses'];
    if (verses is! List || verse < 1 || verse > verses.length) {
      throw FormatException('Invalid Bible verse: $book $chapter:$verse');
    }
    final verseData = verses[verse - 1];
    if (verseData is! Map || verseData['text'] is! Map) {
      throw FormatException('Invalid Bible verse data: $book $chapter:$verse');
    }
    final text = verseData['text'] as Map;

    return {
      'tamil': text['tamil']?.toString() ?? '',
      'english': text['english']?.toString() ?? '',
      'reference': '$book $chapter:$verse',
    };
  }
}

final bibleBooks = catalog.bibleBooks;

Map<String, dynamic> _decodeBookJson(String raw) {
  final decoded = json.decode(raw);
  if (decoded is! Map) {
    throw const FormatException('Bible book data must be a JSON object.');
  }
  return Map<String, dynamic>.from(decoded);
}
