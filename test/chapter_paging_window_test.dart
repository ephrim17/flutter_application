import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application/church_app/helpers/chapter_paging_window.dart';

/// Exodus has 40 chapters; entering at "chapter 8" means index 7.
const _exodusChapters = 40;
const _exodus8 = 7;

void main() {
  group('Bible reader (no end bound)', () {
    test('reported repro: open Exodus 8, forward 2, back 3 lands on Exodus 7',
        () {
      final window = resolveChapterPagingWindow(
        totalChapters: _exodusChapters,
        startChapterIndex: _exodus8,
      );

      var page = window.initialPage;
      expect(window.chapterNumberForPage(page), 8);

      page += 1;
      expect(window.chapterNumberForPage(page), 9);
      page += 1;
      expect(window.chapterNumberForPage(page), 10);

      page -= 1;
      expect(window.chapterNumberForPage(page), 9);
      page -= 1;
      expect(window.chapterNumberForPage(page), 8);
      // The bug: this third swipe back used to be impossible, because the
      // window started at the entry chapter and page 0 was a wall.
      page -= 1;
      expect(page, greaterThanOrEqualTo(0));
      expect(window.chapterNumberForPage(page), 7);
    });

    test('window spans the whole book, opening on the entry chapter', () {
      final window = resolveChapterPagingWindow(
        totalChapters: _exodusChapters,
        startChapterIndex: _exodus8,
      );

      expect(window.firstChapterIndex, 0);
      expect(window.chapterCount, _exodusChapters);
      expect(window.initialPage, _exodus8);
    });

    test('can swipe back to chapter 1 and forward to the last chapter', () {
      final window = resolveChapterPagingWindow(
        totalChapters: _exodusChapters,
        startChapterIndex: _exodus8,
      );

      expect(window.chapterNumberForPage(0), 1);
      expect(window.chapterNumberForPage(window.lastPage), _exodusChapters);
    });

    test('entering at chapter 1 still has no page before it', () {
      final window = resolveChapterPagingWindow(
        totalChapters: _exodusChapters,
        startChapterIndex: 0,
      );

      expect(window.initialPage, 0);
      expect(window.chapterNumberForPage(0), 1);
    });

    test('entering at the last chapter has no page after it', () {
      final window = resolveChapterPagingWindow(
        totalChapters: _exodusChapters,
        startChapterIndex: _exodusChapters - 1,
      );

      expect(window.initialPage, window.lastPage);
      expect(window.chapterNumberForPage(window.lastPage), _exodusChapters);
    });

    test('every chapter of every book size opens on the chapter asked for', () {
      // Covers the single-chapter books (Obadiah, Philemon, Jude, 2-3 John)
      // through the longest (Psalms, 150) — the fix has to hold for all of
      // them, not just Exodus.
      for (final total in <int>[1, 4, 40, 66, 150]) {
        for (var start = 0; start < total; start++) {
          final window = resolveChapterPagingWindow(
            totalChapters: total,
            startChapterIndex: start,
          );
          expect(window.chapterCount, total, reason: 'total=$total');
          expect(
            window.chapterNumberForPage(window.initialPage),
            start + 1,
            reason: 'total=$total start=$start',
          );
          expect(window.chapterNumberForPage(0), 1, reason: 'total=$total');
          expect(
            window.chapterNumberForPage(window.lastPage),
            total,
            reason: 'total=$total',
          );
        }
      }
    });
  });

  group('Reading plan (bounded range)', () {
    test('stays clamped to the plan range and opens at its first chapter', () {
      // "Exodus 8-10": the day's assignment, not a free-reading entry point.
      final window = resolveChapterPagingWindow(
        totalChapters: _exodusChapters,
        startChapterIndex: _exodus8,
        endChapterIndex: 9,
      );

      expect(window.firstChapterIndex, _exodus8);
      expect(window.chapterCount, 3);
      expect(window.initialPage, 0);
      expect(window.chapterNumberForPage(0), 8);
      expect(window.chapterNumberForPage(window.lastPage), 10);
    });

    test('a single-chapter range is one page', () {
      final window = resolveChapterPagingWindow(
        totalChapters: _exodusChapters,
        startChapterIndex: _exodus8,
        endChapterIndex: _exodus8,
      );

      expect(window.chapterCount, 1);
      expect(window.chapterNumberForPage(0), 8);
    });
  });

  group('Out-of-range input is clamped, never thrown', () {
    test('a start past the end of the book falls back to the last chapter', () {
      final window = resolveChapterPagingWindow(
        totalChapters: _exodusChapters,
        startChapterIndex: 99,
      );

      expect(window.initialPage, _exodusChapters - 1);
      expect(window.chapterNumberForPage(window.initialPage), _exodusChapters);
    });

    test('a negative start falls back to chapter 1', () {
      final window = resolveChapterPagingWindow(
        totalChapters: _exodusChapters,
        startChapterIndex: -3,
      );

      expect(window.initialPage, 0);
      expect(window.chapterNumberForPage(0), 1);
    });

    test('a plan range running past the book clamps to the last chapter', () {
      // A stored plan range can outlive a switch to a version with fewer
      // chapters — this must not throw out of sublist.
      final window = resolveChapterPagingWindow(
        totalChapters: 10,
        startChapterIndex: 8,
        endChapterIndex: 40,
      );

      expect(window.firstChapterIndex, 8);
      expect(window.chapterCount, 2);
      expect(window.chapterNumberForPage(window.lastPage), 10);
    });

    test('an inverted plan range collapses to a single chapter', () {
      final window = resolveChapterPagingWindow(
        totalChapters: _exodusChapters,
        startChapterIndex: 9,
        endChapterIndex: 2,
      );

      expect(window.chapterCount, 1);
      expect(window.chapterNumberForPage(0), 10);
    });

    test('an empty book yields an empty window instead of throwing', () {
      final window = resolveChapterPagingWindow(
        totalChapters: 0,
        startChapterIndex: 3,
      );

      expect(window.chapterCount, 0);
      expect(window.initialPage, 0);
      expect(window.lastPage, -1);
    });
  });

  group('Swiping a PageView wired like the reader', () {
    // The reader's own screen builds its repository directly, so mounting it
    // here would need the Bible assets and download layer. This mirrors the
    // exact wiring instead — window -> itemCount/initialPage/labels — so the
    // swipe directions and page-change math are exercised for real.
    testWidgets('swipe forward twice then back three times reaches Exodus 7',
        (tester) async {
      final window = resolveChapterPagingWindow(
        totalChapters: _exodusChapters,
        startChapterIndex: _exodus8,
      );
      final controller = PageController(initialPage: window.initialPage);
      addTearDown(controller.dispose);
      var currentChapter = window.chapterNumberForPage(window.initialPage);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PageView.builder(
              controller: controller,
              itemCount: window.chapterCount,
              onPageChanged: (page) =>
                  currentChapter = window.chapterNumberForPage(page),
              itemBuilder: (_, page) => Center(
                child: Text('Chapter ${window.chapterNumberForPage(page)}'),
              ),
            ),
          ),
        ),
      );

      // Fling rather than drag: a half-width drag sits exactly on the
      // snap threshold and won't reliably advance a page.
      Future<void> swipeForward() async {
        await tester.fling(find.byType(PageView), const Offset(-600, 0), 1000);
        await tester.pumpAndSettle();
      }

      Future<void> swipeBack() async {
        await tester.fling(find.byType(PageView), const Offset(600, 0), 1000);
        await tester.pumpAndSettle();
      }

      expect(find.text('Chapter 8'), findsOneWidget);

      await swipeForward();
      expect(find.text('Chapter 9'), findsOneWidget);
      await swipeForward();
      expect(find.text('Chapter 10'), findsOneWidget);

      await swipeBack();
      expect(find.text('Chapter 9'), findsOneWidget);
      await swipeBack();
      expect(find.text('Chapter 8'), findsOneWidget);
      await swipeBack();
      expect(find.text('Chapter 7'), findsOneWidget);
      expect(currentChapter, 7);
    });

    test('a plan range cannot be swiped out of', () {
      final window = resolveChapterPagingWindow(
        totalChapters: _exodusChapters,
        startChapterIndex: _exodus8,
        endChapterIndex: 9,
      );

      // No page exists for Exodus 7 or 11 — the range is the whole window.
      expect(window.chapterCount, 3);
      expect(
        List.generate(
          window.chapterCount,
          window.chapterNumberForPage,
        ),
        <int>[8, 9, 10],
      );
    });
  });
}
