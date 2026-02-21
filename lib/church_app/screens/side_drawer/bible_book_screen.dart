import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/models/bible_book_model.dart';
import 'package:flutter_application/church_app/providers/for_you_sections/favorites_provider.dart' show favoritesProvider, toggleGlobalHighlight;
import 'package:flutter_application/church_app/services/side_drawer/bible_book_repository.dart';
import 'package:flutter_application/church_app/widgets/app_bar_title_widget.dart';
import 'package:flutter_application/church_app/widgets/bible_reader_appbar.dart';
import 'package:flutter_application/church_app/widgets/bible_verse_item_widget.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

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

  late PageController _pageController;
  String chapterIndexText = '';

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: 0,
    );
    chapterIndexText = (widget.startChapterIndex + 1).toString();
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
            : allChapters.sublist(widget.startChapterIndex);

        final highlights = ref.watch(favoritesProvider).maybeWhen(
          data: (h) => h,
          orElse: () => [],
        );

        return Scaffold(
          appBar: BibleReaderAppBar(
            title: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.book.key, style: const TextStyle(fontSize: 18)),
                    Text(widget.book.name,
                        style: const TextStyle(fontSize: 10)),
                  ],
                ),
                const SizedBox(width: 10),
                Text(
                  chapterIndexText,
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: () => _share(chapters, highlights),
              ),
            ],
          ),
          body: PageView.builder(
            controller: _pageController,
            itemCount: chapters.length,
            onPageChanged: (index) {
              final actualChapterIndex = widget.startChapterIndex + index;
              setState(() {
                chapterIndexText = (actualChapterIndex + 1).toString();
              });
            },
            itemBuilder: (context, chapterIndex) {
              final chapter = chapters[chapterIndex];
              final verses = chapter['verses'] as List<dynamic>;

              final actualChapterIndex = widget.startChapterIndex + chapterIndex;

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: verses.length,
                itemBuilder: (_, index) {
                  final verse = verses[index];
                  final reference = "${widget.book.key} ${actualChapterIndex + 1}:${verse['verse']}";
                  final isHighlighted = highlights.any((v) => (v['reference'] ?? '') == reference);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isHighlighted
                          ? Colors.yellow.withOpacity(0.25)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: BibleVerseItemWidget(
                            verseNumber: verse['verse'].toString(),
                            versePrimary: verse['text']['tamil'],
                            verseSecondary: verse['text']['english'],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            isHighlighted ? Icons.favorite : Icons.favorite_border,
                            color: isHighlighted ? Colors.red : Colors.grey,
                          ),
                          onPressed: () async {
                            await toggleGlobalHighlight(
                              widget.book.key,
                              actualChapterIndex + 1,
                              int.parse(verse['verse'].toString()),
                            );
                            ref.invalidate(favoritesProvider);
                          },
                        ),
                      ],
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

  void _share(List<dynamic> chapters, List<dynamic> highlights) {
    if (highlights.isEmpty) return;
    final currentPage = _pageController.page?.round() ?? 0;
    final verses = chapters[currentPage]['verses'] as List<dynamic>;
    final text = highlights.map((v) {
      final reference = v['reference'] ?? '';
      final verse = verses.firstWhere(
        (vv) => "${widget.book.key} ${chapterIndexText}:${vv['verse']}" == reference,
        orElse: () => null,
      );
      if (verse == null) return '';
      return '''
${widget.book.key} ${widget.book.name}: $chapterIndexText:${verse['verse']}

${verse['text']['tamil']}
${verse['text']['english']}
''';
    }).join('\n');
    if (text.trim().isNotEmpty) {
      Share.share(text.trim());
    }
  }
}
