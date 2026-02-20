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
           style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontSize: BibleFontConfig.tamil(size),
            fontWeight: FontWeight.w100,
            height: 1.5,  
            letterSpacing: 0.5
          ),
        ),
        const SizedBox(height: 6),
        Text(
          verseSecondary,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontSize: BibleFontConfig.english(size),
            color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
            fontWeight: FontWeight.w100,
            height: 1.5,  
            letterSpacing: 0.5
          ),
        ),
      ],
    );
  }
}
