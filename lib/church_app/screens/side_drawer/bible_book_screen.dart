import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/widgets/app_loading_indicator.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/models/bible_book_model.dart';
import 'package:flutter_application/church_app/models/bible_version_model.dart';
import 'package:flutter_application/church_app/providers/for_you_sections/favorites_provider.dart'
    show favoritesProvider, toggleGlobalHighlight;
import 'package:flutter_application/church_app/services/side_drawer/bible_book_repository.dart';
import 'package:flutter_application/church_app/widgets/app_bar_title_widget.dart';
import 'package:flutter_application/church_app/widgets/bible_reader_appbar.dart';
import 'package:flutter_application/church_app/widgets/bible_verse_item_widget.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

class BibleBookScreen extends StatelessWidget {
  const BibleBookScreen({
    super.key,
    required this.version,
    this.requireDownloaded = true,
  });

  final BibleVersion version;
  final bool requireDownloaded;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: AppBarTitle(
          text: context.t('bible.title', fallback: 'Holy Bible'),
        ),
      ),
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
                  builder: (_) => ChapterScreen(
                    book: book,
                    version: version,
                    requireDownloaded: requireDownloaded,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class ChapterScreen extends StatefulWidget {
  const ChapterScreen({
    super.key,
    required this.book,
    required this.version,
    this.requireDownloaded = true,
  });

  final BibleBook book;
  final BibleVersion version;
  final bool requireDownloaded;

  @override
  State<ChapterScreen> createState() => _ChapterScreenState();
}

class _ChapterScreenState extends State<ChapterScreen> {
  final BibleRepository _repo = BibleRepository();
  late final Future<Map<String, dynamic>> _bookFuture;

  @override
  void initState() {
    super.initState();
    _bookFuture = _repo.loadBook(
      widget.book.key,
      version: widget.version,
      requireDownloaded: widget.requireDownloaded,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _bookFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: AppLoadingIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text(
                "${context.t('common.error_prefix', fallback: 'Error')}: ${snapshot.error}",
              ),
            ),
          );
        }

        final chapters = snapshot.data!['chapters'] as List<dynamic>;

        return Scaffold(
          appBar: AppBar(
              title: Column(
            children: [
              Text(
                widget.book.key,
                style: TextStyle(fontSize: 18),
              ),
              Text(
                widget.book.name,
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
                        book: widget.book,
                        version: widget.version,
                        requireDownloaded: widget.requireDownloaded,
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
  final BibleVersion? version;
  final bool requireDownloaded;
  final int startChapterIndex;
  final int? endChapterIndex;

  const VerseScreen({
    super.key,
    required this.book,
    this.version,
    this.requireDownloaded = false,
    required this.startChapterIndex,
    this.endChapterIndex,
  });

  @override
  ConsumerState<VerseScreen> createState() => _VerseScreenState();
}

class _VerseScreenState extends ConsumerState<VerseScreen> {
  final repo = BibleRepository();

  late PageController _pageController;
  late final Future<Map<String, dynamic>> _bookFuture;
  String chapterIndexText = '';

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: 0,
    );
    _bookFuture = repo.loadBook(
      widget.book.key,
      version: widget.version,
      requireDownloaded: widget.requireDownloaded,
    );
    chapterIndexText = (widget.startChapterIndex + 1).toString();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _bookFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: AppLoadingIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: BibleReaderAppBar(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.book.key, style: const TextStyle(fontSize: 18)),
                  Text(
                    widget.book.name,
                    style: const TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  "${context.t('common.error_prefix', fallback: 'Error')}: ${snapshot.error}",
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return Scaffold(
            appBar: BibleReaderAppBar(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.book.key, style: const TextStyle(fontSize: 18)),
                  Text(
                    widget.book.name,
                    style: const TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ),
            body: Center(
              child: Text(
                context.t(
                  'common.no_data',
                  fallback: 'No data found',
                ),
              ),
            ),
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

              final actualChapterIndex =
                  widget.startChapterIndex + chapterIndex;

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: verses.length,
                itemBuilder: (_, index) {
                  final verse = verses[index];
                  final reference =
                      "${widget.book.key} ${actualChapterIndex + 1}:${verse['verse']}";
                  final isHighlighted = highlights
                      .any((v) => (v['reference'] ?? '') == reference);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isHighlighted
                          ? Colors.yellow.withValues(alpha: 0.25)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              await toggleGlobalHighlight(
                                widget.book.key,
                                actualChapterIndex + 1,
                                int.parse(verse['verse'].toString()),
                              );
                              ref.invalidate(favoritesProvider);
                            },
                            child: BibleVerseItemWidget(
                              verseNumber: verse['verse'].toString(),
                              versePrimary: verse['text']['tamil'],
                              verseSecondary: verse['text']['english'],
                            ),
                          ),
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
        (vv) => "$chapterIndexText:${vv['verse']}" == reference.split(' ').last,
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
