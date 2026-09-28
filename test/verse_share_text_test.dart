import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application/church_app/screens/side_drawer/bible_book_screen.dart';

void main() {
  test('verse share text carries both scripts under their own references', () {
    final text = buildVerseShareText(
      reference: 'Genesis 23:2',
      tamilReference: 'ஆதியாகமம் 23:2',
      englishText: 'And Sarah died in Kirjatharba.',
      tamilText: 'சாராள் மரித்தாள்.',
    );

    expect(
      text,
      'Genesis 23:2\n'
      'And Sarah died in Kirjatharba.\n'
      '\n'
      'ஆதியாகமம் 23:2\n'
      'சாராள் மரித்தாள்.',
    );
  });

  test('a missing script is dropped rather than shared as a bare reference',
      () {
    expect(
      buildVerseShareText(
        reference: 'Genesis 23:2',
        tamilReference: 'ஆதியாகமம் 23:2',
        englishText: 'And Sarah died in Kirjatharba.',
        tamilText: '   ',
      ),
      'Genesis 23:2\nAnd Sarah died in Kirjatharba.',
    );

    expect(
      buildVerseShareText(
        reference: 'Genesis 23:2',
        tamilReference: 'ஆதியாகமம் 23:2',
        englishText: '',
        tamilText: 'சாராள் மரித்தாள்.',
      ),
      'ஆதியாகமம் 23:2\nசாராள் மரித்தாள்.',
    );
  });

  test('a verse with neither script shares nothing at all', () {
    expect(
      buildVerseShareText(
        reference: 'Genesis 23:2',
        tamilReference: 'ஆதியாகமம் 23:2',
        englishText: '',
        tamilText: '',
      ),
      isEmpty,
    );
  });
}
