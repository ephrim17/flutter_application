import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/bible_font_size_constant.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BibleVerseItemWidget extends ConsumerWidget {
  const BibleVerseItemWidget({
    super.key,
    required this.verseNumber,
    required this.versePrimary,
    required this.verseSecondary,
  });

  final String verseNumber;
  final String versePrimary;
  final String verseSecondary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = ref.watch(bibleFontSizeProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          verseNumber,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: BibleFontConfig.verseNumber(size),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          versePrimary,
          style: TextStyle(
            fontSize: BibleFontConfig.tamil(size),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          verseSecondary,
          style: TextStyle(
            fontSize: BibleFontConfig.english(size),
            height: 1.4,
            color: Colors.black54,
          ),
        ),
      ],
    );
  }
}
