import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application/church_app/helpers/message_composer.dart';

/// Adding a WhatsApp group means pasting a long opaque invite link. The
/// link cannot be derived from the group's name — the code in it is a
/// secret WhatsApp issues per group — so the only thing that can be saved
/// is the typing, by reading what the admin has just copied.
///
/// These cover the decision the dialog makes about clipboard contents:
/// what counts as a group link worth filling in, and what must be ignored
/// so the box is never silently filled with the wrong thing.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<String?> clipboardLink(String? clipboardText) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform,
        (MethodCall call) async {
      if (call.method == 'Clipboard.getData') {
        return clipboardText == null ? null : {'text': clipboardText};
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );

    final data = await Clipboard.getData(Clipboard.kTextPlain);
    return normalizeWhatsAppGroupLink(data?.text ?? '');
  }

  test('a copied group link is recognised and normalised', () async {
    expect(
      await clipboardLink('https://chat.whatsapp.com/ABCdef123456'),
      'https://chat.whatsapp.com/ABCdef123456',
    );
  });

  test('WhatsApp copies the link with surrounding text on some platforms',
      () async {
    // "Copy link" can put a trailing newline or spaces on the clipboard.
    expect(
      await clipboardLink('  https://chat.whatsapp.com/ABCdef123456\n'),
      'https://chat.whatsapp.com/ABCdef123456',
    );
  });

  test('an unrelated clipboard is left alone', () async {
    // The admin copied a verse, a phone number, anything. The box must
    // stay empty rather than be filled with nonsense.
    expect(await clipboardLink('Prayer meeting at 9'), isNull);
    expect(await clipboardLink('https://example.com/ABCdef123456'), isNull);
    expect(await clipboardLink(''), isNull);
  });

  test('an empty clipboard is handled, not crashed on', () async {
    expect(await clipboardLink(null), isNull);
  });

  test('a one-to-one chat link is never taken for a group', () async {
    // wa.me is one person. Saved under a group's name it would message a
    // single member every time staff meant to reach the group.
    expect(await clipboardLink('https://wa.me/919876543210'), isNull);
  });
}
