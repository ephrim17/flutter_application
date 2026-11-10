/// The arithmetic and text handling behind the Communication tab.
///
/// All pure, so the parts that quietly go wrong in a feature like this —
/// phone numbers that do not dial, placeholders left raw in a message that
/// went to the whole church — are testable without a device.
library;

import 'package:flutter_application/church_app/models/church_membership_model.dart';
import 'package:flutter_application/church_app/models/communication_models.dart';

/// Placeholders that differ per person. A group message cannot fill these:
/// one body goes to everyone.
const List<String> perPersonPlaceholders = <String>['{name}', '{first}'];

/// Placeholders that are the same for everyone, so they always resolve.
///
/// A `{sender}` placeholder existed here briefly and was never given a
/// value, so it silently resolved to nothing in the sent message. A
/// placeholder that quietly deletes itself is worse than no placeholder:
/// the sender signs off and the member receives a blank. Anyone wanting to
/// sign a message types their own name.
const List<String> sharedPlaceholders = <String>['{church}'];

/// Fills in whatever can be filled for [member].
///
/// A null [member] means a group send, where only the shared placeholders
/// resolve — see [messageHasPerPersonPlaceholder].
String resolveMessageBody(
  String body, {
  ChurchMembership? member,
  required String churchName,
}) {
  var text = body.replaceAll('{church}', churchName.trim());

  if (member == null) return text;

  final name = member.displayName.trim();
  final first = name.isEmpty ? '' : name.split(RegExp(r'\s+')).first;
  text = text.replaceAll('{name}', name).replaceAll('{first}', first);
  return text;
}

/// Whether the body contains a placeholder that only makes sense per person.
///
/// A group send with `{name}` still in it would deliver the literal text
/// "Dear {name}" to the whole church, which is the kind of mistake that is
/// only noticed after it has gone out.
bool messageHasPerPersonPlaceholder(String body) {
  return perPersonPlaceholders.any(body.contains);
}

/// Strips the per-person placeholders out, for when the sender wants one
/// body for everyone after all. Collapses the whitespace they leave behind
/// so "Dear {name}, we meet" does not become "Dear , we meet".
String stripPerPersonPlaceholders(String body) {
  var text = body;
  for (final token in perPersonPlaceholders) {
    text = text.replaceAll(token, '');
  }
  return text
      .replaceAll(RegExp(r'[ \t]+'), ' ')
      // A removed placeholder leaves a space before its punctuation:
      // "Dear {name}," becomes "Dear ,". Close it up.
      .replaceAllMapped(
        RegExp(r' +([,.!?;:])'),
        (match) => match.group(1)!,
      )
      .replaceAll(RegExp(r'^[ \t]+', multiLine: true), '')
      .trim();
}

/// A phone number reduced to digits with a country code, ready for a
/// `wa.me` or `sms:` link, or null when there is nothing dialable.
///
/// [defaultCountryCode] is applied to a local number — a church's members
/// are overwhelmingly in one country, and a 10-digit Indian mobile stored
/// without +91 is the normal case, not the exception.
String? normalizePhoneNumber(
  String raw, {
  String defaultCountryCode = '91',
}) {
  var digits = raw.replaceAll(RegExp(r'[^0-9+]'), '');
  if (digits.isEmpty) return null;

  if (digits.startsWith('+')) {
    digits = digits.substring(1);
  } else if (digits.startsWith('00')) {
    digits = digits.substring(2);
  } else if (digits.startsWith('0')) {
    // A trunk prefix: drop it and treat the rest as a local number.
    digits = '$defaultCountryCode${digits.substring(1)}';
  } else if (digits.length <= 10) {
    digits = '$defaultCountryCode$digits';
  }

  digits = digits.replaceAll(RegExp(r'[^0-9]'), '');
  // Shorter than this is a short code or a typo, not someone's mobile.
  if (digits.length < 10) return null;
  return digits;
}

/// Members this message can actually reach on [channel], in name order.
///
/// Email needs an email address, everything else needs a dialable phone
/// number. Someone with neither is not an error — they are simply not
/// reachable this way, and the screen says how many that is rather than
/// silently sending to fewer people than the sender expected.
List<ChurchMembership> reachableMembers(
  Iterable<ChurchMembership> members,
  MessageChannel channel,
) {
  final reachable = members.where((member) {
    if (channel == MessageChannel.email) {
      return member.displayEmail.trim().contains('@');
    }
    return normalizePhoneNumber(member.displayPhone) != null;
  }).toList()
    ..sort(
      (a, b) =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
    );
  return reachable;
}

/// The headline numbers above the composer.
class CommunicationStats {
  const CommunicationStats({
    required this.messagesThisMonth,
    required this.peopleReachedThisMonth,
    required this.withPhone,
    required this.withoutPhone,
  });

  final int messagesThisMonth;
  final int peopleReachedThisMonth;
  final int withPhone;
  final int withoutPhone;
}

CommunicationStats communicationStats({
  required Iterable<ChurchMembership> members,
  required Iterable<SentMessage> log,
  DateTime? asOf,
}) {
  final now = asOf ?? DateTime.now();
  final monthStart = DateTime(now.year, now.month);

  final thisMonth = log.where((message) {
    final sentAt = message.sentAt;
    return sentAt != null && !sentAt.isBefore(monthStart);
  });

  final withPhone = members
      .where((member) => normalizePhoneNumber(member.displayPhone) != null)
      .length;

  return CommunicationStats(
    messagesThisMonth: thisMonth.length,
    peopleReachedThisMonth:
        thisMonth.fold<int>(0, (sum, message) => sum + message.recipientCount),
    withPhone: withPhone,
    withoutPhone: members.length - withPhone,
  );
}

/// A `wa.me` link for one person, with the message pre-filled.
Uri? whatsAppUri(String phone, String message) {
  final number = normalizePhoneNumber(phone);
  if (number == null) return null;
  return Uri.parse(
    'https://wa.me/$number?text=${Uri.encodeComponent(message)}',
  );
}

/// An `sms:` link. [numbers] may hold several — most Android SMS apps accept
/// a comma-separated list, which is how one message reaches a group.
Uri? smsUri(List<String> numbers, String message) {
  final dialable = numbers
      .map(normalizePhoneNumber)
      .whereType<String>()
      .toList(growable: false);
  if (dialable.isEmpty) return null;
  return Uri(
    scheme: 'sms',
    path: dialable.join(','),
    queryParameters: <String, String>{'body': message},
  );
}

/// A `mailto:` link. Addresses go in bcc so a church announcement does not
/// hand every member's address to every other member.
Uri? emailUri(List<String> addresses, String subject, String message) {
  final valid = addresses
      .map((address) => address.trim())
      .where((address) => address.contains('@'))
      .toList(growable: false);
  if (valid.isEmpty) return null;
  return Uri(
    scheme: 'mailto',
    queryParameters: <String, String>{
      'bcc': valid.join(','),
      'subject': subject,
      'body': message,
    },
  );
}

/// Members who belong to [groupId], or everyone when it is null.
///
/// Groups come from the fixed `churchGroupDefinitions` list and are stored
/// on each member as `churchGroupIds`, so this is a filter over the roster
/// already loaded rather than another read.
List<ChurchMembership> membersInGroup(
  Iterable<ChurchMembership> members,
  String? groupId,
) {
  if (groupId == null || groupId.trim().isEmpty) {
    return members.toList(growable: false);
  }
  return members
      .where((member) => member.churchGroupIds.contains(groupId))
      .toList(growable: false);
}

/// How many recipients go into one hand-off before it is split.
///
/// These are not app limits — they are limits of what is on the other side
/// of the hand-off, and they differ by channel:
///
/// * **WhatsApp has no bulk link at all.** `wa.me` opens exactly one chat,
///   so one recipient per hand-off is the ceiling, not a choice. Reaching a
///   large group on WhatsApp for free means a Broadcast List made inside
///   WhatsApp (256 recipients), which is why the numbers can be copied.
/// * **SMS is generous but uneven.** Google Messages on Android accepted
///   1,000 recipients in testing and labelled it a mass text, sending one
///   message per person. Other SMS apps, iOS, and individual carriers are
///   stricter, and a carrier that silently drops recipients past its cap
///   gives no error at all — so above this many the app offers to split.
/// * **Email is capped by URL length, not by the mail app.** A `mailto:`
///   with 200 bcc addresses runs past 5,000 characters, and clients start
///   truncating well before that; the ones that truncate do it silently.
int communicationBatchLimit(MessageChannel channel) {
  return switch (channel) {
    MessageChannel.whatsapp => 1,
    MessageChannel.sms => 100,
    MessageChannel.email => 50,
  };
}

/// Splits [items] into chunks of at most [size], preserving order.
///
/// Order matters: a church working through batches needs the same people in
/// the same batch each time it reopens the screen, or it cannot tell what it
/// has already sent.
List<List<T>> messageBatches<T>(List<T> items, int size) {
  if (size <= 0) return items.isEmpty ? const [] : [items.toList()];
  final batches = <List<T>>[];
  for (var start = 0; start < items.length; start += size) {
    final end = start + size > items.length ? items.length : start + size;
    batches.add(items.sublist(start, end));
  }
  return batches;
}

/// Whether this many recipients should be split for this channel.
bool needsBatching(int recipientCount, MessageChannel channel) {
  return recipientCount > communicationBatchLimit(channel);
}

/// Opens WhatsApp with the message already written and no recipient
/// chosen, so the sender picks one of their own chats or groups.
///
/// This is how a church reaches a WhatsApp group it already has: WhatsApp
/// shows its own picker, the group is selected there, and one message goes
/// to everyone in it. There is deliberately no number in the link.
Uri whatsAppShareUri(String message) {
  return Uri.parse('https://wa.me/?text=${Uri.encodeComponent(message)}');
}

/// A pasted WhatsApp group invite link, reduced to its canonical form, or
/// null when it is not one.
///
/// Group links look like `https://chat.whatsapp.com/<code>` and come from
/// Group info → Invite via link. A `wa.me` link is a *person*, not a group,
/// and is rejected: saving one under a group's name would quietly message
/// one member whenever staff meant to reach the whole group.
String? normalizeWhatsAppGroupLink(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;

  final uri = Uri.tryParse(
    trimmed.startsWith('http') ? trimmed : 'https://$trimmed',
  );
  if (uri == null) return null;
  if (uri.host.toLowerCase() != 'chat.whatsapp.com') return null;

  final code = uri.pathSegments.where((part) => part.isNotEmpty).firstOrNull;
  // Invite codes are a longish opaque string; anything shorter is a
  // mistyped or truncated paste.
  if (code == null || code.length < 8) return null;
  return 'https://chat.whatsapp.com/$code';
}
