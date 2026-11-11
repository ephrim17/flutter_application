import 'package:flutter_application/church_app/models/communication_models.dart';
import 'package:flutter_application/church_app/providers/church_provider.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_provider.dart';
import 'package:flutter_application/church_app/services/side_drawer/communication_repository.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final communicationRepositoryProvider =
    Provider.autoDispose<CommunicationRepository>((ref) {
  final churchId = ref.watch(currentChurchIdProvider).asData?.value;
  if (churchId == null || churchId.trim().isEmpty) {
    throw Exception('Church not selected');
  }

  return CommunicationRepository(
    firestore: ref.read(firestoreProvider),
    churchId: churchId,
  );
});

/// What the church recorded as sent, newest first.
final messageLogProvider = StreamProvider.autoDispose<List<SentMessage>>((ref) {
  final churchIdAsync = ref.watch(currentChurchIdProvider);

  return churchIdAsync.when(
    data: (churchId) {
      if (churchId == null || churchId.trim().isEmpty) {
        return Stream.value(const <SentMessage>[]);
      }
      return CommunicationRepository(
        firestore: ref.read(firestoreProvider),
        churchId: churchId,
      ).watchLog();
    },
    loading: () => const Stream<List<SentMessage>>.empty(),
    error: (_, __) => Stream.value(const <SentMessage>[]),
  );
});

/// Reusable message bodies, by name.
final messageTemplatesProvider =
    StreamProvider.autoDispose<List<MessageTemplate>>((ref) {
  final churchIdAsync = ref.watch(currentChurchIdProvider);

  return churchIdAsync.when(
    data: (churchId) {
      if (churchId == null || churchId.trim().isEmpty) {
        return Stream.value(const <MessageTemplate>[]);
      }
      return CommunicationRepository(
        firestore: ref.read(firestoreProvider),
        churchId: churchId,
      ).watchTemplates();
    },
    loading: () => const Stream<List<MessageTemplate>>.empty(),
    error: (_, __) => Stream.value(const <MessageTemplate>[]),
  );
});

/// WhatsApp groups the church already runs, by label.
final whatsAppGroupsProvider =
    StreamProvider.autoDispose<List<WhatsAppGroupLink>>((ref) {
  final churchIdAsync = ref.watch(currentChurchIdProvider);

  return churchIdAsync.when(
    data: (churchId) {
      if (churchId == null || churchId.trim().isEmpty) {
        return Stream.value(const <WhatsAppGroupLink>[]);
      }
      return CommunicationRepository(
        firestore: ref.read(firestoreProvider),
        churchId: churchId,
      ).watchWhatsAppGroups();
    },
    loading: () => const Stream<List<WhatsAppGroupLink>>.empty(),
    error: (_, __) => Stream.value(const <WhatsAppGroupLink>[]),
  );
});
