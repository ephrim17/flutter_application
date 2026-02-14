import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/models/bible_book_model.dart';
import 'package:flutter_application/church_app/models/for_you_section_models/highlight_verse_model.dart';
import 'package:flutter_application/church_app/providers/for_you_sections/favorites_provider.dart';
import 'package:flutter_application/church_app/services/side_drawer/bible_book_repository.dart';
import 'package:flutter_application/church_app/widgets/app_bar_title_widget.dart';
import 'package:flutter_application/church_app/widgets/bible_reader_appbar.dart';
import 'package:flutter_application/church_app/widgets/bible_verse_item_widget.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BibleBookScreen extends StatelessWidget {
  const BibleBookScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: AppBarTitle(text: "Holy Bible")),
      body: ListView.builder(
        itemCount: bibleBooks.length,
        itemBuilder: (_, index) {
          final book = bibleBooks[index];
          return ListTile(
            title: Text(book.key),
            subtitle: Text(book.name),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChapterScreen(book: book),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class ChapterScreen extends StatelessWidget {
  final BibleBook book;
  final repo = BibleRepository();

  ChapterScreen({super.key, required this.book});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: repo.loadBook(book.key),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        }

        final chapters = snapshot.data!['chapters'] as List<dynamic>;

        return Scaffold(
          appBar: AppBar(
              title: Column(
            children: [
              Text(
                book.key,
                style: TextStyle(fontSize: 18),
              ),
              Text(
                book.name,
                style: TextStyle(fontSize: 10),
              ),
            ],
          )),
          body: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              childAspectRatio: 1.2,
            ),
            itemCount: chapters.length,
            itemBuilder: (_, index) {
              final chapterNo = chapters[index]['chapter'].toString();
              return InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VerseScreen(
                        book: book,
                        startChapterIndex: index,
                      ),
                    ),
                  );
                },
                child: Card(
                  child: Center(child: Text(chapterNo)),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class VerseScreen extends ConsumerStatefulWidget {
  final BibleBook book;
  final int startChapterIndex;
  final int? endChapterIndex;

  const VerseScreen({
    super.key,
    required this.book,
    required this.startChapterIndex,
    this.endChapterIndex,
  });

  @override
  ConsumerState<VerseScreen> createState() => _VerseScreenState();
}

class _VerseScreenState extends ConsumerState<VerseScreen> {
  final repo = BibleRepository();
  final Set<int> highlightedVerses = {};

  late PageController _pageController;
  String chapterIndexText = '';

  @override
  void initState() {
    super.initState();

    _pageController = PageController(
      initialPage: widget.startChapterIndex,
    );

    chapterIndexText = (widget.startChapterIndex + 1).toString();

    _loadHighlights(widget.startChapterIndex);
  }

  String _storageKey(int actualChapterIndex) =>
      'highlight_${widget.book.key}_$actualChapterIndex';

  Future<void> _loadHighlights(int actualChapterIndex) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_storageKey(actualChapterIndex));

    setState(() {
      highlightedVerses
        ..clear()
        ..addAll(stored?.map(int.parse) ?? []);
    });
  }

  Future<void> _saveHighlights(int actualChapterIndex) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _storageKey(actualChapterIndex),
      highlightedVerses.map((e) => e.toString()).toList(),
    );
  }

  Future<void> _toggleGlobalHighlight(HighlightRef refData) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList('all_highlights') ?? [];

    final key = "${refData.book}_${refData.chapter}_${refData.verse}";

    if (stored.contains(key)) {
      stored.remove(key);
    } else {
      stored.add(key);
    }

    await prefs.setStringList('all_highlights', stored);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: repo.loadBook(widget.book.key),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final allChapters = snapshot.data!['chapters'] as List<dynamic>;

        final chapters = widget.endChapterIndex != null
            ? allChapters.sublist(
                widget.startChapterIndex,
                widget.endChapterIndex! + 1,
              )
            : allChapters;

        return Scaffold(
          appBar: BibleReaderAppBar(
            title: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.book.key,
                        style: const TextStyle(fontSize: 18)),
                    Text(widget.book.name,
                        style: const TextStyle(fontSize: 10)),
                  ],
                ),
                const SizedBox(width: 10),
                Text(chapterIndexText),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: () => _share(chapters),
              ),
            ],
          ),
          body: PageView.builder(
            controller: _pageController,
            itemCount: chapters.length,
            onPageChanged: (index) {
              final actualChapterIndex =
                  widget.startChapterIndex + index;

              highlightedVerses.clear();
              _loadHighlights(actualChapterIndex);

              setState(() {
                chapterIndexText =
                    (actualChapterIndex + 1).toString();
              });
            },
            itemBuilder: (context, chapterIndex) {
              final chapter = chapters[chapterIndex];
              final verses = chapter['verses'] as List<dynamic>;

              final actualChapterIndex =
                  widget.startChapterIndex + chapterIndex;

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: verses.length,
                itemBuilder: (_, index) {
                  final verse = verses[index];
                  final isHighlighted =
                      highlightedVerses.contains(index);

                  return GestureDetector(
                    onTap: () async {
                      final verseData = verses[index];

                      final highlightRef = HighlightRef(
                        book: widget.book.key,
                        chapter: actualChapterIndex + 1,
                        verse: int.parse(
                            verseData['verse'].toString()),
                      );

                      setState(() {
                        if (highlightedVerses.contains(index)) {
                          highlightedVerses.remove(index);
                        } else {
                          highlightedVerses.add(index);
                        }
                      });

                      await _saveHighlights(actualChapterIndex);
                      await _toggleGlobalHighlight(highlightRef);

                      // 🔥 Force refresh Favorites screen
                      ref.invalidate(favoritesProvider);
                    },
                    child: Container(
                      margin:
                          const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isHighlighted
                            ? Colors.yellow
                                .withValues(alpha: 0.25)
                            : Colors.transparent,
                        borderRadius:
                            BorderRadius.circular(8),
                      ),
                      child: BibleVerseItemWidget(
                        verseNumber:
                            verse['verse'].toString(),
                        versePrimary:
                            verse['text']['tamil'],
                        verseSecondary:
                            verse['text']['english'],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  void _share(List<dynamic> chapters) {
    if (highlightedVerses.isEmpty) return;

    final currentPage =
        _pageController.page?.round() ?? 0;
    final verses =
        chapters[currentPage]['verses'] as List<dynamic>;

    final text = highlightedVerses.map((i) {
      final v = verses[i];
      return '''
${v['verse']}
${v['text']['tamil']}
${v['text']['english']}
''';
    }).join('\n');

    Share.share(text.trim());
  }
}
