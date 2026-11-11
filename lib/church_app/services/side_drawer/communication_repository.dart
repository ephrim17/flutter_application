import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application/church_app/models/communication_models.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_paths.dart';

/// Reads and writes the church's message log and templates.
///
/// Church-scoped through [churchId], like every other repository here —
/// a message log names who was contacted about what and must never be
/// readable across churches.
class CommunicationRepository {
  const CommunicationRepository({
    required this.firestore,
    required this.churchId,
  });

  final FirebaseFirestore firestore;
  final String churchId;

  /// How much history the screen holds. A church sending weekly has years
  /// inside this, and the stats only look at the current month.
  static const int _logCap = 300;

  Stream<List<SentMessage>> watchLog() {
    return FirestorePaths.churchMessageLog(firestore, churchId)
        .orderBy('sentAt', descending: true)
        .limit(_logCap)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => SentMessage.fromFirestore(doc.id, doc.data()))
              .toList(growable: false),
        );
  }

  Stream<List<MessageTemplate>> watchTemplates() {
    return FirestorePaths.churchMessageTemplates(firestore, churchId)
        .orderBy('name')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => MessageTemplate.fromFirestore(doc.id, doc.data()))
              .toList(growable: false),
        );
  }

  /// Records what the church meant to send. The app hands off to WhatsApp
  /// or the SMS app and cannot know whether the person pressed send, so
  /// this is logged on the sender's say-so, not on delivery.
  Future<void> logSent(SentMessage message) {
    return FirestorePaths.churchMessageLog(firestore, churchId).add({
      ...message.toMap(),
      'sentAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> saveTemplate(MessageTemplate template) {
    final collection =
        FirestorePaths.churchMessageTemplates(firestore, churchId);
    if (template.id.isEmpty) {
      return collection.add({
        ...template.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    return collection.doc(template.id).update(template.toMap());
  }

  Future<void> deleteTemplate(String templateId) {
    return FirestorePaths.churchMessageTemplates(firestore, churchId)
        .doc(templateId)
        .delete();
  }

  Stream<List<WhatsAppGroupLink>> watchWhatsAppGroups() {
    return FirestorePaths.churchWhatsAppGroups(firestore, churchId)
        .orderBy('label')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => WhatsAppGroupLink.fromFirestore(doc.id, doc.data()),
              )
              .toList(growable: false),
        );
  }

  Future<void> saveWhatsAppGroup(WhatsAppGroupLink group) {
    final collection = FirestorePaths.churchWhatsAppGroups(firestore, churchId);
    if (group.id.isEmpty) return collection.add(group.toMap());
    return collection.doc(group.id).update(group.toMap());
  }

  Future<void> deleteWhatsAppGroup(String groupId) {
    return FirestorePaths.churchWhatsAppGroups(firestore, churchId)
        .doc(groupId)
        .delete();
  }

  Future<void> deleteLogEntry(String messageId) {
    return FirestorePaths.churchMessageLog(firestore, churchId)
        .doc(messageId)
        .delete();
  }
}
