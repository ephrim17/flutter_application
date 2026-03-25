import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/models/app_user_model.dart';
import 'package:flutter_application/church_app/providers/app_config_provider.dart';
import 'package:flutter_application/church_app/providers/authentication/super_admin_provider.dart';
import 'package:flutter_application/church_app/providers/preflow_theme_provider.dart';
import 'package:flutter_application/church_app/providers/user_provider.dart';
import 'package:flutter_application/church_app/screens/entry/admin_mode_screen.dart';
import 'package:flutter_application/church_app/screens/entry/create_auth_account_screen.dart';
import 'package:flutter_application/church_app/screens/church_tab_screen.dart';
import 'package:flutter_application/church_app/screens/onboarding_screen.dart';
import 'package:flutter_application/church_app/screens/select-church-screen.dart';
import 'package:flutter_application/church_app/screens/super_admin/super_admin_home_screen.dart';
import 'package:flutter_application/church_app/screens/super_admin/super_admin_mode_screen.dart';
import 'package:flutter_application/church_app/widgets/pending_approval_widget.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppEntry extends ConsumerStatefulWidget {
  const AppEntry({
    super.key,
    this.initialUser,
  });

  final AppUser? initialUser;

  @override
  ConsumerState<AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends ConsumerState<AppEntry> {
  bool? _showOnboarding;

  void _syncSuperAdminSessionForUser(String uid) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(superAdminEntryModeProvider.notifier).syncForUser(uid);
    });
  }

  void _syncPreflowTheme(bool enabled) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final notifier = ref.read(forcePreflowThemeProvider.notifier);
      if (notifier.state != enabled) {
        notifier.state = enabled;
      }
    });
  }

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
    final isSuperAdminAsync = ref.watch(isSuperAdminProvider);
    final userAsync = ref.watch(appUserProvider);
    final resolvedUser = userAsync.maybeWhen(
      data: (user) => user,
      orElse: () => widget.initialUser,
    );
    final superAdminSession = ref.watch(superAdminEntryModeProvider);
    final firebaseUser = ref.watch(authStateProvider).value;
    final isSuperAdmin = firebaseUser != null &&
        isSuperAdminAsync.maybeWhen(
          data: (value) => value,
          orElse: () => false,
        );

    if (firebaseUser != null && isSuperAdminAsync.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (isSuperAdmin) {
      if (superAdminSession.isLoading) {
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      }
      if (superAdminSession.uid != firebaseUser.uid) {
        _syncSuperAdminSessionForUser(firebaseUser.uid);
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      }
      if (superAdminSession.mode == null) {
        _syncPreflowTheme(true);
        return const SuperAdminModeScreen();
      }
      if (superAdminSession.mode == SuperAdminEntryMode.superAdmin) {
        _syncPreflowTheme(true);
        return const SuperAdminHomeScreen();
      }
      _syncPreflowTheme(true);
    }

    return userAsync.when(
      loading: () => _buildResolvedScreen(resolvedUser),
      error: (e, _) => const SelectChurchScreen(),
      data: (user) {
        return _buildResolvedScreen(user);
      },
    );
  }

  Widget _buildResolvedScreen(AppUser? user) {
    final firebaseUser = ref.watch(authStateProvider).value;
    final appConfig = ref.watch(appConfigProvider).value;
    final normalizedEmail = firebaseUser?.email?.trim().toLowerCase() ?? '';
    final isChurchAdmin = appConfig != null &&
        normalizedEmail.isNotEmpty &&
        appConfig.isAdmin(normalizedEmail);
    if (firebaseUser == null) {
      _syncPreflowTheme(true);
      return const CreateAuthAccountScreen();
    }
    if (user == null) {
      _syncPreflowTheme(true);
      return const SelectChurchScreen();
    }
    if (!user.approved) {
      _syncPreflowTheme(true);
      return const PendingApprovalWidget();
    }
    if (appConfig?.adminMode.enabled == true && !isChurchAdmin) {
      _syncPreflowTheme(true);
      return const AdminModeScreen();
    }
    _syncPreflowTheme(false);
    return const ChurchTabScreen();
  }
}
