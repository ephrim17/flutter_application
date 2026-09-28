import 'package:flutter/foundation.dart';

/// Which slice of a book's chapters the reader's `PageView` spans, and where
/// inside that slice it opens.
///
/// Two callers, two intents:
///
/// * The Bible reader opens at a chapter with no end bound — the reader is
///   free to swipe anywhere in the book, so the window is the **whole book**
///   and the entry chapter is just the initial page. This is what lets a
///   reader who opened Exodus 8 swipe back to Exodus 7; before, the window
///   started at the entry chapter, so page 0 was a wall.
/// * A reading plan opens a chapter *range* (e.g. "Exodus 8-10") — that range
///   is the day's assignment, so the window stays clamped to it and opens at
///   its first chapter.
@immutable
class ChapterPagingWindow {
  const ChapterPagingWindow({
    required this.firstChapterIndex,
    required this.chapterCount,
    required this.initialPage,
  });

  /// Index, within the book's full chapter list, of this window's first page.
  final int firstChapterIndex;

  /// How many chapters the window spans (the `PageView`'s item count).
  final int chapterCount;

  /// The page the reader opens on, relative to [firstChapterIndex].
  final int initialPage;

  /// Index, within the book's full chapter list, of the chapter on [page].
  int chapterIndexForPage(int page) => firstChapterIndex + page;

  /// Human-facing chapter number (1-based) of the chapter on [page].
  int chapterNumberForPage(int page) => chapterIndexForPage(page) + 1;

  /// The window's last page index, or -1 when the book has no chapters.
  int get lastPage => chapterCount - 1;
}

/// Resolves the paging window for a book of [totalChapters] chapters opened at
/// [startChapterIndex], optionally bounded above by [endChapterIndex].
///
/// Every input is clamped rather than trusted: chapter counts differ between
/// Bible versions, and a reading plan's stored range can outlive a version
/// switch, so an out-of-range index must degrade to a readable chapter instead
/// of throwing out of `sublist`.
ChapterPagingWindow resolveChapterPagingWindow({
  required int totalChapters,
  required int startChapterIndex,
  int? endChapterIndex,
}) {
  if (totalChapters <= 0) {
    return const ChapterPagingWindow(
      firstChapterIndex: 0,
      chapterCount: 0,
      initialPage: 0,
    );
  }
  final lastIndex = totalChapters - 1;
  final start = startChapterIndex.clamp(0, lastIndex);
  if (endChapterIndex == null) {
    return ChapterPagingWindow(
      firstChapterIndex: 0,
      chapterCount: totalChapters,
      initialPage: start,
    );
  }
  final end = endChapterIndex.clamp(start, lastIndex);
  return ChapterPagingWindow(
    firstChapterIndex: start,
    chapterCount: end - start + 1,
    initialPage: 0,
  );
}
