import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
import 'package:flutter_application/church_app/screens/church_tab_screen.dart';
import 'package:flutter_application/church_app/screens/entry/auth_entry_screen.dart';
import 'package:flutter_application/church_app/screens/onboarding_screen.dart';
import 'package:flutter_application/church_app/widgets/pending_approval_widget.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppEntry extends ConsumerStatefulWidget {
  const AppEntry({super.key});

  @override
  ConsumerState<AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends ConsumerState<AppEntry> {
  bool? _showOnboarding;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final completed = prefs.getBool('onboarding_completed') ?? false;
    setState(() {
      _showOnboarding = !completed;
    });
  }

  void _onOnboardingComplete() {
    setState(() {
      _showOnboarding = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show loading while onboarding check is pending
    if (_showOnboarding == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    // Show onboarding if not completed
    if (_showOnboarding!) {
      return OnboardingScreen(onComplete: _onOnboardingComplete);
    }

    // Existing logic (do not change)
    final userAsync = ref.watch(appUserProvider);

    return userAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => const AuthEntryScreen(),
      data: (user) {
        if (user == null) {
          return const AuthEntryScreen();
        }
        if (!user.approved) {
          return const PendingApprovalWidget();
        }
        return const ChurchTabScreen();
      },
    );
  }
}
