import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/bible_font_size_constant.dart';
import 'package:flutter_application/church_app/providers/for_you_sections/bible_swipe_verse_provider.dart';
import 'package:flutter_application/church_app/widgets/app_bar_title_widget.dart';
import 'package:flutter_application/church_app/widgets/bible_reader_appbar.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class BibleSwipeVerseScreen extends ConsumerWidget {
  const BibleSwipeVerseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final versesAsync = ref.watch(swipeVersesProvider);
    final size = ref.watch(bibleFontSizeProvider);

    return Scaffold(
      //backgroundColor: Colors.white,
      appBar: BibleReaderAppBar(
        title: const AppBarTitle(text: "Bible Swipes"),
      ),
      body: versesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (verses) {
          return PageView.builder(
            scrollDirection: Axis.vertical,
            itemCount: verses.length,
            itemBuilder: (context, index) {
              final v = verses[index];

              return Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tamil
                    Text(
                      v['tamil'] ?? '',
                      textAlign: TextAlign.start,
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(height: 1.5, fontSize: BibleFontConfig.verseNumber(size),),
                    ),

                    const SizedBox(height: 16),

                    // English
                    Text(
                      v['english'] ?? '',
                      textAlign: TextAlign.start,
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(height: 1.5, fontSize: BibleFontConfig.verseNumber(size),),
                    ),

                    const SizedBox(height: 16),

                    // English
                    

                    const SizedBox(height: 20),

                    // Reference
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        v['reference'] ?? '',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
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
  }
}
