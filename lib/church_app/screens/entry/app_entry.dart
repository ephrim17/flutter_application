import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
import 'package:flutter_application/church_app/screens/church_tab_screen.dart';
import 'package:flutter_application/church_app/screens/entry/auth_entry_screen.dart';
import 'package:flutter_application/church_app/screens/entry/login_request_screen.dart';
import 'package:flutter_application/church_app/widgets/pending_approval_widget.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';


class AppEntry extends ConsumerWidget {
  const AppEntry({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(appUserProvider);

    return userAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const AuthEntryScreen(),
      data: (user) {
        if (user == null) {
          return const AuthEntryScreen();
        }

        if (!user.approved) {
          return const PendingApprovalWidget();
        }

        return const ChurchTabScreen(); // MAIN APP
      },
    );
  }
}
