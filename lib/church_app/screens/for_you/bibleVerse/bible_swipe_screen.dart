

import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/models/for_you_section_model/bible_verse_model.dart';
import 'package:flutter_application/church_app/providers/for_you_sections/bible_verse_provider.dart';
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
          error: (e, _) => Center(
            child: Text('Something went wrong'),
          ),
          data: (_) {
            if (verse == null) {
              return const Center(child: Text('No verse found'));
            }

            return Column(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    Expanded(
      child: _VersePage(verse: verse),
    ),
    const SizedBox(height: 20),
    ElevatedButton(
      onPressed: () => ref.read(randomBibleVerseProvider.notifier).next(),
      child: const Text('Next'),
    ),
    const SizedBox(height: 20), // optional padding from bottom
  ],
);

          },
        ),
      ),
    );
  }
}





// class BibleVerseScreen extends ConsumerStatefulWidget {
//   const BibleVerseScreen({super.key});

//   @override
//   ConsumerState<BibleVerseScreen> createState() =>
//       _BibleVerseScreenState();
// }

// class _BibleVerseScreenState extends ConsumerState<BibleVerseScreen> {
//   late final PageController _controller;

//   @override
//   void initState() {
//     super.initState();
//     _controller = PageController();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final versesAsync = ref.watch(bibleVerseProvider);

//     return Scaffold(
//       backgroundColor: Colors.white,
//       body: SafeArea(
//         child: versesAsync.when(
//           loading: () => const Center(
//             child: CircularProgressIndicator(),
//           ),
//           error: (err, stack) => Center(
//             child: Text('Something went wrong'),
//           ),
//           data: (verses) => PageView.builder(
//             controller: _controller,
//             itemCount: verses.length,
//             itemBuilder: (context, index) {
//               return _VersePage(verse: verses[index]);
//             },
//           ),
//         ),
//       ),
//     );
//   }
// }


class _VersePage extends StatelessWidget {
  const _VersePage({required this.verse});
  final BibleVerse verse;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          // 🔹 Top bar
          SizedBox(
            height: 56,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios),
                  onPressed: () => Navigator.pop(context),
                ),
                const Spacer(),
                Text(
                  "Bible Swipes",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                )
              ],
            ),
          ),

          const Spacer(),

          // 🔹 Verse text
          Text(
            verse.english,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 28,
              height: 1.4,
              fontFamily: 'Serif',
              fontWeight: FontWeight.w400,
            ),
          ),

          Text(
            verse.tamil,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 28,
              height: 1.4,
              fontFamily: 'Serif',
              fontWeight: FontWeight.w400,
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

          const Spacer(),

          // 🔹 Bottom actions
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: const [
                Icon(Icons.share_outlined),
                Icon(Icons.favorite_border),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
