import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/models/for_you_section_models/bible_verse_model.dart';
import 'package:flutter_application/church_app/models/for_you_section_models/favorites_model.dart';
import 'package:flutter_application/church_app/providers/for_you_sections/bible_verse_provider.dart';
import 'package:flutter_application/church_app/providers/for_you_sections/favorites_provider.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class BibleSwipeScreen extends ConsumerWidget {
  const BibleSwipeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncVerses = ref.watch(allBibleVersesProvider);
    final verse = ref.watch(randomBibleVerseProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: asyncVerses.when(
          loading: () => const Center(
            child: CircularProgressIndicator(),
          ),
          error: (e, _) => const Center(
            child: Text('Something went wrong'),
          ),
          data: (_) {
            if (verse == null) {
              return const Center(child: Text('No verse found'));
            }

            /// 🔑 THIS gives bounded height
            return SizedBox.expand(
              child: Column(
                children: [
                  /// 🔹 Verse page controls its own scrolling
                  Expanded(
                    child: _VersePage(verse: verse),
                  ),

                  const SizedBox(height: 12),

                  ElevatedButton(
                    onPressed: () => ref
                        .read(randomBibleVerseProvider.notifier)
                        .next(),
                    child: const Text('Next'),
                  ),

                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}


class _VersePage extends ConsumerWidget {
  const _VersePage({required this.verse});
  final BibleVerse verse;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesNotifier = ref.read(favoritesProvider.notifier);
    final isFavorite =
        ref.watch(favoritesProvider).any(
              (v) => v.reference == verse.reference,
            );

    return Column(
      children: [
        /// 🔹 FIXED TOP BAR
        SizedBox(
          height: 56,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios),
                onPressed: () => Navigator.pop(context),
              ),
              const Spacer(),
              const Text(
                "Bible Swipes",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              const SizedBox(width: 48),
            ],
          ),
        ),

        /// 🔹 SCROLLABLE VERSE CONTENT
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                const SizedBox(height: 40),

                Text(
                  verse.english,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    height: 1.4,
                    fontFamily: 'Serif',
                  ),
                ),

                const SizedBox(height: 16),

                Text(
                  verse.tamil,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    height: 1.4,
                    fontFamily: 'Serif',
                  ),
                ),

                const SizedBox(height: 24),

                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '- ${verse.reference}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),

                const SizedBox(height: 80),
              ],
            ),
          ),
        ),

        /// 🔹 FIXED BOTTOM ACTIONS
        Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              const Icon(Icons.share_outlined),

              /// ❤️ FAVORITE TOGGLE
              IconButton(
                icon: Icon(
                  isFavorite
                      ? Icons.favorite
                      : Icons.favorite_border,
                  color: isFavorite ? Colors.red : null,
                ),
                onPressed: () {
                  favoritesNotifier.toggle(
                    FavoriteVerse(
                      english: verse.english,
                      tamil: verse.tamil,
                      reference: verse.reference,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
