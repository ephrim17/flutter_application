import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/providers/language_provider.dart';
import 'package:flutter_application/church_app/services/side_drawer/bible_book_repository.dart';
import 'package:flutter_application/church_app/widgets/language_toggle_widget.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

class BibleChapterReaderScreen extends ConsumerStatefulWidget {
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
  ConsumerState<BibleChapterReaderScreen> createState() =>
      _BibleChapterReaderScreenState();
}

class _BibleChapterReaderScreenState
    extends ConsumerState<BibleChapterReaderScreen> {
  final repo = BibleRepository();
  late final PageController _controller;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: 0);
  }

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(chapterReaderLanguageProvider);

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
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: BibleLanguageToggle(
                  provider: chapterReaderLanguageProvider,
                ),
              ),
            ],
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

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: verses.length,
                itemBuilder: (_, verseIndex) {
                  final verse = verses[verseIndex];

                  final verseText = language == BibleLanguage.tamil
                      ? verse['text']['tamil']
                      : verse['text']['english'];

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: RichText(
                      text: TextSpan(
                        style: DefaultTextStyle.of(context)
                            .style
                            .copyWith(height: 1.4),
                        children: [
                          TextSpan(
                            text: '${verse['verse']} ',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextSpan(text: verseText),
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
