import 'package:cloud_firestore/cloud_firestore.dart';

/// How a message leaves the app.
///
/// The app never sends anything itself: it opens WhatsApp, the SMS app or
/// the mail app with the message already written, exactly as the reference
/// does. That is deliberate — a church sends from its own number, from the
/// account members already recognise, and nothing can go out by accident
/// because a person still presses send in the app that owns the thread.
enum MessageChannel {
  whatsapp('whatsapp'),
  sms('sms'),
  email('email');

  const MessageChannel(this.key);

  /// Stored on the log. A key, not display text, so a church can rename the
  /// label without rewriting its history.
  final String key;

  static MessageChannel fromKey(String key) {
    return MessageChannel.values.firstWhere(
      (channel) => channel.key == key.trim().toLowerCase(),
      orElse: () => MessageChannel.whatsapp,
    );
  }

  /// Whether this channel needs a phone number. Email does not.
  bool get needsPhone => this != MessageChannel.email;
}

/// What kind of message this is.
///
/// Recorded on every sent message so the history can be read back by
/// purpose — "what did we send about events last month" is the question a
/// church actually asks. The reference also lets members opt out per
/// category; that needs member-facing settings and is not built, so these
/// are labels on the log, not a delivery filter. See the feature doc.
const List<String> messageCategoryKeys = <String>[
  'general',
  'event_reminder',
  'greeting',
  'ministry',
  'emergency',
];

/// A reusable message body — `churches/{churchId}/message_templates/{id}`.
class MessageTemplate {
  const MessageTemplate({
    required this.id,
    required this.name,
    required this.body,
    this.category = 'general',
    this.createdBy = '',
    this.createdAt,
  });

  final String id;
  final String name;
  final String body;
  final String category;
  final String createdBy;
  final DateTime? createdAt;

  factory MessageTemplate.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    return MessageTemplate(
      id: id,
      name: (data['name'] ?? '').toString().trim(),
      body: (data['body'] ?? '').toString(),
      category: (data['category'] ?? 'general').toString().trim(),
      createdBy: (data['createdBy'] ?? '').toString().trim(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'name': name,
        'body': body,
        'category': category,
        'createdBy': createdBy,
      };
}

/// One message the church recorded as sent —
/// `churches/{churchId}/message_log/{id}`.
///
/// "Recorded as sent", not "sent": the app hands off to WhatsApp or the SMS
/// app and cannot know whether the person pressed send. The log is the
/// church's own record of what it meant to send and to whom, which is what
/// makes "did anyone tell the youth group?" answerable.
class SentMessage {
  const SentMessage({
    required this.id,
    required this.body,
    required this.channel,
    required this.category,
    required this.recipientCount,
    this.audienceLabel = '',
    this.sentBy = '',
    this.sentAt,
  });

  final String id;
  final String body;
  final MessageChannel channel;
  final String category;
  final int recipientCount;

  /// Who it went to, in words — "Youth group", "Everyone with a phone".
  /// Stored as text because the group may be renamed or deleted later and
  /// the history should still read correctly.
  final String audienceLabel;

  final String sentBy;
  final DateTime? sentAt;

  factory SentMessage.fromFirestore(String id, Map<String, dynamic> data) {
    return SentMessage(
      id: id,
      body: (data['body'] ?? '').toString(),
      channel: MessageChannel.fromKey((data['channel'] ?? '').toString()),
      category: (data['category'] ?? 'general').toString().trim(),
      recipientCount: (data['recipientCount'] as num?)?.toInt() ?? 0,
      audienceLabel: (data['audienceLabel'] ?? '').toString().trim(),
      sentBy: (data['sentBy'] ?? '').toString().trim(),
      sentAt: (data['sentAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'body': body,
        'channel': channel.key,
        'category': category,
        'recipientCount': recipientCount,
        'audienceLabel': audienceLabel,
        'sentBy': sentBy,
      };
}

/// A WhatsApp group the church already has —
/// `churches/{churchId}/whatsapp_groups/{id}`.
///
/// Only the invite link is stored. WhatsApp exposes no way to send into a
/// named group from a link, so this opens the group and the message is
/// pasted; the Share action is what actually puts text into a group.
class WhatsAppGroupLink {
  const WhatsAppGroupLink({
    required this.id,
    required this.label,
    required this.inviteUrl,
  });

  final String id;
  final String label;
  final String inviteUrl;

  factory WhatsAppGroupLink.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    return WhatsAppGroupLink(
      id: id,
      label: (data['label'] ?? '').toString().trim(),
      inviteUrl: (data['inviteUrl'] ?? '').toString().trim(),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'label': label,
        'inviteUrl': inviteUrl,
      };
}
