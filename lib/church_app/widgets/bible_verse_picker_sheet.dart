import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/widgets/app_modal_bottom_sheet.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';
import 'package:flutter_application/church_app/models/bible_book_model.dart';
import 'package:flutter_application/church_app/services/side_drawer/bible_book_repository.dart';

class BibleVerseSelection {
  const BibleVerseSelection({
    required this.book,
    required this.chapter,
    required this.verse,
  });

  final String book;
  final int chapter;
  final int verse;
}

Future<void> showBibleVersePickerSheet(
  BuildContext context, {
  required String title,
  required String initialBook,
  required int initialChapter,
  required int initialVerse,
  required Future<void> Function({
    required String book,
    required int chapter,
    required int verse,
  }) onSave,
}) {
  return showAppModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _BibleVersePickerSheet(
      title: title,
      initialBook: initialBook,
      initialChapter: initialChapter,
      initialVerse: initialVerse,
      onSave: onSave,
    ),
  );
}

class _BibleVersePickerSheet extends StatefulWidget {
  const _BibleVersePickerSheet({
    required this.title,
    required this.initialBook,
    required this.initialChapter,
    required this.initialVerse,
    required this.onSave,
  });

  final String title;
  final String initialBook;
  final int initialChapter;
  final int initialVerse;
  final Future<void> Function({
    required String book,
    required int chapter,
    required int verse,
  }) onSave;

  @override
  State<_BibleVersePickerSheet> createState() => _BibleVersePickerSheetState();
}

class _BibleVersePickerSheetState extends State<_BibleVersePickerSheet> {
  final BibleRepository _bibleRepository = BibleRepository();

  late BibleBook _selectedBook;
  late int _selectedChapter;
  late int _selectedVerse;
  int _chapterCount = 1;
  int _verseCount = 1;
  bool _isLoadingStructure = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedBook = bibleBooks.firstWhere(
      (book) => book.key == widget.initialBook,
      orElse: () => bibleBooks.first,
    );
    _selectedChapter = widget.initialChapter;
    _selectedVerse = widget.initialVerse;
    _loadStructure();
  }

  Future<void> _loadStructure() async {
    setState(() {
      _isLoadingStructure = true;
    });

    final data = await _bibleRepository.loadBook(_selectedBook.key);
    final chapters = (data['chapters'] as List<dynamic>? ?? const []).toList();
    final safeChapterCount = chapters.isEmpty ? 1 : chapters.length;
    final safeChapter = _selectedChapter.clamp(1, safeChapterCount);
    final verses =
        (chapters[safeChapter - 1]['verses'] as List<dynamic>? ?? const [])
            .toList();
    final safeVerseCount = verses.isEmpty ? 1 : verses.length;
    final safeVerse = _selectedVerse.clamp(1, safeVerseCount);

    if (!mounted) return;
    setState(() {
      _chapterCount = safeChapterCount;
      _verseCount = safeVerseCount;
      _selectedChapter = safeChapter;
      _selectedVerse = safeVerse;
      _isLoadingStructure = false;
    });
  }

  Future<void> _reloadVerseCount() async {
    setState(() {
      _isLoadingStructure = true;
    });

    final data = await _bibleRepository.loadBook(_selectedBook.key);
    final chapters = (data['chapters'] as List<dynamic>? ?? const []).toList();
    final safeChapterCount = chapters.isEmpty ? 1 : chapters.length;
    final safeChapter = _selectedChapter.clamp(1, safeChapterCount);
    final verses =
        (chapters[safeChapter - 1]['verses'] as List<dynamic>? ?? const [])
            .toList();
    final safeVerseCount = verses.isEmpty ? 1 : verses.length;
    final safeVerse = _selectedVerse.clamp(1, safeVerseCount);

    if (!mounted) return;
    setState(() {
      _chapterCount = safeChapterCount;
      _verseCount = safeVerseCount;
      _selectedChapter = safeChapter;
      _selectedVerse = safeVerse;
      _isLoadingStructure = false;
    });
  }

  Future<void> _pickBook() async {
    final pickedBook = await showAppModalBottomSheet<BibleBook>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: bibleBooks.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final book = bibleBooks[index];
              return ListTile(
                title: Text(book.key),
                subtitle: Text(book.name),
                trailing: book.key == _selectedBook.key
                    ? Icon(
                        Icons.check_circle,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                onTap: () => Navigator.of(context).pop(book),
              );
            },
          ),
        );
      },
    );

    if (pickedBook == null || pickedBook.key == _selectedBook.key) return;

    setState(() {
      _selectedBook = pickedBook;
      _selectedChapter = 1;
      _selectedVerse = 1;
    });
    await _loadStructure();
  }

  Future<void> _pickChapter() async {
    if (_isLoadingStructure) return;

    final pickedChapter = await showAppModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: _chapterCount,
            itemBuilder: (context, index) {
              final chapter = index + 1;
              return ListTile(
                title: Text(
                  '${context.t('studio.chapter_prefix', fallback: 'Chapter')} $chapter',
                ),
                trailing: chapter == _selectedChapter
                    ? Icon(
                        Icons.check_circle,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                onTap: () => Navigator.of(context).pop(chapter),
              );
            },
          ),
        );
      },
    );

    if (pickedChapter == null || pickedChapter == _selectedChapter) return;

    setState(() {
      _selectedChapter = pickedChapter;
      _selectedVerse = 1;
    });
    await _reloadVerseCount();
  }

  Future<void> _pickVerse() async {
    if (_isLoadingStructure) return;

    final pickedVerse = await showAppModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: _verseCount,
            itemBuilder: (context, index) {
              final verse = index + 1;
              return ListTile(
                title: Text(
                  '${context.t('studio.verse_prefix', fallback: 'Verse')} $verse',
                ),
                trailing: verse == _selectedVerse
                    ? Icon(
                        Icons.check_circle,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                onTap: () => Navigator.of(context).pop(verse),
              );
            },
          ),
        );
      },
    );

    if (pickedVerse == null) return;

    setState(() {
      _selectedVerse = pickedVerse;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${context.t('studio.edit_item_prefix', fallback: 'Edit')} ${widget.title}',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Choose a book, chapter, and verse from the Bible list.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: carouselBoxDecoration(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selected Reference',
                      style: theme.textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_selectedBook.key}:$_selectedChapter:$_selectedVerse',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _selectedBook.name,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _VersePickerTile(
                label: context.t('studio.verse_book', fallback: 'Book'),
                value: _selectedBook.key,
                subtitle: _selectedBook.name,
                onTap: _pickBook,
              ),
              const SizedBox(height: 12),
              _VersePickerTile(
                label: context.t('studio.verse_chapter', fallback: 'Chapter'),
                value: '$_selectedChapter',
                subtitle: _isLoadingStructure
                    ? 'Loading chapters...'
                    : '$_chapterCount chapters available',
                onTap: _pickChapter,
              ),
              const SizedBox(height: 12),
              _VersePickerTile(
                label: context.t('studio.verse_verse', fallback: 'Verse'),
                value: '$_selectedVerse',
                subtitle: _isLoadingStructure
                    ? 'Loading verses...'
                    : '$_verseCount verses available',
                onTap: _pickVerse,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSaving || _isLoadingStructure
                      ? null
                      : () async {
                          setState(() => _isSaving = true);
                          try {
                            await widget.onSave(
                              book: _selectedBook.key,
                              chapter: _selectedChapter,
                              verse: _selectedVerse,
                            );
                            if (context.mounted) Navigator.pop(context);
                          } finally {
                            if (mounted) {
                              setState(() => _isSaving = false);
                            }
                          }
                        },
                  child: _isSaving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(context.t('common.save', fallback: 'Save')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VersePickerTile extends StatelessWidget {
  const _VersePickerTile({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.onTap,
  });

  final String label;
  final String value;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: carouselBoxDecoration(context),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      value,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
