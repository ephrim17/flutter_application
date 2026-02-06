import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/services/side_drawer/bible_book_repository.dart';

List<int> parseChapterRange(String chapters) {
  if (!chapters.contains('-')) {
    final ch = int.parse(chapters.trim());
    return [ch, ch];
  }

  final parts = chapters.split('-');
  return [
    int.parse(parts[0].trim()),
    int.parse(parts[1].trim()),
  ];
}

class BibleChapterReaderScreen extends StatefulWidget {
  final String bookKey;
  final int startChapter;
  final int endChapter;

  const BibleChapterReaderScreen({
    super.key,
    required this.bookKey,
    required this.startChapter,
    required this.endChapter,
  });

  @override
  State<BibleChapterReaderScreen> createState() =>
      _BibleChapterReaderScreenState();
}

class _BibleChapterReaderScreenState extends State<BibleChapterReaderScreen> {
  final repo = BibleRepository();
  late final PageController _controller;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _currentPage = 0;
    _controller = PageController(initialPage: 0);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: repo.loadBook(widget.bookKey),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final chapters = snapshot.data!['chapters'] as List<dynamic>;

        final visibleChapters = chapters.sublist(
          widget.startChapter - 1,
          widget.endChapter,
        );

        final currentChapter = visibleChapters[_currentPage]['chapter'];

        return Scaffold(
          appBar: AppBar(
            title: Text('${widget.bookKey} $currentChapter'),
          ),
          body: PageView.builder(
            controller: _controller,
            itemCount: visibleChapters.length,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemBuilder: (context, index) {
              final chapter = visibleChapters[index];
              final verses = chapter['verses'] as List<dynamic>;
              //final chapterNo = chapter['chapter'];

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: verses.length,
                itemBuilder: (_, verseIndex) {
                  final verse = verses[verseIndex];

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: RichText(
                      text: TextSpan(
                        style: DefaultTextStyle.of(context).style,
                        children: [
                          TextSpan(
                            text: '${verse['verse']} ',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextSpan(text: verse['text']),
                        ],
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
}
