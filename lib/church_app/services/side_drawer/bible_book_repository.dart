import 'dart:convert';
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
      return Map<String, dynamic>.from(json.decode(raw) as Map);
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

    final chapters = data['chapters'] as List<dynamic>;
    final chapterData = chapters[chapter - 1];
    final verses = chapterData['verses'] as List<dynamic>;
    final verseData = verses[verse - 1];

    return {
      'tamil': verseData['text']['tamil'],
      'english': verseData['text']['english'],
      'reference': '$book $chapter:$verse',
    };
  }
}

final bibleBooks = catalog.bibleBooks;
