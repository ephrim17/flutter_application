import 'package:hooks_riverpod/legacy.dart';

final requestAccessLoadingProvider = StateProvider<bool>((ref) => false);
final logginAccessLoadingProvider = StateProvider<bool>((ref) => false);
final passwordVisibleProvider = StateProvider<bool>((ref) => false);