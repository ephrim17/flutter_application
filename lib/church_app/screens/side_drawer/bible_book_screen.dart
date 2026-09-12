import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/widgets/app_loading_indicator.dart';
import 'package:flutter_application/church_app/widgets/app_modal_bottom_sheet.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/models/bible_book_model.dart';
import 'package:flutter_application/church_app/models/bible_version_model.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
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
          text: context.t('bible.title'),
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
                "${context.t('common.error_prefix')}: ${snapshot.error}",
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
  void dispose() {
    _pageController.dispose();
    super.dispose();
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
                  "${context.t('common.error_prefix')}: ${snapshot.error}",
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
                context.t('common.no_data'),
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
                icon: const Icon(Icons.auto_awesome_rounded),
                tooltip: context.t('ui.bible_reader_appbar.ai_summary'),
                onPressed: () => _summarizeChapter(context, chapters),
              ),
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
                          child: GestureDetector(
                            onLongPressStart: (details) => _showVerseMenu(
                              context,
                              details.globalPosition,
                              reference: reference,
                              tamilText: verse['text']['tamil'],
                              englishText: verse['text']['english'],
                              isHighlighted: isHighlighted,
                              onToggleHighlight: () async {
                                await toggleGlobalHighlight(
                                  widget.book.key,
                                  actualChapterIndex + 1,
                                  int.parse(verse['verse'].toString()),
                                  firestore: ref.read(firestoreProvider),
                                  uid: ref
                                      .read(firebaseAuthProvider)
                                      .currentUser
                                      ?.uid,
                                );
                                ref.invalidate(favoritesProvider);
                              },
                            ),
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

  Future<void> _summarizeChapter(
    BuildContext context,
    List<dynamic> chapters,
  ) async {
    final currentPage =
        _pageController.hasClients ? (_pageController.page?.round() ?? 0) : 0;
    final verses = chapters[currentPage]['verses'] as List<dynamic>;
    final tamilText = verses
        .map((v) => "${v['verse']}. ${v['text']['tamil']}")
        .join('\n');
    final englishText = verses
        .map((v) => "${v['verse']}. ${v['text']['english']}")
        .join('\n');
    final reference = '${widget.book.key} $chapterIndexText';
    await _requestSummary(
      context,
      mode: 'chapter',
      tamilText: tamilText,
      englishText: englishText,
      reference: reference,
    );
  }

  Future<void> _showVerseMenu(
    BuildContext context,
    Offset position, {
    required String reference,
    required String tamilText,
    required String englishText,
    required bool isHighlighted,
    required VoidCallback onToggleHighlight,
  }) async {
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: [
        PopupMenuItem(
          value: 'highlight',
          child: Row(
            children: [
              Icon(
                isHighlighted
                    ? Icons.bookmark_remove_outlined
                    : Icons.bookmark_add_outlined,
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                isHighlighted
                    ? context.t('ui.bible_reader_appbar.remove_highlight')
                    : context.t('ui.bible_reader_appbar.add_highlight'),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'summarize',
          child: Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, size: 20),
              const SizedBox(width: 10),
              Text(context.t('ui.bible_reader_appbar.summarize_with_ai')),
            ],
          ),
        ),
      ],
    );
    if (selected == 'highlight') {
      onToggleHighlight();
    } else if (selected == 'summarize' && context.mounted) {
      await _requestSummary(
        context,
        mode: 'verse',
        tamilText: tamilText,
        englishText: englishText,
        reference: reference,
      );
    }
  }

  Future<void> _requestSummary(
    BuildContext context, {
    required String mode,
    required String tamilText,
    required String englishText,
    required String reference,
  }) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Text(context.t('ui.bible_reader_appbar.summarizing')),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final result = await FirebaseFunctions.instanceFor(
        region: 'us-central1',
      ).httpsCallable('summarizeBibleContent').call<Map<String, dynamic>>({
        'mode': mode,
        'tamilText': tamilText,
        'englishText': englishText,
        'reference': reference,
      });
      if (!context.mounted) return;
      Navigator.of(context).pop();
      final tamil = result.data['tamil'] as String? ?? '';
      final english = result.data['english'] as String? ?? '';
      if (!context.mounted) return;
      _showSummarySheet(
        context,
        reference: reference,
        tamil: tamil,
        english: english,
      );
    } on FirebaseFunctionsException catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop();
      final key = e.message == 'quota-exceeded'
          ? 'ui.bible_reader_appbar.summary_quota_exceeded'
          : 'ui.bible_reader_appbar.summary_failed';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t(key))),
      );
    } catch (_) {
      if (!context.mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t('ui.bible_reader_appbar.summary_failed')),
        ),
      );
    }
  }

  void _showSummarySheet(
    BuildContext context, {
    required String reference,
    required String tamil,
    required String english,
  }) {
    showAppModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome_rounded),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      reference,
                      style: Theme.of(sheetContext)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (tamil.isNotEmpty) ...[
                Text(
                  tamil,
                  style: Theme.of(sheetContext)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(height: 1.5),
                ),
                const SizedBox(height: 16),
              ],
              if (english.isNotEmpty)
                Text(
                  english,
                  style: Theme.of(sheetContext)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(height: 1.5),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
