import 'package:flutter_application/church_app/services/for_you_section/shorts_repository.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../models/for_you_section_model/shorts_model.dart';

final shortsProvider = StreamProvider<List<ShortModel>>((ref) {
  const churchChannelId = "UCfMUXhM4ujEI8aDTAh34K3A"; // your channel
  return ref
      .read(shortsRepositoryProvider)
      .watchActiveShorts(churchChannelId);
});