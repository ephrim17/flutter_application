import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
import 'package:flutter_application/church_app/screens/church_tab_screen.dart';
import 'package:flutter_application/church_app/screens/entry/auth_entry_screen.dart';
import 'package:flutter_application/church_app/widgets/pending_approval_widget.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class AppEntry extends ConsumerStatefulWidget {
  const AppEntry({super.key});

  @override
  ConsumerState<AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends ConsumerState<AppEntry> {

  @override
Widget build(BuildContext context) {
  debugPrint('🔥 AppEntry build()');

  final userAsync = ref.watch(appUserProvider);

  debugPrint('🔥 appUserProvider state: $userAsync');

  return userAsync.when(
    loading: () {
      debugPrint('⏳ user loading');
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    },
    error: (e, _) {
      debugPrint('❌ user error: $e');
      return const AuthEntryScreen();
    },
    data: (user) {
      debugPrint('✅ user data: $user');

      if (user == null) {
        debugPrint('➡️ user null → AuthEntry');
        return const AuthEntryScreen();
      }

      if (!user.approved) {
        debugPrint('⛔ not approved');
        return const PendingApprovalWidget();
      }

      debugPrint('🚀 approved → main app');
      return const ChurchTabScreen();
    },
  );
}
}