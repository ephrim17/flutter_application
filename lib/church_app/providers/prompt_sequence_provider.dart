import 'package:hooks_riverpod/legacy.dart';

/// Home alerts wait for notification setup to finish so modal sheets never
/// compete for the navigator and can be shown in a predictable order.
final notificationPromptCompletedProvider = StateProvider<bool>((ref) => false);
