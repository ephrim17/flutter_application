import 'package:flutter_application/church_app/models/attendance_service_model.dart';
import 'package:flutter_application/church_app/providers/church_provider.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_provider.dart';
import 'package:flutter_application/church_app/services/side_drawer/attendance_repository.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final attendanceRepositoryProvider =
    Provider.autoDispose<AttendanceRepository>((ref) {
  final churchId = ref.watch(currentChurchIdProvider).asData?.value;
  if (churchId == null || churchId.trim().isEmpty) {
    throw Exception('Church not selected');
  }

  return AttendanceRepository(
    firestore: ref.read(firestoreProvider),
    churchId: churchId,
  );
});

/// Every recorded service for the selected church, newest first.
final attendanceServicesProvider =
    StreamProvider.autoDispose<List<AttendanceService>>((ref) {
  final churchIdAsync = ref.watch(currentChurchIdProvider);

  return churchIdAsync.when(
    data: (churchId) {
      if (churchId == null || churchId.trim().isEmpty) {
        return Stream.value(const <AttendanceService>[]);
      }
      return AttendanceRepository(
        firestore: ref.read(firestoreProvider),
        churchId: churchId,
      ).watchServices();
    },
    loading: () => const Stream.empty(),
    error: (error, stackTrace) => Stream.error(error, stackTrace),
  );
});

/// One service, live — the marking sheet watches this so a second admin's
/// save shows up rather than being silently overwritten.
final attendanceServiceProvider = StreamProvider.autoDispose
    .family<AttendanceService?, String>((ref, serviceId) {
  final churchIdAsync = ref.watch(currentChurchIdProvider);

  return churchIdAsync.when(
    data: (churchId) {
      if (churchId == null || churchId.trim().isEmpty) {
        return Stream.value(null);
      }
      return AttendanceRepository(
        firestore: ref.read(firestoreProvider),
        churchId: churchId,
      ).watchService(serviceId);
    },
    loading: () => const Stream.empty(),
    error: (error, stackTrace) => Stream.error(error, stackTrace),
  );
});
