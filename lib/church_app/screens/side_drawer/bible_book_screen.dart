import 'dart:ffi';

import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/models/bible_book_model.dart';
import 'package:flutter_application/church_app/services/side_drawer/bible_book_repository.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BibleBookScreen extends StatelessWidget {
  const BibleBookScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Holy Bible')),
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
          appBar: AppBar(title: Column(
            children: [
              Text(book.key, style: TextStyle(fontSize: 18),),
              Text(book.name, style: TextStyle(fontSize: 10),),
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
              final chapterNo = chapters[index]['chapter'];
              return InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VerseScreen(
                        book: book,
                        chapterIndex: index,
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

class VerseScreen extends StatefulWidget {
  final BibleBook book;
  final int chapterIndex;

  const VerseScreen({
    super.key,
    required this.book,
    required this.chapterIndex,
  });

  @override
  State<VerseScreen> createState() => _VerseScreenState();
}

class _VerseScreenState extends State<VerseScreen> {
  final repo = BibleRepository();
  final Set<int> highlightedVerses = {};
  var chapterIndex = "";
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController =
        PageController(initialPage: widget.chapterIndex);
    _loadHighlights(widget.chapterIndex);
    setState(() {
        chapterIndex = (widget.chapterIndex+1).toString();
      });
  }

  // 🔹 Storage key
  String _storageKey(int chapterIndex) =>
      'highlight_${widget.book.key}_$chapterIndex';

  // 🔹 Load highlights
  Future<void> _loadHighlights(int chapterIndex) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_storageKey(chapterIndex));

    if (stored != null) {
      setState(() {
        highlightedVerses
          ..clear()
          ..addAll(stored.map(int.parse));
      });
    }
  }

  // 🔹 Save highlights
  Future<void> _saveHighlights(int chapterIndex) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _storageKey(chapterIndex),
      highlightedVerses.map((e) => e.toString()).toList(),
    );
  }

  void setChapterIndex(String index) {
    setState(() {
      chapterIndex = index;
    });
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

        final chapters =
            snapshot.data!['chapters'] as List<dynamic>;

        return Scaffold(
          appBar: AppBar(
            title: Row(
            children: [
              Column(
                children: [
                  Text(widget.book.key, style: TextStyle(fontSize: 18),),
                  Text(widget.book.name, style: TextStyle(fontSize: 10),),
                ],
              ),
              const SizedBox(width: 10,),
              Text(chapterIndex)
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
              highlightedVerses.clear();
              _loadHighlights(index);
              setChapterIndex((index + 1).toString());
            },
            itemBuilder: (context, chapterIndex) {
              final chapter = chapters[chapterIndex];
              final verses =
                  chapter['verses'] as List<dynamic>;
              final chapterNo = chapter['chapter'];

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: verses.length,
                itemBuilder: (_, index) {
                  final verse = verses[index];
                  final isHighlighted =
                      highlightedVerses.contains(index);

                  return GestureDetector(
                    onTap: () async {
                      setState(() {
                        isHighlighted
                            ? highlightedVerses.remove(index)
                            : highlightedVerses.add(index);
                      });
                      await _saveHighlights(chapterIndex);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isHighlighted
                            ? Colors.yellow
                                .withValues(alpha: 0.3)
                            : Colors.transparent,
                        borderRadius:
                            BorderRadius.circular(8),
                      ),
                      child: RichText(
                        text: TextSpan(
                          style: DefaultTextStyle.of(context)
                              .style,
                          children: [
                            TextSpan(
                              text:
                                  '${verse['verse']} ',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextSpan(text: verse['text']),
                          ],
                        ),
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

    final currentPage = _pageController.page?.round() ?? 0;
    final verses =
        chapters[currentPage]['verses'] as List<dynamic>;

    final text = highlightedVerses
        .map((i) =>
            '${verses[i]['verse']} ${verses[i]['text']}')
        .join('\n\n');

    Share.share(text);
  }
}
