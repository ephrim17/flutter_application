import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/models/user_identity_model.dart';
import 'package:flutter_application/church_app/providers/app_config_provider.dart';
import 'package:flutter_application/church_app/providers/authentication/super_admin_provider.dart';
import 'package:flutter_application/church_app/providers/church_provider.dart';
import 'package:flutter_application/church_app/providers/preflow_theme_provider.dart';
import 'package:flutter_application/church_app/providers/select_church_provider.dart';
import 'package:flutter_application/church_app/providers/user_provider.dart';
import 'package:flutter_application/church_app/screens/entry/admin_mode_screen.dart';
import 'package:flutter_application/church_app/screens/entry/complete_profile_screen.dart';
import 'package:flutter_application/church_app/screens/entry/create_auth_account_screen.dart';
import 'package:flutter_application/church_app/screens/church_tab_screen.dart';
import 'package:flutter_application/church_app/screens/onboarding_screen.dart';
import 'package:flutter_application/church_app/screens/personal/guest_shell_screen.dart';
import 'package:flutter_application/church_app/screens/super_admin/super_admin_home_screen.dart';
import 'package:flutter_application/church_app/screens/super_admin/super_admin_mode_screen.dart';
import 'package:flutter_application/church_app/widgets/app_splash_screen.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Entry state machine — KT Files/architecture/
/// user-church-decoupling-migration.md §5.4:
///   onboarding incomplete           -> onboarding
///   signed out                      -> auth
///   signed in, no identity doc      -> complete profile   (NEW)
///   super admin                     -> mode chooser
///   signed in, no approved anywhere -> guest shell         (NEW)
///   approved                        -> ChurchTabScreen
class AppEntry extends ConsumerStatefulWidget {
  const AppEntry({super.key});

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

  void _restoreSelectedChurchIfNeeded() {
    final selectedChurch = ref.watch(selectedChurchProvider);
    if (selectedChurch != null) return;

    final churchId = ref.watch(currentChurchIdProvider).value;
    if (churchId == null || churchId.trim().isEmpty) return;

    final churchAsync = ref.watch(churchByIdProvider(churchId));
    final church = churchAsync.value;
    if (church == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final notifier = ref.read(selectedChurchProvider.notifier);
      if (notifier.state == null) {
        notifier.state = church;
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
    if (!mounted) return;
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
        body: Center(child: AppSplashScreen()),
      );
    }
    // Show onboarding if not completed
    if (_showOnboarding!) {
      _syncPreflowTheme(true);
      return OnboardingScreen(onComplete: _onOnboardingComplete);
    }

    final isSuperAdminAsync = ref.watch(isSuperAdminProvider);
    final identityAsync = ref.watch(userIdentityProvider);
    final superAdminSession = ref.watch(superAdminEntryModeProvider);
    final firebaseUser = ref.watch(authStateProvider).value;
    final isSuperAdmin = firebaseUser != null &&
        isSuperAdminAsync.maybeWhen(
          data: (value) => value,
          orElse: () => false,
        );

    if (firebaseUser != null && isSuperAdminAsync.isLoading) {
      return const Scaffold(
        body: Center(child: AppSplashScreen()),
      );
    }

    if (isSuperAdmin) {
      if (superAdminSession.isLoading) {
        return const Scaffold(
          body: Center(child: AppSplashScreen()),
        );
      }
      if (superAdminSession.uid != firebaseUser.uid) {
        _syncSuperAdminSessionForUser(firebaseUser.uid);
        return const Scaffold(
          body: Center(child: AppSplashScreen()),
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

    return identityAsync.when(
      loading: () => const Scaffold(
        body: Center(child: AppSplashScreen()),
      ),
      error: (_, __) => const CreateAuthAccountScreen(),
      data: _buildResolvedScreen,
    );
  }

  Widget _buildResolvedScreen(UserIdentity? identity) {
    final firebaseUser = ref.watch(authStateProvider).value;
    if (firebaseUser == null) {
      _syncPreflowTheme(true);
      return const CreateAuthAccountScreen();
    }
    if (identity == null) {
      _syncPreflowTheme(true);
      return const CompleteProfileScreen();
    }

    final membershipsAsync = ref.watch(myMembershipsProvider);
    if (membershipsAsync.isLoading) {
      return const Scaffold(
        body: Center(child: AppSplashScreen()),
      );
    }
    final memberships = membershipsAsync.asData?.value ?? const [];
    final hasApprovedMembership =
        memberships.any((membership) => membership.approved);

    if (!hasApprovedMembership) {
      _syncPreflowTheme(true);
      return const GuestShellScreen();
    }

    final appConfig = ref.watch(appConfigProvider).value;
    final normalizedEmail = firebaseUser.email?.trim().toLowerCase() ?? '';
    final isChurchAdmin = appConfig != null &&
        normalizedEmail.isNotEmpty &&
        appConfig.isAdmin(normalizedEmail);

    _restoreSelectedChurchIfNeeded();
    if (appConfig?.superAdminDisabled == true) {
      _syncPreflowTheme(true);
      return AdminModeScreen(
        messageOverride: ref.t('super_admin.disabled_message'),
      );
    }
    if (appConfig?.adminMode.enabled == true && !isChurchAdmin) {
      _syncPreflowTheme(true);
      return const AdminModeScreen();
    }
    _syncPreflowTheme(false);
    return const ChurchTabScreen();
  }
}
