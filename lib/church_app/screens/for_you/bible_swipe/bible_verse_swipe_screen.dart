import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/providers/for_you_sections/bible_swipe_verse_provider.dart';
import 'package:flutter_application/church_app/providers/for_you_sections/favorites_provider.dart';
import 'package:flutter_application/church_app/screens/side_drawer/favorite_verses_screen.dart';
import 'package:flutter_application/church_app/widgets/app_bar_title_widget.dart';
import 'package:flutter_application/church_app/widgets/bible_reader_appbar.dart';
import 'package:flutter_application/church_app/widgets/bible_verse_item_widget.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class BibleSwipeVerseScreen extends ConsumerWidget {
  const BibleSwipeVerseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final versesAsync = ref.watch(swipeVersesProvider);

    return Scaffold(
      appBar: BibleReaderAppBar(
        title: const AppBarTitle(text: "Bible Swipes"),
      ),
      body: versesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (verses) {
          final highlights = ref.watch(favoritesProvider).maybeWhen(
            data: (h) => h,
            orElse: () => [],
          );
          return PageView.builder(
            scrollDirection: Axis.vertical,
            itemCount: verses.length,
            itemBuilder: (context, index) {
              final v = verses[index];
              final reference = v['reference'] ?? '';
              // Parse reference: e.g. "Genesis 1:1"
              final parts = reference.split(' ');
              final book = parts.first;
              final chapterVerse = parts.length > 1 ? parts.last.split(':') : ['1', '1'];
              final chapter = int.tryParse(chapterVerse[0]) ?? 1;
              final verseNumber = int.tryParse(chapterVerse[1]) ?? 1;
              final isHighlighted = highlights.any((verse) => (verse['reference'] ?? '') == reference);

              return Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BibleVerseItemWidget(
                        verseNumber: v['reference'] ?? '',
                        versePrimary: v['tamil'] ?? '',
                        verseSecondary: v['english'] ?? ''),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            isHighlighted ? Icons.favorite : Icons.favorite_border,
                            color: isHighlighted ? Colors.red : Colors.grey,
                          ),
                          onPressed: () async {
                            await toggleGlobalHighlight(book, chapter, verseNumber);
                            ref.invalidate(favoritesProvider);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.share_outlined),
                          onPressed: () async {
                            showLanguageShareOptions(
                              context,
                              verse: v,
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
