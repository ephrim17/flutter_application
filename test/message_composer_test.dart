import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application/church_app/helpers/message_composer.dart';
import 'package:flutter_application/church_app/models/church_membership_model.dart';
import 'package:flutter_application/church_app/models/communication_models.dart';

/// A church message goes to real phones and cannot be recalled. These pin
/// the two things that would be noticed only after it went out: a number
/// that does not dial, and a placeholder delivered raw to everyone.
ChurchMembership _member(
  String id, {
  String name = 'Member',
  String phone = '',
  String email = '',
}) {
  return ChurchMembership.fromFirestore(id, 'church-1', {
    'uid': id,
    'displayName': name,
    'displayPhone': phone,
    'displayEmail': email,
  });
}

SentMessage _sent(DateTime? at, int recipients) {
  return SentMessage(
    id: 'x',
    body: 'hello',
    channel: MessageChannel.whatsapp,
    category: 'general',
    recipientCount: recipients,
    sentAt: at,
  );
}

void main() {
  group('normalizePhoneNumber', () {
    test('adds the country code to a local mobile', () {
      expect(normalizePhoneNumber('9876543210'), '919876543210');
    });

    test('keeps an already international number', () {
      expect(normalizePhoneNumber('+91 98765 43210'), '919876543210');
      expect(normalizePhoneNumber('0091 98765 43210'), '919876543210');
    });

    test('drops a trunk zero rather than dialing it', () {
      // 09876543210 is the same phone as 9876543210, not a different one.
      expect(normalizePhoneNumber('09876543210'), '919876543210');
    });

    test('ignores the punctuation people actually type', () {
      expect(normalizePhoneNumber('(98765) 43210'), '919876543210');
      expect(normalizePhoneNumber('98765-43210'), '919876543210');
    });

    test('refuses anything too short to be a mobile', () {
      // Landline extensions and typos must not become a wa.me link that
      // opens a chat with a stranger.
      expect(normalizePhoneNumber('12345'), isNull);
      expect(normalizePhoneNumber(''), isNull);
      expect(normalizePhoneNumber('not a number'), isNull);
    });

    test('respects a different country', () {
      expect(
        normalizePhoneNumber('7700900123', defaultCountryCode: '44'),
        '447700900123',
      );
    });
  });

  group('resolveMessageBody', () {
    test('fills the person and the church', () {
      final text = resolveMessageBody(
        'Dear {first}, {church} meets on Sunday.',
        member: _member('a', name: 'Arul Vivek'),
        churchName: 'Grace Church',
      );
      expect(text, 'Dear Arul, Grace Church meets on Sunday.');
    });

    test('a group send resolves only what is the same for everyone', () {
      final text = resolveMessageBody(
        'Dear {first}, {church} meets on Sunday.',
        churchName: 'Grace Church',
      );
      expect(text, 'Dear {first}, Grace Church meets on Sunday.');
    });
  });

  group('per-person placeholders in a group message', () {
    test('are detected', () {
      expect(messageHasPerPersonPlaceholder('Dear {name}, hello'), isTrue);
      expect(messageHasPerPersonPlaceholder('Hello {church}'), isFalse);
    });

    test('strip cleanly, without leaving dangling punctuation', () {
      // "Dear {name}, we meet" must not become "Dear , we meet".
      expect(
        stripPerPersonPlaceholders('Dear {name}, we meet at 9.'),
        'Dear, we meet at 9.',
      );
    });
  });

  group('reachableMembers', () {
    final members = [
      _member('a', name: 'Zoe', phone: '9876543210', email: 'zoe@x.com'),
      _member('b', name: 'Anna', phone: '', email: 'anna@x.com'),
      _member('c', name: 'Mary', phone: '12345'),
    ];

    test('a phone channel needs a dialable number', () {
      final reached = reachableMembers(members, MessageChannel.whatsapp);
      // Anna has no phone; Mary's is too short to dial.
      expect(reached.map((m) => m.displayName), ['Zoe']);
    });

    test('email needs an address, not a phone', () {
      final reached = reachableMembers(members, MessageChannel.email);
      expect(reached.map((m) => m.displayName), ['Anna', 'Zoe']);
    });

    test('the list is name-ordered so it reads like the directory', () {
      final reached = reachableMembers([
        _member('a', name: 'Zoe', phone: '9876543210'),
        _member('b', name: 'Anna', phone: '9876543211'),
      ], MessageChannel.sms);
      expect(reached.map((m) => m.displayName), ['Anna', 'Zoe']);
    });
  });

  group('links', () {
    test('whatsapp carries the number and the text', () {
      final uri = whatsAppUri('9876543210', 'Hello there');
      expect(uri.toString(), startsWith('https://wa.me/919876543210?text='));
      expect(uri.toString(), contains('Hello%20there'));
    });

    test('whatsapp refuses an undialable number', () {
      expect(whatsAppUri('12345', 'Hello'), isNull);
    });

    test('sms addresses everyone it can reach and drops the rest', () {
      final uri = smsUri(['9876543210', 'rubbish', '09876543211'], 'Hi');
      expect(uri!.path, '919876543210,919876543211');
      expect(uri.queryParameters['body'], 'Hi');
    });

    test('sms is null when nobody is reachable', () {
      expect(smsUri(['rubbish', ''], 'Hi'), isNull);
    });

    test('email hides the recipients from each other', () {
      // A church announcement must not hand every member's address to
      // every other member.
      final uri = emailUri(['a@x.com', 'b@x.com'], 'Sunday', 'Hello');
      expect(uri!.queryParameters['bcc'], 'a@x.com,b@x.com');
      expect(uri.queryParameters['to'], isNull);
      expect(uri.queryParameters['subject'], 'Sunday');
    });

    // Spaces must travel as %20, not as the `+` that HTML form encoding
    // uses. `Uri(queryParameters: …)` encodes as form data, so "Dear
    // Archana, Welcome to our church" reached the SMS app as
    // "Dear+Archana,+Welcome+to+our+church" — the receiving app does not
    // decode `+` back to a space, so the member read the pluses.
    //
    // These assert on the link text rather than on `queryParameters`,
    // which decodes `+` back into a space and so cannot see the bug at
    // all. That is why the tests above, which use single-word bodies and
    // read `queryParameters`, went on passing throughout.
    const sentence = 'Dear Archana, Welcome to our church';

    test('sms sends spaces as %20, never as +', () {
      final uri = smsUri(['9876543210'], sentence);

      expect(uri.toString(), contains('Dear%20Archana'));
      expect(uri.toString(), isNot(contains('+919876543210?body=Dear+')));
      expect(
        uri!.query.contains('+'),
        isFalse,
        reason: 'a + in the body is shown literally by the SMS app',
      );
      expect(uri.queryParameters['body'], sentence);
    });

    test('email sends spaces as %20 in both subject and body', () {
      final uri = emailUri(['a@x.com'], 'This Sunday', sentence);

      expect(uri.toString(), contains('This%20Sunday'));
      expect(uri.toString(), contains('Dear%20Archana'));
      expect(uri!.query.contains('+'), isFalse);
      expect(uri.queryParameters['subject'], 'This Sunday');
      expect(uri.queryParameters['body'], sentence);
    });

    test('whatsapp was already correct and stays that way', () {
      final uri = whatsAppUri('9876543210', sentence);

      expect(uri.toString(), contains('Dear%20Archana'));
      expect(uri!.query.contains('+'), isFalse);
    });

    test('sms still reaches several numbers after the encoding change', () {
      final uri = smsUri(['9876543210', 'rubbish', '09876543211'], sentence);

      expect(uri!.path, '919876543210,919876543211');
      expect(uri.queryParameters['body'], sentence);
    });
  });

  group('communicationStats', () {
    final asOf = DateTime(2026, 11, 10);

    test('counts only this month, and sums who was reached', () {
      final stats = communicationStats(
        members: [
          _member('a', phone: '9876543210'),
          _member('b', phone: ''),
          _member('c', phone: '9876543211'),
        ],
        log: [
          _sent(DateTime(2026, 11, 2), 12),
          _sent(DateTime(2026, 11, 9), 30),
          _sent(DateTime(2026, 10, 30), 99),
          _sent(null, 5),
        ],
        asOf: asOf,
      );
      expect(stats.messagesThisMonth, 2);
      expect(stats.peopleReachedThisMonth, 42);
      expect(stats.withPhone, 2);
      expect(stats.withoutPhone, 1);
    });

    test('an empty church reports zeroes, not a crash', () {
      final stats = communicationStats(
        members: const [],
        log: const [],
        asOf: asOf,
      );
      expect(stats.messagesThisMonth, 0);
      expect(stats.withPhone, 0);
      expect(stats.withoutPhone, 0);
    });
  });

  group('membersInGroup', () {
    final members = [
      ChurchMembership.fromFirestore('a', 'c', {
        'displayName': 'Anna',
        'churchGroupIds': ['youth', 'music_ministry'],
      }),
      ChurchMembership.fromFirestore('b', 'c', {
        'displayName': 'Ben',
        'churchGroupIds': ['youth'],
      }),
      ChurchMembership.fromFirestore('c', 'c', {'displayName': 'Cara'}),
    ];

    test('filters to one group', () {
      expect(
        membersInGroup(members, 'youth').map((m) => m.displayName),
        ['Anna', 'Ben'],
      );
      expect(
        membersInGroup(members, 'music_ministry').map((m) => m.displayName),
        ['Anna'],
      );
    });

    test('null means everyone, including members in no group', () {
      expect(membersInGroup(members, null), hasLength(3));
      expect(membersInGroup(members, '  '), hasLength(3));
    });

    test('an empty group is empty, not everyone', () {
      // The trap: falling back to "all" when a group has nobody in it would
      // send a message meant for the youth to the whole church.
      expect(membersInGroup(members, 'elders'), isEmpty);
    });
  });

  group('batching', () {
    test('splits in order and keeps everyone exactly once', () {
      final batches = messageBatches(List.generate(205, (i) => i), 100);
      expect(batches.map((b) => b.length), [100, 100, 5]);
      expect(batches.expand((b) => b).toList(), List.generate(205, (i) => i));
    });

    test('a list smaller than the batch is one batch', () {
      expect(messageBatches([1, 2, 3], 100), [
        [1, 2, 3]
      ]);
    });

    test('an empty list produces no batches at all', () {
      expect(messageBatches(<int>[], 50), isEmpty);
    });

    test('WhatsApp is one per batch, because wa.me opens one chat', () {
      expect(communicationBatchLimit(MessageChannel.whatsapp), 1);
      expect(needsBatching(2, MessageChannel.whatsapp), isTrue);
    });

    test('SMS and email split at their own ceilings', () {
      expect(needsBatching(100, MessageChannel.sms), isFalse);
      expect(needsBatching(101, MessageChannel.sms), isTrue);
      expect(needsBatching(50, MessageChannel.email), isFalse);
      expect(needsBatching(51, MessageChannel.email), isTrue);
    });

    test('an email batch stays inside a workable mailto length', () {
      // The real constraint: clients truncate long mailto URLs silently.
      final addresses = List.generate(
        communicationBatchLimit(MessageChannel.email),
        (i) => 'member$i@example.com',
      );
      final uri = emailUri(addresses, 'Church', 'A normal length notice.');
      expect(uri.toString().length, lessThan(2000));
    });
  });

  group('WhatsApp groups', () {
    test('share link carries the text and names no recipient', () {
      final uri = whatsAppShareUri('Prayer meeting at 9');
      expect(uri.toString(), startsWith('https://wa.me/?text='));
      expect(uri.toString(), contains('Prayer%20meeting%20at%209'));
      // A number here would send to one person instead of opening the
      // picker where the group is chosen.
      expect(uri.path, '/');
    });

    test('accepts a group invite link, with or without the scheme', () {
      const expected = 'https://chat.whatsapp.com/ABCdef123456';
      expect(
        normalizeWhatsAppGroupLink('https://chat.whatsapp.com/ABCdef123456'),
        expected,
      );
      expect(
        normalizeWhatsAppGroupLink('chat.whatsapp.com/ABCdef123456'),
        expected,
      );
      expect(
        normalizeWhatsAppGroupLink(
            '  https://chat.whatsapp.com/ABCdef123456/  '),
        expected,
      );
    });

    test('rejects a wa.me link, which is one person and not a group', () {
      // The trap: saving this under "Youth group" would message a single
      // member every time staff meant to reach the whole group.
      expect(normalizeWhatsAppGroupLink('https://wa.me/919876543210'), isNull);
    });

    test('rejects rubbish and truncated pastes', () {
      expect(normalizeWhatsAppGroupLink(''), isNull);
      expect(normalizeWhatsAppGroupLink('not a link'), isNull);
      expect(normalizeWhatsAppGroupLink('https://chat.whatsapp.com/'), isNull);
      expect(
          normalizeWhatsAppGroupLink('https://chat.whatsapp.com/abc'), isNull);
      expect(
        normalizeWhatsAppGroupLink('https://example.com/ABCdef123456'),
        isNull,
      );
    });
  });
}
